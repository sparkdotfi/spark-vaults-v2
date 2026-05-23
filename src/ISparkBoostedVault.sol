// SPDX-License-Identifier: AGPL-3.0-or-later

// Copyright (C) 2021 Dai Foundation
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.8.35;

import {
    IAccessControlEnumerable
} from "../lib/openzeppelin-contracts/contracts/access/extensions/IAccessControlEnumerable.sol";

interface ISparkBoostedVault is IAccessControlEnumerable {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    /**
     * @notice Represents a user's deposit position in the vault.
     * @param  principal   Asset amount the account has put in, minus any withdrawn principal.
     * @param  shares      Raw rate-based shares; raw assets = shares * chi / RAY.
     * @param  depositTime Effective deposit time, blended on deposit and partial withdraw.
     */
    struct Position {
        uint256 principal;   // Asset amount put in, minus any withdrawn principal.
        uint256 shares;      // Raw rate-based shares; raw assets = shares * chi / RAY.
        uint64  depositTime; // Effective deposit time, blended on deposit/withdraw.
    }

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @notice The deposit event.
     * @param  account    The address depositing the assets.
     * @param  positionId The unique identifier of the position.
     * @param  assets     The amount of underlying assets deposited.
     * @param  shares     The raw rate-based shares credited to the position.
     * @param  referral   The 16-bit referral identifier.
     */
    event Deposit(
        address indexed account,
        uint256 indexed positionId,
        uint256         assets,
        uint256         shares,
        uint16  indexed referral
    );

    /**
     * @notice Emitted when the maximum liability cap is updated.
     * @param  cap New cap [asset units].
     */
    event MaxLiabilityCapSet(uint256 cap);

    /**
     * @notice Emitted every time drip() is called at a new rho.
     * @param  chi  The new rate accumulator value after the drip [ray].
     * @param  diff The change in raw total assets [asset units].
     */
    event Drip(uint256 chi, uint256 diff);

    /**
     * @notice Emitted when an account with TAKER_ROLE withdraws assets.
     * @param  to     The TAKER_ROLE recipient.
     * @param  assets The amount taken [asset units]
     */
    event Take(address indexed to, uint256 assets);

    /**
     * @notice Emitted when the VSR bounds are updated.
     * @param  maxVsr New maximum [ray].
     * @param  minVsr New minimum [ray].
     */
    event VsrBoundsSet(uint256 maxVsr, uint256 minVsr);

    /**
     * @notice Emitted when the VSR is updated.
     * @param  sender The caller with SETTER_ROLE.
     * @param  vsr    The new VSR [ray].
     */
    event VsrSet(address indexed sender, uint256 vsr);

    /**
     * @notice ERC4626 withdraw event.
     * @param  account    The position owner whose state was reduced.
     * @param  positionId The unique identifier of the position.
     * @param  assets     The amount of underlying assets sent to receiver.
     * @param  shares     The raw rate-based shares burned from the position.
     */
    event Withdraw(
        address indexed account,
        uint256 indexed positionId,
        uint256         assets,
        uint256         shares
    );

    /**********************************************************************************************/
    /*** Interactive Functions                                                                  ***/
    /**********************************************************************************************/

    /**
     * @notice Deposits specified assets into the vault with a referral tracker, creating a new
     *         position.
     * @dev    Updates the rate accumulator (drips) before depositing.
     *         Reverts if total assets exceeds max liability cap.
     * @param  assets_     The amount of underlying assets to deposit.
     * @param  referral_   The 16-bit referral identifier for tracking user acquisition.
     * @return positionId_ The unique identifier of the newly created position.
     */
    function deposit(uint256 assets_, uint16 referral_) external returns (uint256 positionId_);

    /**
     * @notice Deposits specified assets into the vault, creating a new position.
     * @dev    Updates the rate accumulator (drips) before depositing.
     *         Reverts if total assets exceeds max liability cap.
     * @param  assets_     The amount of underlying assets to deposit.
     * @return positionId_ The unique identifier of the newly created position.
     */
    function deposit(uint256 assets_) external returns (uint256 positionId_);

    /**
     * @notice Updates the rate accumulator (chi) based on the elapsed time and current Vault
     *         Savings Rate (VSR).
     * @dev    Calculates the new chi value based on: new_chi = old_chi * (vsr)^delta_t / RAY.
     *         Updates the last update timestamp (rho) to the current block timestamp.
     */
    function drip() external;

