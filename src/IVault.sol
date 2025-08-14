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

interface IVault is IERC20Permit, IERC4626 {

    // Events
    event Drip(uint256 chi, uint256 diff);
    event Referral(uint16 indexed referral, address indexed owner, uint256 assets, uint256 shares);
    event SsrBoundsSet(uint256 minSsr, uint256 maxSsr);
    event SsrSet(address indexed sender, uint256 oldSsr, uint256 newSsr);
    event Take(address indexed to, uint256 value);

    // Valuation functions
    function chi() external view returns (uint192);
    function drip() external returns (uint256);
    function rho() external view returns (uint64);
    function setSsr(uint256 data) external;
    function ssr() external view returns (uint256);

    // ERC4626 functions with referrals
    function deposit(uint256, address, uint16) external returns (uint256);
    function mint(uint256, address, uint16) external returns (uint256);

    // Permissioned withdrawal function
    function take(uint256 value) external;

    // Versioning function TODO: Do we need this?
    function version() external view returns (string memory);

}
