// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.35;

import { IERC20 }         from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 }      from "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { EnumerableSet }  from "../lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

import { AccessControlEnumerableUpgradeable }
    from "../lib/openzeppelin-contracts-upgradeable/contracts/access/extensions/AccessControlEnumerableUpgradeable.sol";

import { UUPSUpgradeable } from "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

import { ISparkBoostedVault } from "./ISparkBoostedVault.sol";

/*

  ███████╗██████╗  █████╗ ██████╗ ██╗  ██╗
  ██╔════╝██╔══██╗██╔══██╗██╔══██╗██║ ██╔╝
  ███████╗██████╔╝███████║██████╔╝█████╔╝
  ╚════██║██╔═══╝ ██╔══██║██╔══██╗██╔═██╗
  ███████║██║     ██║  ██║██║  ██║██║  ██╗
  ╚══════╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

  ██████╗  ██████╗  ██████╗ ███████╗████████╗███████╗██████╗
  ██╔══██╗██╔═══██╗██╔═══██╗██╔════╝╚══██╔══╝██╔════╝██╔══██╗
  ██████╔╝██║   ██║██║   ██║███████╗   ██║   █████╗  ██║  ██║
  ██╔══██╗██║   ██║██║   ██║╚════██║   ██║   ██╔══╝  ██║  ██║
  ██████╔╝╚██████╔╝╚██████╔╝███████║   ██║   ███████╗██████╔╝
  ╚═════╝  ╚═════╝  ╚═════╝ ╚══════╝   ╚═╝   ╚══════╝╚═════╝

  ██╗   ██╗ █████╗ ██╗   ██╗██╗  ████████╗
  ██║   ██║██╔══██╗██║   ██║██║  ╚══██╔══╝
  ██║   ██║███████║██║   ██║██║     ██║
  ╚██╗ ██╔╝██╔══██║██║   ██║██║     ██║
   ╚████╔╝ ██║  ██║╚██████╔╝███████╗██║
    ╚═══╝  ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝

*/

