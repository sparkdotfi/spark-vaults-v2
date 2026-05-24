// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { SafeERC20 }      from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 }         from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { AccessControlEnumerable }
    from "openzeppelin-contracts/contracts/access/extensions/AccessControlEnumerable.sol";

import { ISparkBoostedVault } from "./ISparkBoostedVault.sol";

/*

  ███████╗██████╗  █████╗ ██████╗ ██╗  ██╗    ██████╗  ██████╗  ██████╗ ███████╗████████╗███████╗██████╗
  ██╔════╝██╔══██╗██╔══██╗██╔══██╗██║ ██╔╝    ██╔══██╗██╔═══██╗██╔═══██╗██╔════╝╚══██╔══╝██╔════╝██╔══██╗
  ███████╗██████╔╝███████║██████╔╝█████╔╝     ██████╔╝██║   ██║██║   ██║███████╗   ██║   █████╗  ██║  ██║
  ╚════██║██╔═══╝ ██╔══██║██╔══██╗██╔═██╗     ██╔══██╗██║   ██║██║   ██║╚════██║   ██║   ██╔══╝  ██║  ██║
  ███████║██║     ██║  ██║██║  ██║██║  ██╗    ██████╔╝╚██████╔╝╚██████╔╝███████║   ██║   ███████╗██████╔╝
  ╚══════╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝    ╚═════╝  ╚═════╝  ╚═════╝ ╚══════╝   ╚═╝   ╚══════╝╚═════╝

*/