    /**
     * @notice Initializes the boosted vault implementation with core configuration.
     * @dev    Can only be called once. Sets initial storage parameters, sets chi/vsr/minVsr/maxVsr
     *         to RAY, sets rho to block.timestamp, and grants DEFAULT_ADMIN_ROLE to `admin_`.
     * @param  asset_ The address of the underlying asset.
     * @param  admin_ The address to be granted the admin role.
     * @param  term_  The total vesting duration [seconds].
     * @param  cliff_ The vesting cliff duration [seconds], must be less than or equal to `term_`.
     */
    function initialize(address asset_, address admin_, uint64 term_, uint64 cliff_) external;

    /**
     * @notice Sets the maximum liability cap for the vault.
     * @dev    Can only be called by accounts with DEFAULT_ADMIN_ROLE.
     *         Deposits are disabled if they would cause the total liability to exceed this cap.
     * @param  cap_ The new maximum liability cap [asset units].
     */
    function setMaxLiabilityCap(uint256 cap_) external;

    /**
     * @notice Sets the Vault Savings Rate (VSR).
     * @dev    Can only be called by accounts with SETTER_ROLE.
     *         Triggers a drip update before updating the rate.
     *         The rate must be within the configured min/max bounds.
     * @param  vsr_ The new VSR value [ray].
     */
    function setVsr(uint256 vsr_) external;

    /**
     * @notice Sets the minimum and maximum bounds for the Vault Savings Rate (VSR).
     * @dev    Can only be called by accounts with DEFAULT_ADMIN_ROLE.
     *         Ensures minVsr_ is at least RAY, maxVsr_ is at most MAX_VSR, and minVsr_ <= maxVsr_.
     * @param  minVsr_ The new minimum allowed VSR value [ray].
     * @param  maxVsr_ The new maximum allowed VSR value [ray].
     */
    function setVsrBounds(uint256 minVsr_, uint256 maxVsr_) external;

    /**
     * @notice Allows authorized accounts with TAKER_ROLE to withdraw assets from the vault.
     * @dev    Transfers the specified amount of underlying assets to the caller.
     * @param  value_ The amount of assets to withdraw [asset units].
     */
    function take(uint256 value_) external;

    /**
     * @notice Withdraws all assets from a specific position.
     * @dev    Updates the rate accumulator (drips) before executing.
     *         Zeros shares and principal.
     *         Reverts if caller is not the owner of the position, or if position does not exist.
     * @param  positionId_ The unique identifier of the position.
     */
    function withdraw(uint256 positionId_) external;

    /**
     * @notice Withdraws assets from a specific position.
     * @dev    Updates the rate accumulator (drips) before executing.
     *         Reduces shares and principal proportionally based on the withdrawable assets.
     *         Reverts if caller is not the owner of the position, or if position does not exist.
     * @param  positionId_ The unique identifier of the position.
     * @param  assets_     The amount of underlying assets to withdraw.
     */
    function withdraw(uint256 positionId_, uint256 assets_) external;

    /**********************************************************************************************/
    /*** Variables.                                                                             ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the absolute maximum allowed Vault Savings Rate (VSR).
     */
    function MAX_VSR() external view returns (uint256);

    /**
     * @notice Returns the precision multiplier representing 1.0 (1e27).
     */
    function RAY() external view returns (uint256);

    /**
     * @notice Returns the identifier of the role that can set the VSR.
     */
    function SETTER_ROLE() external view returns (bytes32);

    /**
     * @notice Returns the identifier of the role that can take assets.
     */
    function TAKER_ROLE() external view returns (bytes32);

    /**
     * @notice Returns the implementation version string.
     */
    function VERSION() external view returns (string memory);

    /**
     * @notice Returns the address of the underlying asset.
     */
    function asset() external view returns (address);

    /**
     * @notice Returns the rate accumulator (chi) as of the last drip.
     */
    function chi() external view returns (uint192);

    /**
     * @notice Returns the vesting cliff duration configured for positions.
     */
    function cliff() external view returns (uint64);

    /**
     * @notice Returns the maximum amount of assets that can be currently deposited.
     * @dev    Calculated as the difference between the max liability cap and the current total
     *         liability.
     */
    function maxDeposit() external view returns (uint256);