contract SparkBoostedVault is
    ISparkBoostedVault,
    UUPSUpgradeable,
    AccessControlEnumerableUpgradeable
{

    using EnumerableSet for EnumerableSet.UintSet;

    /**********************************************************************************************/
    /*** Vault Storage                                                                          ***/
    /**********************************************************************************************/

    /// @custom:storage-location erc7201:spark.storage.SparkBoostedVault
    struct VaultStorage {
        address asset;
        uint192 chi;
        uint256 maxLiabilityCap;
        uint256 maxVsr;
        uint256 minVsr;
        uint256 positionCount;
        uint256 totalPrincipal;
        uint256 totalShares;
        uint256 vsr;
        uint64  cliff;
        uint64  rho;
        uint64  term;
        mapping (address account => EnumerableSet.UintSet positionIdSet) positionIdSets;
        mapping (uint256 positionId => Position position)                positions;
    }

    // keccak256(abi.encode(uint256(keccak256("spark.storage.SparkBoostedVault")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant VAULT_STORAGE_LOCATION =
        0xc17bc7d7900d416104247b8a376a9ec13ddcf9b23ba3053d5835239467c9f800;

    function _getVaultStorage() internal pure returns (VaultStorage storage $) {
        assembly {
            $.slot := VAULT_STORAGE_LOCATION
        }
    }

    /**********************************************************************************************/
    /*** Constants                                                                              ***/
    /**********************************************************************************************/

    // This corresponds to a 100% APY, verify here:
    // bc -l <<< 'scale=27; e( l(2)/(60 * 60 * 24 * 365) )'
    /// @inheritdoc ISparkBoostedVault
    uint256 public constant override MAX_VSR = 1.000000021979553151239153027e27;

    /// @inheritdoc ISparkBoostedVault
    uint256 public constant override RAY = 1e27;

    /// @inheritdoc ISparkBoostedVault
    bytes32 public constant override SETTER_ROLE = keccak256("SETTER_ROLE");

    /// @inheritdoc ISparkBoostedVault
    bytes32 public constant override TAKER_ROLE  = keccak256("TAKER_ROLE");

    /// @inheritdoc ISparkBoostedVault
    string public constant override VERSION = "1";

    /**********************************************************************************************/
    /*** Constructor                                                                            ***/
    /**********************************************************************************************/

    constructor() {
        _disableInitializers();  // Avoid initializing in the context of the implementation
    }

    /**********************************************************************************************/
    /*** Initializer                                                                            ***/
    /**********************************************************************************************/

    /// @inheritdoc ISparkBoostedVault
    function initialize(address asset_, address admin_, uint64 term_, uint64 cliff_)
        external
        override
        initializer
    {
        require(term_  != 0,     "SparkBoostedVault/invalid-term");
        require(cliff_ <= term_, "SparkBoostedVault/cliff-gt-term");

        VaultStorage storage $ = _getVaultStorage();

        $.asset  = asset_;
        $.chi    = uint192(RAY);
        $.cliff  = cliff_;
        $.maxVsr = RAY;
        $.minVsr = RAY;
        $.rho    = uint64(block.timestamp);
        $.term   = term_;
        $.vsr    = RAY;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    }

    /**********************************************************************************************/
    /*** External Interactive Admin Functions                                                   ***/
    /**********************************************************************************************/

    /// @inheritdoc ISparkBoostedVault
    function setMaxLiabilityCap(uint256 cap_) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        emit MaxLiabilityCapSet(_getVaultStorage().maxLiabilityCap = cap_);
    }

    /// @inheritdoc ISparkBoostedVault
    function setVsrBounds(uint256 minVsr_, uint256 maxVsr_)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(minVsr_ >= RAY,     "SparkBoostedVault/vsr-too-low");
        require(maxVsr_ <= MAX_VSR, "SparkBoostedVault/vsr-too-high");
        require(minVsr_ <= maxVsr_, "SparkBoostedVault/min-vsr-gt-max-vsr");

        VaultStorage storage $ = _getVaultStorage();

        emit VsrBoundsSet($.maxVsr = maxVsr_, $.minVsr = minVsr_);
    }

    /**********************************************************************************************/
    /*** External Interactive Setter Functions                                                  ***/
    /**********************************************************************************************/

    /// @inheritdoc ISparkBoostedVault
    function setVsr(uint256 vsr_) external override onlyRole(SETTER_ROLE) {
        VaultStorage storage $ = _getVaultStorage();

        require(vsr_ >= $.minVsr, "SparkBoostedVault/vsr-too-low");
        require(vsr_ <= $.maxVsr, "SparkBoostedVault/vsr-too-high");

        drip();

        emit VsrSet(msg.sender, $.vsr = vsr_);
    }

    /**********************************************************************************************/
    /*** External Interactive Taker Functions                                                   ***/
    /**********************************************************************************************/

    /// @inheritdoc ISparkBoostedVault
    function take(uint256 assets_) external override onlyRole(TAKER_ROLE) {
        _pushAsset(msg.sender, assets_);

        emit Take(msg.sender, assets_);
    }

    /**********************************************************************************************/
    /*** External Interactive Functions                                                         ***/
    /**********************************************************************************************/

    /// @inheritdoc ISparkBoostedVault
    function drip() public override {
        VaultStorage storage $ = _getVaultStorage();

        uint256 rho_ = $.rho;

        if (block.timestamp <= rho_) return;

        uint256 chi_    = $.chi;
        uint256 newChi_ = _rpow($.vsr, block.timestamp - rho_) * chi_ / RAY;

        // Safe as newChi is limited to maxUint256/RAY (which is < maxUint192).
        $.chi = uint192(newChi_);
        $.rho = uint64(block.timestamp);

        uint256 totalShares_ = $.totalShares;

        emit Drip(newChi_, ((totalShares_ * newChi_) / RAY) - ((totalShares_ * chi_) / RAY));
    }

    /// @inheritdoc ISparkBoostedVault
    function deposit(uint256 assets_) external override returns (uint256 positionId_) {
        return _deposit(assets_, 0);
    }

    /// @inheritdoc ISparkBoostedVault
    function deposit(uint256 assets_, uint16 referral_)
        external
        override
        returns (uint256 positionId_)
    {
        return _deposit(assets_, referral_);
    }

    /// @inheritdoc ISparkBoostedVault
    function withdraw(uint256 positionId_) external override {
        _withdraw(positionId_, withdrawableOf(positionId_));
    }

    /// @inheritdoc ISparkBoostedVault
    function withdraw(uint256 positionId_, uint256 assets_) external override {
        _withdraw(positionId_, assets_);
    }

    /**********************************************************************************************/
    /*** External Variable Getters                                                              ***/
    /**********************************************************************************************/

    /// @inheritdoc ISparkBoostedVault
    function asset() external view override returns (address) {
        return _getVaultStorage().asset;
    }

    /// @inheritdoc ISparkBoostedVault
    function chi() external view override returns (uint192) {
        return _getVaultStorage().chi;
    }

    /// @inheritdoc ISparkBoostedVault
    function cliff() external view override returns (uint64) {
        return _getVaultStorage().cliff;
    }

    /// @inheritdoc ISparkBoostedVault
    function maxDeposit() external view override returns (uint256) {
        uint256 maxLiability_    = maxLiability();
        uint256 maxLiabilityCap_ = _getVaultStorage().maxLiabilityCap;

        return maxLiabilityCap_ > maxLiability_ ? maxLiabilityCap_ - maxLiability_ : 0;
    }

    /// @inheritdoc ISparkBoostedVault
    function maxLiability() public view override returns (uint256) {
        return _getVaultStorage().totalShares * nowChi() / RAY;
    }

    /// @inheritdoc ISparkBoostedVault
    function maxLiabilityCap() external view override returns (uint256) {
        return _getVaultStorage().maxLiabilityCap;
    }

    /// @inheritdoc ISparkBoostedVault
    function maxVsr() external view override returns (uint256) {
        return _getVaultStorage().maxVsr;
    }

    /// @inheritdoc ISparkBoostedVault
    function minVsr() external view override returns (uint256) {
        return _getVaultStorage().minVsr;
    }

    /// @inheritdoc ISparkBoostedVault
    function nowChi() public view override returns (uint256) {
        VaultStorage storage $ = _getVaultStorage();

        return (block.timestamp > $.rho)
            ? _rpow($.vsr, block.timestamp - $.rho) * $.chi / RAY
            : $.chi;
    }

    /// @inheritdoc ISparkBoostedVault
    function rho() external view override returns (uint64) {
        return _getVaultStorage().rho;
    }

    /// @inheritdoc ISparkBoostedVault
    function term() external view override returns (uint64) {
        return _getVaultStorage().term;
    }

    /// @inheritdoc ISparkBoostedVault
    function totalPrincipal() external view override  returns (uint256) {
        return _getVaultStorage().totalPrincipal;
    }

    /// @inheritdoc ISparkBoostedVault
    function totalShares() external view override returns (uint256) {
        return _getVaultStorage().totalShares;
    }

    /// @inheritdoc ISparkBoostedVault
    function vsr() external view override returns (uint256) {
        return _getVaultStorage().vsr;
    }

    /**********************************************************************************************/
    /*** External View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    /// @inheritdoc ISparkBoostedVault
    function getPosition(uint256 positionId_) external view override returns (Position memory) {
        return _getVaultStorage().positions[positionId_];
    }

    /// @inheritdoc ISparkBoostedVault
    function getPositionIdsOf(address account_) external view override returns (uint256[] memory) {
        return _getVaultStorage().positionIdSets[account_].values();
    }

    /// @inheritdoc ISparkBoostedVault
    function getPositionsOf(address account_)
        external
        view
        override
        returns (Position[] memory positions_)
    {
        VaultStorage storage $            = _getVaultStorage();
        uint256[]    memory  positionIds_ = $.positionIdSets[account_].values();

        positions_ = new Position[](positionIds_.length);

        for (uint256 i = 0; i < positionIds_.length; ++i) {
            positions_[i] = $.positions[positionIds_[i]];
        }
    }

    /// @inheritdoc ISparkBoostedVault
    function maxWithdrawOf(uint256 positionId_) external view override returns (uint256) {
        uint256 liquidity_    = IERC20(_getVaultStorage().asset).balanceOf(address(this));
        uint256 withdrawable_ = withdrawableOf(positionId_);

        return liquidity_ > withdrawable_ ? withdrawable_ : liquidity_;
    }

    /// @inheritdoc ISparkBoostedVault
    function unvestedYieldOf(uint256 positionId_) external view override returns (uint256) {
        return yieldOf(positionId_) - vestedYieldOf(positionId_);
    }

    /// @inheritdoc ISparkBoostedVault
    function vestedYieldOf(uint256 positionId_) public view override returns (uint256) {
        return (yieldOf(positionId_) * vestingMultiplierOf(positionId_)) / RAY;
    }

    /// @inheritdoc ISparkBoostedVault
    function vestingMultiplierOf(uint256 positionId) public view override returns (uint256) {
        VaultStorage storage $         = _getVaultStorage();
        Position     storage position_ = $.positions[positionId];

        uint64 depositTime_ = position_.depositTime;

        if (depositTime_ == 0) return 0;

        uint256 elapsed_ = block.timestamp - depositTime_;

        if (elapsed_ < $.cliff) return 0;

        uint256 term_ = $.term;

        if (elapsed_ >= term_) return RAY;

        // NOTE: `elapsed_` is gated by `elapsed_ < term_` and `term_` is `uint64`, so `elapsed_^2`
        // is at most 2^128. Multiplied by RAY (~2^90) the intermediate fits in `uint256`.
        return (elapsed_ * elapsed_) * RAY / (term_ * term_);
    }

    /// @inheritdoc ISparkBoostedVault
    function withdrawableOf(uint256 positionId_) public view override returns (uint256) {
        Position storage position = _getVaultStorage().positions[positionId_];

        return position.principal + vestedYieldOf(positionId_);
    }

    /// @inheritdoc ISparkBoostedVault
    function yieldOf(uint256 positionId_) public view override returns (uint256) {
        Position storage position_ = _getVaultStorage().positions[positionId_];

        uint256 assets_ = (position_.shares * nowChi()) / RAY;

        return assets_ > position_.principal ? (assets_ - position_.principal) : 0;
    }

    /// @inheritdoc ISparkBoostedVault
    function supportsInterface(bytes4 interfaceId_)
        public
        view
        override(ISparkBoostedVault, AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return
            interfaceId_ == type(ISparkBoostedVault).interfaceId ||
            super.supportsInterface(interfaceId_);
    }

    /**********************************************************************************************/
    /*** Internal Interactive Functions                                                         ***/
    /**********************************************************************************************/

    function _deposit(uint256 assets_, uint16 referral_) internal returns (uint256 positionId_) {
        VaultStorage storage $ = _getVaultStorage();

        require(
            maxLiability() + assets_ <= $.maxLiabilityCap,
            "SparkBoostedVault/max-liability-cap-exceeded"
        );

        positionId_ = ++$.positionCount;

        drip();

        uint256 shares_ = assets_ * RAY / $.chi;

        emit Deposit(msg.sender, positionId_, assets_, shares_, referral_);

        SafeERC20.safeTransferFrom(IERC20($.asset), msg.sender, address(this), assets_);

        $.positions[positionId_] = Position({
            principal   : assets_,
            shares      : shares_,
            depositTime : uint64(block.timestamp)
        });

        $.positionIdSets[msg.sender].add(positionId_);

        $.totalShares    += shares_;
        $.totalPrincipal += assets_;
    }

    function _pushAsset(address to_, uint256 amount_) internal {
        IERC20 asset_ = IERC20(_getVaultStorage().asset);

        require(amount_ <= asset_.balanceOf(address(this)),
            "SparkBoostedVault/insufficient-liquidity"
        );

        SafeERC20.safeTransfer(asset_, to_, amount_);
    }

    function _withdraw(uint256 positionId_, uint256 assets_) internal {
        drip();

        uint256 withdrawable_ = withdrawableOf(positionId_);

        require(withdrawable_ != 0, "SparkBoostedVault/zero-position");

        VaultStorage          storage $              = _getVaultStorage();
        EnumerableSet.UintSet storage positionIdSet_ = $.positionIdSets[msg.sender];

        require(positionIdSet_.contains(positionId_), "SparkBoostedVault/not-owner");

        Position storage position_ = $.positions[positionId_];

        uint256 shares_           = position_.shares;
        uint256 principal_        = position_.principal;
        uint256 sharePortion_     = (shares_ * assets_) / withdrawable_;
        uint256 principalPortion_ = (principal_ * assets_) / withdrawable_;

        if (sharePortion_ == shares_ || principalPortion_ == principal_) {
            positionIdSet_.remove(positionId_);

            delete $.positions[positionId_];

            sharePortion_     = shares_;
            principalPortion_ = principal_;
        } else {
            position_.shares    = shares_ - sharePortion_;
            position_.principal = principal_ - principalPortion_;
        }

        $.totalShares    -= sharePortion_;
        $.totalPrincipal -= principalPortion_;

        emit Withdraw(msg.sender, positionId_, assets_, sharePortion_);

        _pushAsset(msg.sender, assets_);
    }

    /**********************************************************************************************/
    /*** Internal View/Pure Functions                                                           ***/
    /**********************************************************************************************/

    // Only DEFAULT_ADMIN_ROLE can upgrade the implementation
    function _authorizeUpgrade(address) internal view override onlyRole(DEFAULT_ADMIN_ROLE) {}

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
