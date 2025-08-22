// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.25;

import "./a_init.sol";

contract FlowsErc4626 is Init {

    constructor(address _vault) Init(_vault) {}

    function deposit(uint256 assetAmount, uint32 userIndex) public totalAssetsCheck accountingCheck {
        numCalls["deposit"]++;
        address user = getRandomUser(userIndex);
        assetAmount  = _bound(assetAmount, 0, 10_000_000_000 * 10 ** asset.decimals());

        deal(address(asset), user, assetAmount);
        asset.approve(address(vault), assetAmount);
        vault.deposit(assetAmount, address(user));
        lastBalanceOf[user] = vault.balanceOf(user);
        lastAssetsOf[user]  = vault.assetsOf(user);
        vm.stopPrank();
    }

    function mint(uint256 shareAmount, uint32 userIndex) public totalAssetsCheck accountingCheck {
        numCalls["mint"]++;
        address user = getRandomUser(userIndex);
        shareAmount = _bound(shareAmount, 0, 10_000_000_000 * 10 ** vault.decimals());

        uint256 previewAssetAmount = vault.previewMint(shareAmount);
        deal(address(asset), address(user), previewAssetAmount);
        asset.approve(address(vault), previewAssetAmount);
        uint256 assetAmount = vault.mint(shareAmount, address(user));
        assertEq(assetAmount, previewAssetAmount);
        lastBalanceOf[user] = vault.balanceOf(user);
        lastAssetsOf[user]  = vault.assetsOf(user);
        vm.stopPrank();
    }

    function withdraw(uint256 assetAmount, uint32 userIndex) public accountingCheck {
        numCalls["withdraw"]++;
        address user = getRandomUser(userIndex);
        uint256 effectiveAssets = Math.min(vault.assetsOf(user), asset.balanceOf(address(vault)));
        assetAmount = _bound(assetAmount, 0, effectiveAssets);

        vault.withdraw(assetAmount, address(user), address(user));
        lastBalanceOf[user] = vault.balanceOf(user);
        lastAssetsOf[user]  = vault.assetsOf(user);
        vm.stopPrank();
    }

    function redeem(uint256 shareAmount, uint32 userIndex) public accountingCheck {
        numCalls["redeem"]++;
        address user = getRandomUser(userIndex);
        uint256 effectiveAssets = Math.min(vault.assetsOf(user), asset.balanceOf(address(vault)));
        uint256 effectiveShares = vault.convertToShares(effectiveAssets);
        shareAmount = _bound(shareAmount, 0, effectiveShares);

        vault.redeem(shareAmount, address(user), address(user));
        lastBalanceOf[user] = vault.balanceOf(user);
        lastAssetsOf[user]  = vault.assetsOf(user);
        vm.stopPrank();
    }

}
