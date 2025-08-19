// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { ERC1967Utils } from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { SafeERC20 }    from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 }       from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import { AccessControlEnumerableUpgradeable }
    from "openzeppelin-contracts-upgradeable/contracts/access/extensions/AccessControlEnumerableUpgradeable.sol";

import { UUPSUpgradeable } from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { ISparkVault } from "./ISparkVault.sol";

interface IERC1271 {
    function isValidSignature(bytes32, bytes memory) external view returns (bytes4);
}

/*

  ███████╗██████╗  █████╗ ██████╗ ██╗  ██╗    ██╗   ██╗ █████╗ ██╗   ██╗██╗  ████████╗
  ██╔════╝██╔══██╗██╔══██╗██╔══██╗██║ ██╔╝    ██║   ██║██╔══██╗██║   ██║██║  ╚══██╔══╝
  ███████╗██████╔╝███████║██████╔╝█████╔╝     ██║   ██║███████║██║   ██║██║     ██║
  ╚════██║██╔═══╝ ██╔══██║██╔══██╗██╔═██╗     ╚██╗ ██╔╝██╔══██║██║   ██║██║     ██║
  ███████║██║     ██║  ██║██║  ██║██║  ██╗     ╚████╔╝ ██║  ██║╚██████╔╝███████╗██║
  ╚══════╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝      ╚═══╝  ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝

*/