contract SparkBoostedVault is AccessControlEnumerable, ISparkBoostedVault {

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    // This corresponds to a 100% APY, verify here:
    // bc -l <<< 'scale=27; e( l(2)/(60 * 60 * 24 * 365) )'
    uint256 public constant MAX_VSR = 1.000000021979553151239153027e27;
    uint256 public constant RAY     = 1e27;

    bytes32 public constant SETTER_ROLE = keccak256("SETTER_ROLE");
    bytes32 public constant TAKER_ROLE  = keccak256("TAKER_ROLE");

    string public constant version = "1";

    /**********************************************************************************************/
    /*** Storage variables                                                                      ***/
    /**********************************************************************************************/

    address public immutable asset;

    uint8 public immutable decimals;

    string public name;
    string public symbol;

    // The vesting window for the per-user yield multiplier. Both are durations in seconds. Yield
    // earned by a user is multiplied by 0 if elapsed < cliff, else by min((elapsed / term)^2, 1),
    // where elapsed = block.timestamp - position.depositTime. The quadratic ramp is slow at the
    // start and fast at the end, so early exits forfeit disproportionately more yield than under
    // a linear curve.
    uint64 public immutable term;
    uint64 public immutable cliff;

    uint64  public rho;    // Time of last drip              [unix epoch time]
    uint192 public chi;    // The Rate Accumulator           [ray]
    uint256 public vsr;    // The Vault Savings Rate         [ray]
    uint256 public minVsr; // The minimum Vault Savings Rate [ray]
    uint256 public maxVsr; // The maximum Vault Savings Rate [ray]

    uint256 public depositCap;

    // Aggregate accounting. Not ERC20: positions are non-fungible.
    uint256 public totalShares;
    uint256 public totalPrincipal;

    struct Position {
        uint256 principal;   // Asset amount the user has put in, minus any withdrawn principal.
        uint256 shares;      // Raw rate-based shares; raw assets = shares * chi / RAY.
        uint64  depositTime; // Effective deposit time, blended on deposit and partial withdraw.
    }

    mapping (address => Position) public positions;

    /**********************************************************************************************/
    /*** Construction                                                                           ***/
    /**********************************************************************************************/

    constructor(
        address asset_,
        string memory name_,
        string memory symbol_,
        address admin,
        uint64 term_,
        uint64 cliff_
    ) {
        require(term_  > 0,      "SparkBoostedVault/invalid-term");
        require(cliff_ <= term_, "SparkBoostedVault/cliff-gt-term");

        asset  = asset_;
        name   = name_;
        symbol = symbol_;
        term   = term_;
        cliff  = cliff_;

        decimals = IERC20Metadata(asset_).decimals();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        chi = uint192(RAY);
        rho = uint64(block.timestamp);
        vsr = RAY;

        minVsr = RAY;
        maxVsr = RAY;
    }

    /**********************************************************************************************/
    /*** Role-based external functions                                                          ***/
    /**********************************************************************************************/

    function setDepositCap(uint256 newCap) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit DepositCapSet(depositCap, newCap);
        depositCap = newCap;
    }

    function setVsrBounds(uint256 minVsr_, uint256 maxVsr_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(minVsr_ >= RAY,     "SparkBoostedVault/vsr-too-low");
        require(maxVsr_ <= MAX_VSR, "SparkBoostedVault/vsr-too-high");
        require(minVsr_ <= maxVsr_, "SparkBoostedVault/min-vsr-gt-max-vsr");

        emit VsrBoundsSet(minVsr, maxVsr, minVsr_, maxVsr_);

        minVsr = minVsr_;
        maxVsr = maxVsr_;
    }

    function setVsr(uint256 newVsr) external onlyRole(SETTER_ROLE) {
        require(newVsr >= minVsr, "SparkBoostedVault/vsr-too-low");
        require(newVsr <= maxVsr, "SparkBoostedVault/vsr-too-high");

        drip();
        uint256 vsr_ = vsr;
        vsr = newVsr;

        emit VsrSet(msg.sender, vsr_, newVsr);
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
            nChi = _rpow(vsr, block.timestamp - rho_) * chi_ / RAY;
            uint256 totalShares_ = totalShares;
            diff = totalShares_ * nChi / RAY - totalShares_ * chi_ / RAY;

            // Safe as nChi is limited to maxUint256/RAY (which is < maxUint192)
            chi = uint192(nChi);
            rho = uint64(block.timestamp);
        } else {
            nChi = chi_;
        }
        emit Drip(nChi, diff);
    }

    /**********************************************************************************************/
    /*** Deposit / Withdraw                                                                     ***/
    /**********************************************************************************************/

    // Positions are single-shot: each address may hold at most one position at a time. To "top up"
    // or partially exit, fully withdraw first and re-deposit; this resets the vesting clock to now.
    // Both deposit and withdraw are locked to msg.sender — no receiver/owner overrides.

    function deposit(uint256 assets) public returns (uint256 shares) {
        shares = assets * RAY / drip();
        _mint(assets, shares);
    }

    function deposit(uint256 assets, uint16 referral) external returns (uint256 shares) {
        shares = deposit(assets);
        emit Referral(referral, msg.sender, assets, shares);
    }

    function withdraw() external returns (uint256 assets) {
        assets = _burn();
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

    function maxDeposit(address receiver) external view returns (uint256) {
        if (hasRole(TAKER_ROLE, receiver))     return 0;
        if (positions[receiver].principal > 0) return 0;
        uint256 totalAssets_ = totalAssets();
        uint256 depositCap_  = depositCap;
        return depositCap_ <= totalAssets_ ? 0 : depositCap_ - totalAssets_;
    }

    function maxWithdraw(address owner) external view returns (uint256) {
        uint256 liquidity         = IERC20(asset).balanceOf(address(this));
        uint256 userWithdrawable_ = withdrawableOf(owner);
        return liquidity > userWithdrawable_ ? userWithdrawable_ : liquidity;
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    function totalAssets() public view returns (uint256) {
        return convertToAssets(totalShares);
    }

    /**********************************************************************************************/
    /*** Position view functions                                                                ***/
    /**********************************************************************************************/

    function principalOf(address user) external view returns (uint256) {
        return positions[user].principal;
    }

    function sharesOf(address user) external view returns (uint256) {
        return positions[user].shares;
    }

    function depositTimeOf(address user) external view returns (uint64) {
        return positions[user].depositTime;
    }

    function assetsOf(address user) public view returns (uint256) {
        return positions[user].shares * nowChi() / RAY;
    }

    // Returns the vesting multiplier [ray] for the user's current position. A return of 0 means
    // none of the yield has vested; a return of RAY means yield is fully vested. The shape is a
    // quadratic ease-in: m = (elapsed/term)^2 between cliff and term, zero before cliff, one
    // after term.
    //
    // Overflow note: elapsed is gated by `elapsed < term` and term is uint64, so elapsed^2 is
    // at most 2^128. Multiplied by RAY (~2^90) the intermediate fits comfortably in uint256.
    function vestingMultiplier(address user) public view returns (uint256) {
        uint64 t0 = positions[user].depositTime;
        if (t0 == 0) return 0;
        uint256 elapsed = block.timestamp - uint256(t0);
        uint256 cliff_  = cliff;
        uint256 term_   = term;
        if (elapsed < cliff_) return 0;
        if (elapsed >= term_) return RAY;
        return (elapsed * elapsed) * RAY / (term_ * term_);
    }

    function vestedYieldOf(address user) public view returns (uint256) {
        Position memory p   = positions[user];
        uint256 raw         = p.shares * nowChi() / RAY;
        if (raw <= p.principal) return 0;
        uint256 yield_      = raw - p.principal;
        return yield_ * vestingMultiplier(user) / RAY;
    }

    function unvestedYieldOf(address user) external view returns (uint256) {
        Position memory p = positions[user];
        uint256 raw       = p.shares * nowChi() / RAY;
        if (raw <= p.principal) return 0;
        uint256 yield_    = raw - p.principal;
        uint256 vested_   = yield_ * vestingMultiplier(user) / RAY;
        return yield_ - vested_;
    }

    function withdrawableOf(address user) public view returns (uint256) {
        return positions[user].principal + vestedYieldOf(user);
    }

    /**********************************************************************************************/
    /*** Convenience view functions                                                             ***/
    /**********************************************************************************************/

    function assetsOutstanding() public view returns (uint256) {
        uint256 liquidity_   = IERC20(asset).balanceOf(address(this));
        uint256 totalAssets_ = totalAssets();
        return totalAssets_ >= liquidity_ ? totalAssets_ - liquidity_ : 0;
    }

    function nowChi() public view returns (uint256) {
        return (block.timestamp > rho) ? _rpow(vsr, block.timestamp - rho) * chi / RAY : chi;
    }

    /**********************************************************************************************/
    /*** Position mutation internals                                                            ***/
    /**********************************************************************************************/

    function _mint(uint256 assets, uint256 shares) internal {
        require(!hasRole(TAKER_ROLE, msg.sender),     "SparkBoostedVault/taker-cannot-deposit");
        require(positions[msg.sender].principal == 0, "SparkBoostedVault/existing-position");
        require(totalAssets() + assets <= depositCap, "SparkBoostedVault/deposit-cap-exceeded");

        _pullAsset(msg.sender, assets);

        uint64 t0 = uint64(block.timestamp);
        positions[msg.sender] = Position({
            principal:   assets,
            shares:      shares,
            depositTime: t0
        });

        totalShares    = totalShares    + shares;
        totalPrincipal = totalPrincipal + assets;

        emit Deposit(msg.sender, msg.sender, assets, shares);
        emit PositionUpdated(msg.sender, assets, shares, t0);
    }

    function _burn() internal returns (uint256 assets) {
        drip();

        // Full-exit only: the caller withdraws their entire vested balance. Unvested yield in the
        // closed position is forfeited and stays in the vault (claimable by TAKER_ROLE).
        assets = withdrawableOf(msg.sender);
        require(assets > 0, "SparkBoostedVault/zero-position");

        Position memory p = positions[msg.sender];
        delete positions[msg.sender];

        totalShares    = totalShares    - p.shares;
        totalPrincipal = totalPrincipal - p.principal;

        _pushAsset(msg.sender, assets);

        emit Withdraw(msg.sender, msg.sender, msg.sender, assets, p.shares);
        emit PositionUpdated(msg.sender, 0, 0, 0);
    }

    /**********************************************************************************************/
    /*** Asset transfer internals                                                               ***/
    /**********************************************************************************************/

    function _pullAsset(address from, uint256 value) internal {
        SafeERC20.safeTransferFrom(IERC20(asset), from, address(this), value);
    }

    function _pushAsset(address to, uint256 value) internal {
        require(
            value <= IERC20(asset).balanceOf(address(this)),
            "SparkBoostedVault/insufficient-liquidity"
        );
        SafeERC20.safeTransfer(IERC20(asset), to, value);
    }

    /**********************************************************************************************/
    /*** General internal helper functions                                                      ***/
    /**********************************************************************************************/

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
