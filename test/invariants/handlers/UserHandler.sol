// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { HandlerBase } from "./HandlerBase.sol";

contract UserHandler is HandlerBase {

    uint256 public numUsers;

    address[] public users;

    mapping (address user => uint256 lastBalance) public lastBalanceOf;
    mapping (address user => uint256 lastAssets)  public lastAssetsOf;

    uint256 public totalBalance;

    constructor(address vault_, uint256 numUsers_) HandlerBase(vault_) {
        numUsers = numUsers_;
        for (uint256 i = 0; i < numUsers_; i++) {
            users.push(makeAddr(string(abi.encodePacked("user", i))));
        }
    }

    function _getRandomUser(uint256 userIndex) internal returns (address) {
        return users[_bound(userIndex, 0, users.length - 1)];
    }

    function deposit(uint256 assetAmount, uint32 userIndex) public totalAssetsCheck accountingCheck {
        address user = _getRandomUser(userIndex);

        assetAmount = _bound(assetAmount, 0, MAX_AMOUNT);

        deal(address(asset), user, assetAmount);

        vm.startPrank(user);
        asset.approve(address(vault), assetAmount);
        uint256 shares = vault.deposit(assetAmount, address(user));
        vm.stopPrank();

        lastBalanceOf[user] = vault.balanceOf(user);
        lastAssetsOf[user]  = vault.assetsOf(user);

        totalBalance += shares;
    }

    function mint(uint256 shareAmount, uint32 userIndex) public totalAssetsCheck accountingCheck {
        address user = _getRandomUser(userIndex);

        shareAmount = _bound(shareAmount, 0, MAX_AMOUNT);

        uint256 previewAssetAmount = vault.previewMint(shareAmount);

        deal(address(asset), address(user), previewAssetAmount);

        vm.startPrank(user);
        asset.approve(address(vault), previewAssetAmount);
        uint256 assetAmount = vault.mint(shareAmount, address(user));
        vm.stopPrank();

        assertEq(assetAmount, previewAssetAmount);

        lastBalanceOf[user] = vault.balanceOf(user);
        lastAssetsOf[user]  = vault.assetsOf(user);

        totalBalance += shareAmount;
    }

    function withdraw(uint256 assetAmount, uint32 userIndex) public accountingCheck {
        address user = _getRandomUser(userIndex);

        uint256 effectiveAssets = Math.min(vault.assetsOf(user), asset.balanceOf(address(vault)));

        assetAmount = _bound(assetAmount, 0, effectiveAssets);

        vm.prank(user);
        uint256 shares = vault.withdraw(assetAmount, address(user), address(user));

        lastBalanceOf[user] = vault.balanceOf(user);
        lastAssetsOf[user]  = vault.assetsOf(user);

        totalBalance -= shares;
    }

    function redeem(uint256 shareAmount, uint32 userIndex) public accountingCheck {
        address user = _getRandomUser(userIndex);

        uint256 effectiveAssets = Math.min(vault.assetsOf(user), asset.balanceOf(address(vault)));
        uint256 effectiveShares = vault.convertToShares(effectiveAssets);

        shareAmount = _bound(shareAmount, 0, effectiveShares);

        vm.prank(user);
        vault.redeem(shareAmount, address(user), address(user));

        lastBalanceOf[user] = vault.balanceOf(user);
        lastAssetsOf[user]  = vault.assetsOf(user);

        totalBalance -= shareAmount;
    }

}