/// @dev If the inheritance is updated, the functions in `initialize` must be updated as well.
///      Last updated for: `Initializable, UUPSUpgradeable, AccessControlEnumerableUpgradeable,
///      ISparkVault`.
contract SparkVault is AccessControlEnumerableUpgradeable, UUPSUpgradeable, ISparkVault {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    // This corresponds to a 100% APY, verify here:
    // bc -l <<< 'scale=27; e( l(2)/(60 * 60 * 24 * 365) )'
    uint256 public constant MAX_SSR = 1.000000021979553151239153027e27;
    uint256 public constant RAY     = 1e27;

    bytes32 public constant SETTER_ROLE = keccak256("SETTER_ROLE");
    bytes32 public constant TAKER_ROLE  = keccak256("TAKER_ROLE");

    bytes32 public constant PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );

    string public constant version = "1";

    uint8 public constant decimals = 18;

    /**********************************************************************************************/
    /*** Storage variables                                                                      ***/
    /**********************************************************************************************/

    address public asset;

    string public name;
    string public symbol;

    uint64  public rho;    // Time of last drip              [unix epoch time]
    uint192 public chi;    // The Rate Accumulator           [ray]
    uint256 public ssr;    // The Spark Savings Rate         [ray]
    uint256 public minSsr; // The minimum Spark Savings Rate [ray]
    uint256 public maxSsr; // The maximum Spark Savings Rate [ray]

    uint256 public totalSupply;

    mapping (address => uint256) public balanceOf;
    mapping (address => uint256) public nonces;

    mapping (address => mapping (address => uint256)) public allowance;

    /**********************************************************************************************/
    /*** Initialization and upgradeability                                                      ***/
    /**********************************************************************************************/

    constructor() {
        _disableInitializers(); // Avoid initializing in the context of the implementation
    }

    // NOTE: Neither UUPSUpgradeable nor AccessControlEnumerableUpgradeable
    //       require init functions to be called.
    function initialize(address asset_, string memory name_, string memory symbol_, address admin)
        initializer external
    {
        asset  = asset_;
        name   = name_;
        symbol = symbol_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        chi = uint192(RAY);
        rho = uint64(block.timestamp);
        ssr = RAY;

        minSsr = RAY;
        maxSsr = RAY;
    }

    // Only DEFAULT_ADMIN_ROLE can upgrade the implementation
    function _authorizeUpgrade(address) internal view override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**********************************************************************************************/
    /*** Role-based external functions                                                          ***/
    /**********************************************************************************************/

    function setSsrBounds(uint256 minSsr_, uint256 maxSsr_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(minSsr_ >= RAY,     "SparkVault/ssr-too-low");
        require(maxSsr_ <= MAX_SSR, "SparkVault/ssr-too-high");

        emit SsrBoundsSet(minSsr, maxSsr, minSsr_, maxSsr_);

        minSsr = minSsr_;
        maxSsr = maxSsr_;
    }

    function setSsr(uint256 data) external onlyRole(SETTER_ROLE) {
        require(data >= minSsr, "SparkVault/ssr-too-low");
        require(data <= maxSsr, "SparkVault/ssr-too-high");

        drip();
        uint256 ssr_ = ssr;
        ssr = data;

        emit SsrSet(msg.sender, ssr_, data);
    }

    function take(uint256 value) external onlyRole(TAKER_ROLE) {
        _pushAsset(msg.sender, value);

        emit Take(msg.sender, value);
    }

    /**********************************************************************************************/
    /*** Rate accumulation                                                                      ***/
    /**********************************************************************************************/

    function drip() public returns (uint256 nChi) {
        (uint256 chi_, uint256 rho_) = (chi, rho);
        uint256 diff;
        if (block.timestamp > rho_) {
            nChi = _rpow(ssr, block.timestamp - rho_) * chi_ / RAY;
            uint256 totalSupply_ = totalSupply;
            diff = totalSupply_ * nChi / RAY - totalSupply_ * chi_ / RAY;

            // Safe as nChi is limited to maxUint256/RAY (which is < maxUint192)
            chi = uint192(nChi);
            rho = uint64(block.timestamp);
        } else {
            nChi = chi_;
        }
        emit Drip(nChi, diff);
    }

    /**********************************************************************************************/
    /*** ERC20 external mutating functions                                                      ***/
    /**********************************************************************************************/

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);

        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        require(to != address(0) && to != address(this), "SparkVault/invalid-address");
        uint256 balance = balanceOf[msg.sender];
        require(balance >= value, "SparkVault/insufficient-balance");

        // NOTE: Don't need an overflow check here b/c sum of all balances == totalSupply
        unchecked {
            balanceOf[msg.sender] = balance - value;
            balanceOf[to] += value;
        }

        emit Transfer(msg.sender, to, value);

        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(to != address(0) && to != address(this), "SparkVault/invalid-address");
        uint256 balance = balanceOf[from];
        require(balance >= value, "SparkVault/insufficient-balance");

        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                require(allowed >= value, "SparkVault/insufficient-allowance");

                unchecked {
                    allowance[from][msg.sender] = allowed - value;
                }
            }
        }

        // NOTE: Don't need an overflow check here b/c sum of all balances == totalSupply
        unchecked {
            balanceOf[from] = balance - value;
            balanceOf[to] += value;
        }

        emit Transfer(from, to, value);

        return true;
    }

    /**********************************************************************************************/
    /*** EIP712 external mutating functions                                                     ***/
    /**********************************************************************************************/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        bytes memory signature
    ) public {
        require(block.timestamp <= deadline, "SparkVault/permit-expired");
        require(owner != address(0),         "SparkVault/invalid-owner");

        uint256 nonce;
        unchecked { nonce = nonces[owner]++; }

        bytes32 digest =
            keccak256(abi.encodePacked(
                "\x19\x01",
                _calculateDomainSeparator(block.chainid),
                keccak256(abi.encode(
                    PERMIT_TYPEHASH,
                    owner,
                    spender,
                    value,
                    nonce,
                    deadline
                ))
            ));

        require(_isValidSignature(owner, digest, signature), "SparkVault/invalid-permit");

        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        permit(owner, spender, value, deadline, abi.encodePacked(r, s, v));
    }

    /**********************************************************************************************/
    /*** ERC4626 external mutating functions                                                    ***/
    /**********************************************************************************************/

    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        shares = assets * RAY / drip();
        _mint(assets, shares, receiver);
    }

    function deposit(uint256 assets, address receiver, uint16 referral)
        external returns (uint256 shares)
    {
        shares = deposit(assets, receiver);
        emit Referral(referral, receiver, assets, shares);
    }

    function mint(uint256 shares, address receiver) public returns (uint256 assets) {
        assets = _divup(shares * drip(), RAY);
        _mint(assets, shares, receiver);
    }

    function mint(uint256 shares, address receiver, uint16 referral)
        external returns (uint256 assets)
    {
        assets = mint(shares, receiver);
        emit Referral(referral, receiver, assets, shares);
    }

    function withdraw(uint256 assets, address receiver, address owner)
        external returns (uint256 shares)
    {
        shares = _divup(assets * RAY, drip());
        _burn(assets, shares, receiver, owner);
    }

    function redeem(uint256 shares, address receiver, address owner)
        external returns (uint256 assets)
    {
        assets = shares * drip() / RAY;
        _burn(assets, shares, receiver, owner);
    }

    /**********************************************************************************************/
    /*** ERC4626 external view functions                                                        ***/
    /**********************************************************************************************/

    function convertToAssets(uint256 shares) public view returns (uint256) {
        return shares * nowChi() / RAY;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        return assets * RAY / nowChi();
    }

    function maxDeposit(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function maxRedeem(address owner) external view returns (uint256) {
        return balanceOf[owner];
    }

    // TODO: Add remaining view functions
    function maxWithdraw(address owner) external view returns (uint256) {
        uint256 liquidity  = IERC20(asset).balanceOf(address(this));
        uint256 userAssets = assetsOf(owner);
        return liquidity > userAssets ? userAssets : liquidity;
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) external view returns (uint256) {
        return _divup(shares * nowChi(), RAY);
    }

    function previewRedeem(uint256 shares) external view returns (uint256) {
        return convertToAssets(shares);
    }

    function previewWithdraw(uint256 assets) external view returns (uint256) {
        return _divup(assets * RAY, nowChi());
    }

    function totalAssets() public view returns (uint256) {
        return convertToAssets(totalSupply);
    }

    /**********************************************************************************************/
    /*** Convenience view functions                                                             ***/
    /**********************************************************************************************/

    function assetsOf(address owner) public view returns (uint256) {
        return convertToAssets(balanceOf[owner]);
    }

    function assetsOutstanding() public view returns (uint256) {
        // TODO: Create a clamp function
        return totalAssets() - IERC20(asset).balanceOf(address(this));
    }

    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    function nowChi() public view returns (uint256) {
        return (block.timestamp > rho) ? _rpow(ssr, block.timestamp - rho) * chi / RAY : chi;
    }

    /**********************************************************************************************/
    /*** Token transfer internal helper functions                                               ***/
    /**********************************************************************************************/

    function _burn(uint256 assets, uint256 shares, address receiver, address owner) internal {
        uint256 balance = balanceOf[owner];
        require(balance >= shares, "SparkVault/insufficient-balance");

        if (owner != msg.sender) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed != type(uint256).max) {
                require(allowed >= shares, "SparkVault/insufficient-allowance");

                unchecked {
                    allowance[owner][msg.sender] = allowed - shares;
                }
            }
        }

        // NOTE: Don't need overflow checks as require(balance >= shares)
        //       and balance <= totalSupply
        unchecked {
            balanceOf[owner] = balance - shares;
            totalSupply      = totalSupply - shares;
        }

        _pushAsset(receiver, assets);

        emit Transfer(owner, address(0), shares);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function _mint(uint256 assets, uint256 shares, address receiver) internal {
        require(receiver != address(0) && receiver != address(this), "SparkVault/invalid-address");

        _pullAsset(msg.sender, assets);

        // NOTE: Don't need overflow checks as balanceOf[receiver] <= totalSupply
        //       and shares <= totalSupply
        unchecked {
            balanceOf[receiver] = balanceOf[receiver] + shares;
            totalSupply = totalSupply + shares;
        }

        emit Deposit(msg.sender, receiver, assets, shares);
        emit Transfer(address(0), receiver, shares);
    }

    function _pullAsset(address from, uint256 value) internal {
        SafeERC20.safeTransferFrom(IERC20(asset), from, address(this), value);
    }

    function _pushAsset(address to, uint256 value) internal {
        require(
            value <= IERC20(asset).balanceOf(address(this)), "SparkVault/insufficient-liquidity"
        );
        SafeERC20.safeTransfer(IERC20(asset), to, value);
    }

    /**********************************************************************************************/
    /*** EIP712 internal helper functions                                                       ***/
    /**********************************************************************************************/

    function _calculateDomainSeparator(uint256 chainId) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId,
                address(this)
            )
        );
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _calculateDomainSeparator(block.chainid);
    }

    function _isValidSignature(
        address signer,
        bytes32 digest,
        bytes memory signature
    ) internal view returns (bool valid) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            if (signer == ecrecover(digest, v, r, s)) {
                return true;
            }
        }

        if (signer.code.length > 0) {
            (bool success, bytes memory result) = signer.staticcall(
                abi.encodeCall(IERC1271.isValidSignature, (digest, signature))
            );
            valid = (success &&
                result.length == 32 &&
                abi.decode(result, (bytes4)) == IERC1271.isValidSignature.selector);
        }
    }

    /**********************************************************************************************/
    /*** General internal helper functions                                                      ***/
    /**********************************************************************************************/

    function _divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        // NOTE: _divup(0,0) will return 0 differing from natural solidity division
        unchecked {
            z = x != 0 ? ((x - 1) / y) + 1 : 0;
        }
    }

    function _rpow(uint256 x, uint256 n) internal pure returns (uint256 z) {
        assembly {
            switch x case 0 {switch n case 0 {z := RAY} default {z := 0}}
            default {
                switch mod(n, 2) case 0 { z := RAY } default { z := x }
                let half := div(RAY, 2)  // for rounding.
                for { n := div(n, 2) } n { n := div(n,2) } {
                    let xx := mul(x, x)
                    if iszero(eq(div(xx, x), x)) { revert(0,0) }
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) { revert(0,0) }
                    x := div(xxRound, RAY)
                    if mod(n,2) {
                        let zx := mul(z, x)
                        if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) { revert(0,0) }
                        z := div(zxRound, RAY)
                    }
                }
            }
        }
    }

}
