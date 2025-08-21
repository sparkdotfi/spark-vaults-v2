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

pragma solidity >=0.8.0;

import { IERC4626 }     from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { IERC20Permit } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";

interface ISparkVault is IERC20Permit, IERC4626 {

    /**
     * @notice Emitted every time drip() is called.
     * @param  chi  The new rate accumulator value after the drip operation [ray]
     * @param  diff The difference in total assets due to the rate accumulation [wei]
     */
    event Drip(uint256 chi, uint256 diff);

    /**
     * @notice Emitted when assets are deposited or shares are minted with referral tracking.
     * @param  referral The referral ID (16-bit) used for tracking user acquisition
     * @param  owner    The address receiving the minted shares
     * @param  assets   The amount of underlying assets deposited/minted
     * @param  shares   The amount of vault shares minted to the owner
     */
    event Referral(uint16 indexed referral, address indexed owner, uint256 assets, uint256 shares);

    /**
     * @notice Emitted when the bounds for the Spark Savings Rate (SSR) are updated.
     * @param  oldMinSsr The previous minimum allowed SSR value [ray]
     * @param  oldMaxSsr The previous maximum allowed SSR value [ray]
     * @param  newMinSsr The new minimum allowed SSR value [ray]
     * @param  newMaxSsr The new maximum allowed SSR value [ray]
     */
    event SsrBoundsSet(uint256 oldMinSsr, uint256 oldMaxSsr, uint256 newMinSsr, uint256 newMaxSsr);

    /**
     * @notice Emitted when the Spark Savings Rate (SSR) is updated.
     * @param  sender The address that called setSsr() to update the rate
     * @param  oldSsr The previous SSR value before the update [ray]
     * @param  newSsr The new SSR value after the update [ray]
     */
    event SsrSet(address indexed sender, uint256 oldSsr, uint256 newSsr);

    /**
     * @notice Emitted when assets are withdrawn from the vault by accounts with TAKER_ROLE.
     * @param  to    The address receiving the withdrawn assets
     * @param  value The amount of assets withdrawn from the vault [wei]
     */
    event Take(address indexed to, uint256 value);

    /**
     * @notice Returns the current rate accumulator (chi).
     * @dev    Chi represents the cumulative growth factor for all shares. It starts at 1e27 (RAY) and
     *         increases exponentially over time based on the Spark Savings Rate (SSR). The formula is:
     *         chi = chi_old * (ssr)^(time_delta) / RAY where time_delta is the time since last drip.
     *         User assets = user_shares * nowChi() / RAY
     * @return The current rate accumulator value [ray]
     */
    function chi() external view returns (uint192);

    /**
     * @notice Updates the rate accumulator and returns the new value.
     * @dev    This function calculates the new chi value based on the time elapsed since the last drip
     *         and the current SSR. The formula used is:
     *         new_chi = old_chi * (ssr)^(block.timestamp - rho) / RAY
     * @return nChi The new Chi value [ray]
     */
    function drip() external returns (uint256);

    /**
     * @notice Returns the timestamp of the last drip operation.
     * @dev    rho tracks when the rate accumulator was last updated.
     * @return The timestamp of the last drip [unix epoch time]
     */
    function rho() external view returns (uint64);

    /**
     * @notice Sets the Spark Savings Rate (SSR) within the configured bounds.
     * @dev    This function can only be called by accounts with SETTER_ROLE.
     *         The SSR determines the rate at which user shares grow over time. A higher SSR
     *         means faster share growth and higher yields for depositors.
     * @param  data The new SSR value [ray]
     */
    function setSsr(uint256 data) external;

    /**
     * @notice Returns the current Spark Savings Rate (SSR).
     * @dev    The SSR is the rate at which the vault's shares appreciate in value over time.
     *         It's expressed in ray (1e27).
     * @return The current SSR value [ray]
     */
    function ssr() external view returns (uint256);

    /**
     * @notice Deposits specified assets and mints shares.
     * @param  assets   The amount of assets to deposit
     * @param  receiver The address to receive the minted shares
     * @param  referral The referral ID (16-bit) for tracking
     * @return shares   The amount of shares minted
     */
    function deposit(uint256 assets, address receiver, uint16 referral) external returns (uint256 shares);

    /**
     * @notice Mints specified shares and pulls assets from the caller.
     * @param  shares   The amount of shares to mint
     * @param  receiver The address to receive the minted shares
     * @param  referral The referral ID (16-bit) for tracking
     * @return assets   The amount of assets transferred from the caller.
     */
    function mint(uint256 shares, address receiver, uint16 referral) external returns (uint256 assets);

    /**
     * @notice Allows authorized accounts to withdraw assets from the vault.
     * @dev    This function can only be called by accounts with TAKER_ROLE.
     *         The function transfers the specified amount of assets to the caller.
     * @param  value The amount of assets to withdraw
     */
    function take(uint256 value) external;

    /**
     * @notice Returns the version of the vault implementation.
     * @return The version string.
     */
    function version() external view returns (string memory);

}
