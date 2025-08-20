// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./a_init.sol";

contract FlowsErc4626 is Init {

    constructor(address _vault) Init(_vault) {}

    function deposit(uint256 assetAmount, uint32 userIndex) external {
        numCalls["deposit"]++;
        address user = getRandomUser(userIndex);
        assetAmount  = _bound(assetAmount, 0, 10_000_000_000 * 10 ** asset.decimals());

        deal(address(asset), user, assetAmount);
        asset.approve(address(vault), assetAmount);
        uint256 shareAmount = vault.deposit(assetAmount, address(user));
        lastBalanceOf[user] += shareAmount;
        lastAssetsOf[user] += assetAmount;
    }

    function mint(uint256 shareAmount, uint32 userIndex) external {
        numCalls["mint"]++;
        address user = getRandomUser(userIndex);
        shareAmount = _bound(shareAmount, 0, 10_000_000_000 * 10 ** vault.decimals());

        uint256 previewAssetAmount = vault.previewMint(shareAmount);
        deal(address(asset), address(user), previewAssetAmount);
        asset.approve(address(vault), previewAssetAmount);
        uint256 assetAmount = vault.mint(shareAmount, address(user));
        assertEq(assetAmount, previewAssetAmount);
        lastBalanceOf[user] += shareAmount;
        lastAssetsOf[user] += assetAmount;
    }

    function withdraw(uint256 assetAmount, uint32 userIndex) external {
        numCalls["withdraw"]++;
        address user = getRandomUser(userIndex);

        assetAmount = _bound(assetAmount, 0, vault.assetsOf(user));
        uint256 shareAmount = vault.withdraw(assetAmount, address(user), address(user));
        lastBalanceOf[user] -= shareAmount;
        lastAssetsOf[user] -= assetAmount;
    }

    function withdrawAll(uint32 userIndex) external {
        numCalls["withdrawAll"]++;
        address user = getRandomUser(userIndex);

        uint256 assetAmount = vault.assetsOf(user);
        uint256 shareAmount = vault.withdraw(assetAmount, address(user), address(user));
        assertEq(vault.balanceOf(user), 0);
        assertEq(vault.assetsOf(user), 0);
        lastBalanceOf[user] = 0;
        lastAssetsOf[user] = 0;
    }

    function redeem(uint256 shareAmount, uint32 userIndex) external {
        numCalls["redeem"]++;
        address user = getRandomUser(userIndex);
        shareAmount = _bound(shareAmount, 0, vault.balanceOf(user));

        uint256 assetAmount = vault.redeem(shareAmount, address(this), address(this));
        lastBalanceOf[user] -= shareAmount;
        lastAssetsOf[user] -= assetAmount;
    }

    function redeemAll(uint32 userIndex) external {
        numCalls["redeemAll"]++;
        address user = getRandomUser(userIndex);

        vault.redeem(vault.balanceOf(address(user)), address(user), address(user));
        assertEq(vault.balanceOf(user), 0);
        assertEq(vault.assetsOf(user), 0);
        lastBalanceOf[user] = 0;
        lastAssetsOf[user] = 0;
    }
}
