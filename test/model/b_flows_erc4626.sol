// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./a_init.sol";

contract FlowsErc4626 is Init {

    constructor(address _vault) Init(_vault) {}

    function deposit(uint256 assetAmount) external {
        assetAmount = _bound(assetAmount, 0, type(uint256).max);
        numCalls["deposit"]++;
        deal(address(asset), address(this), assetAmount);
        asset.approve(address(vault), assetAmount);

        // Consider the first expression of `deposit`:
        // function deposit(uint256 assetAmount, address receiver) public returns (uint256 shares) {
        //     shares = assetAmount * RAY / drip();
        // assetAmount * RAY <= type(uint256).max, hence
        // assetAmount <= type(uint256).max / RAY

        bool fail = assetAmount > type(uint256).max / RAY;
        if (fail) {
            vm.expectRevert(stdError.arithmeticError);
        }
        vault.deposit(assetAmount, address(this));
    }

    function mint(uint256 shareAmount) external {
        numCalls["mint"]++;

        // Consider the first expression of `previewMint`:
        // function previewMint(uint256 shareAmount) external view returns (uint256) {
        //     return _divup(shareAmount * nowChi(), RAY);
        // shareAmount * nowChi() <= type(uint256).max, hence
        // shareAmount <= type(uint256).max / nowChi()
        bool fail = shareAmount > type(uint256).max / vault.nowChi();
        if (fail) {
            vm.expectRevert(stdError.arithmeticError); vault.previewMint(shareAmount);
            return;
        }
        deal(address(asset), address(this), vault.previewMint(shareAmount));
        asset.approve(address(vault), vault.previewMint(shareAmount));

        // Consider the first expression of `mint`:
        // function mint(uint256 shareAmount, address receiver) public returns (uint256 assets) {
        //     assets = _divup(shareAmount * drip(), RAY);
        // shareAmount * drip() <= type(uint256).max, hence
        // shareAmount <= type(uint256).max / drip()

        // drip() potentially increases the denominator, so just because we succeeded before doesn't
        // mean we will succeed now. This will occur when
        // type(uint256).max / vault.drip() < shareAmount <= type(uint256).max / vault.nowChi()
        fail = shareAmount > type(uint256).max / vault.drip();

        if (fail) {
            vm.expectRevert(stdError.arithmeticError);
        }
        vault.mint(shareAmount, address(this));
    }

    function withdraw(uint256 assetAmount) external {
        numCalls["withdraw"]++;
        assetAmount = _bound(assetAmount, 0, vault.previewWithdraw(vault.balanceOf(address(this))));
        vault.withdraw(assetAmount, address(this), address(this));
    }

    function withdrawAll() external {
        numCalls["withdrawAll"]++;
        vault.withdraw(vault.previewWithdraw(vault.balanceOf(address(this))), address(this), address(this));
    }

    function redeem(uint256 shareAmount) external {
        numCalls["redeem"]++;
        shareAmount = _bound(shareAmount, 0, vault.balanceOf(address(this)));
        vault.redeem(shareAmount, address(this), address(this));
    }

    function redeemAll() external {
        numCalls["redeemAll"]++;
        vault.redeem(vault.balanceOf(address(this)), address(this), address(this));
    }
}