    /**
     * @notice Returns the current total liability of the vault calculated up to the current
     *         block timestamp.
     */
    function maxLiability() external view returns (uint256);

    /**
     * @notice Returns the maximum liability cap of the vault.
     */
    function maxLiabilityCap() external view returns (uint256);

    /**
     * @notice Returns the maximum allowed VSR value.
     */
    function maxVsr() external view returns (uint256);

    /**
     * @notice Returns the minimum allowed VSR value.
     */
    function minVsr() external view returns (uint256);

    /**
     * @notice Returns the rate accumulator (chi) calculated up to the current block timestamp.
     */
    function nowChi() external view returns (uint256);

    /**
     * @notice Returns the timestamp of the last drip operation.
     */
    function rho() external view returns (uint64);

    /**
     * @notice Returns the total vesting duration configured for positions.
     */
    function term() external view returns (uint64);

    /**
     * @notice Returns the total principal deposited across all active positions.
     */
    function totalPrincipal() external view returns (uint256);

    /**
     * @notice Returns the total shares issued across all active positions.
     */
    function totalShares() external view returns (uint256);

    /**
     * @notice Returns the current Vault Savings Rate (VSR).
     */
    function vsr() external view returns (uint256);

    /**********************************************************************************************/
    /*** View/Pure Functions                                                                    ***/
    /**********************************************************************************************/

    /**
     * @notice Returns the details of a specific position.
     * @param  positionId_ The unique identifier of the position.
     * @return position_   The Position struct details.
     */
    function getPosition(uint256 positionId_) external view returns (Position memory position_);

    /**
     * @notice Returns all position identifiers owned by a specific account.
     * @param  account_     The address of the owner account.
     * @return positionIds_ An array of position identifiers.
     */
    function getPositionIdsOf(address account_)
        external
        view
        returns (uint256[] memory positionIds_);

    /**
     * @notice Returns all position details owned by a specific account.
     * @param  account_   The address of the owner account.
     * @return positions_ An array of Position structs.
     */
    function getPositionsOf(address account_) external view returns (Position[] memory positions_);

    /**
     * @notice Returns the maximum assets that can be withdrawn from a position, constrained by
     *         contract liquidity.
     * @param  positionId_  The unique identifier of the position.
     * @return maxWithdraw_ The maximum withdrawable amount [asset units].
     */
    function maxWithdrawOf(uint256 positionId_) external view returns (uint256 maxWithdraw_);

    /**
     * @notice Returns the unvested yield of a position.
     * @param  positionId_    The unique identifier of the position.
     * @return unvestedYield_ The amount of unvested yield [asset units].
     */
    function unvestedYieldOf(uint256 positionId_) external view returns (uint256 unvestedYield_);

    /**
     * @notice Returns the vested yield of a position.
     * @param  positionId_  The unique identifier of the position.
     * @return vestedYield_ The amount of vested yield [asset units].
     */
    function vestedYieldOf(uint256 positionId_) external view returns (uint256 vestedYield_);

    /**
     * @notice Returns the vesting multiplier [ray] for the user's current position.
     *         A return of 0 means none of the yield has vested.
     *         A return of RAY means yield is fully vested.
     * @param  positionId_ The unique identifier of the position.
     * @return multiplier_ The vesting multiplier [ray].
     */
    function vestingMultiplierOf(uint256 positionId_) external view returns (uint256 multiplier_);

    /**
     * @notice Returns the total withdrawable assets of a position (principal + vested yield).
     * @param  positionId_   The unique identifier of the position.
     * @return withdrawable_ The amount of withdrawable assets [asset units].
     */
    function withdrawableOf(uint256 positionId_) external view returns (uint256 withdrawable_);

    /**
     * @notice Returns the total yield (both vested and unvested) accrued by a position.
     * @param  positionId_ The unique identifier of the position.
     * @return yield_      The total yield [asset units].
     */
    function yieldOf(uint256 positionId_) external view returns (uint256 yield_);

    /**
     * @notice Checks if the contract supports a specific interface.
     * @param  interfaceId_ The interface identifier, as specified in ERC-165.
     * @return isSupported_ True if the contract supports the interface, false otherwise.
     */
    function supportsInterface(bytes4 interfaceId_) external view returns (bool isSupported_);

}
