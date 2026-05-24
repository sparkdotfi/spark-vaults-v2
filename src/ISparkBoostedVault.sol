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

import { IAccessControlEnumerable } from "openzeppelin-contracts/contracts/access/extensions/IAccessControlEnumerable.sol";

interface ISparkBoostedVault is IAccessControlEnumerable {

    /**
     * @notice ERC4626 deposit event.
     * @param  sender The msg.sender that supplied the assets.
     * @param  owner  The address receiving the position credit.
     * @param  assets The amount of underlying assets deposited.
     * @param  shares The raw rate-based shares credited to the position.
     */
    event Deposit(
        address indexed sender,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /**
     * @notice ERC4626 withdraw event.
     * @param  sender   The msg.sender initiating the withdraw.
     * @param  receiver The address receiving the withdrawn assets.
     * @param  owner    The position owner whose state was reduced.
     * @param  assets   The amount of underlying assets sent to receiver.
     * @param  shares   The raw rate-based shares burned from the position.
     */
    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /**
     * @notice Emitted every time drip() is called.
     * @param  chi  The new rate accumulator value after the drip [ray]
     * @param  diff The change in raw total assets [asset units]
     */
    event Drip(uint256 chi, uint256 diff);

    /**
     * @notice Emitted when a deposit is annotated with a referral.
     * @param  referral The 16-bit referral identifier.
     * @param  owner    The position owner.
     * @param  assets   The deposited assets.
     * @param  shares   The raw shares credited.
     */
    event Referral(
        uint16 indexed referral,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /**
     * @notice Emitted when the deposit cap is updated.
     * @param  oldCap Previous cap [asset units]
     * @param  newCap New cap [asset units]
     */
    event DepositCapSet(uint256 oldCap, uint256 newCap);

    /**
     * @notice Emitted when the VSR bounds are updated.
     * @param  oldMinVsr Previous minimum [ray]
     * @param  oldMaxVsr Previous maximum [ray]
     * @param  newMinVsr New minimum [ray]
     * @param  newMaxVsr New maximum [ray]
     */
    event VsrBoundsSet(
        uint256 oldMinVsr,
        uint256 oldMaxVsr,
        uint256 newMinVsr,
        uint256 newMaxVsr
    );

    /**
     * @notice Emitted when the VSR is updated.
     * @param  sender The caller with SETTER_ROLE.
     * @param  oldVsr Previous VSR [ray]
     * @param  newVsr New VSR [ray]
     */
    event VsrSet(address indexed sender, uint256 oldVsr, uint256 newVsr);

    /**
     * @notice Emitted when an account with TAKER_ROLE withdraws assets.
     * @param  to    The TAKER_ROLE recipient.
     * @param  value The amount taken [asset units]
     */
    event Take(address indexed to, uint256 value);

    /**
     * @notice Emitted when a user's position state is mutated.
     * @param  owner       The position owner.
     * @param  principal   The new principal [asset units]
     * @param  shares      The new raw shares.
     * @param  depositTime The new effective deposit timestamp [unix epoch time]
     */
    event PositionUpdated(
        address indexed owner,
        uint256 principal,
        uint256 shares,
        uint64  depositTime
    );

    function asset()          external view returns (address);
    function decimals()       external view returns (uint8);
    function name()           external view returns (string memory);
    function symbol()         external view returns (string memory);
    function version()        external view returns (string memory);

    function term()           external view returns (uint64);
    function cliff()          external view returns (uint64);

    function chi()            external view returns (uint192);
    function nowChi()         external view returns (uint256);
    function drip()           external returns (uint256);
    function rho()            external view returns (uint64);
    function vsr()            external view returns (uint256);
    function minVsr()         external view returns (uint256);
    function maxVsr()         external view returns (uint256);

    function depositCap()     external view returns (uint256);
    function totalShares()    external view returns (uint256);
    function totalPrincipal() external view returns (uint256);

    function positions(address user) external view returns (
        uint256 principal,
        uint256 shares,
        uint64  depositTime
    );

    function principalOf(address user)      external view returns (uint256);
    function sharesOf(address user)         external view returns (uint256);
    function depositTimeOf(address user)    external view returns (uint64);
    function assetsOf(address user)         external view returns (uint256);
    function vestingMultiplier(address user)external view returns (uint256);
    function vestedYieldOf(address user)    external view returns (uint256);
    function unvestedYieldOf(address user)  external view returns (uint256);
    function withdrawableOf(address user)   external view returns (uint256);

    function setDepositCap(uint256 newCap)                   external;
    function setVsr(uint256 newVsr)                          external;
    function setVsrBounds(uint256 minVsr_, uint256 maxVsr_)  external;
    function take(uint256 value)                             external;

    function deposit(uint256 assets)                  external returns (uint256 shares);
    function deposit(uint256 assets, uint16 referral) external returns (uint256 shares);
    function withdraw()                               external returns (uint256 assets);

    function totalAssets()                   external view returns (uint256);
    function assetsOutstanding()             external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function maxDeposit(address receiver)    external view returns (uint256);
    function maxWithdraw(address owner)      external view returns (uint256);
    function previewDeposit(uint256 assets)  external view returns (uint256);

}
