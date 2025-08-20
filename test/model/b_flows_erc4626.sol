// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./a_init.sol";

contract FlowsErc4626 is Init {

    constructor(address _vault) Init(_vault) {}

    function deposit(uint256 assets) external {
        numCalls["deposit"]++;
        deal(address(asset), address(this), assets);
        asset.approve(address(vault), assets);

        // Consider the first expression of `deposit`:
        // function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        //     shares = assets * RAY / drip();
        // assets * RAY <= type(uint256).max, hence
        // assets <= type(uint256).max / RAY

        bool fail = assets > type(uint256).max / RAY;
        if (fail) {
            vm.expectRevert(stdError.arithmeticError);
        }
        vault.deposit(assets, address(this));
    }

    function mint(uint256 shares) external {
        numCalls["mint"]++;

        // Consider the first expression of `previewMint`:
        // function previewMint(uint256 shares) external view returns (uint256) {
        //     return _divup(shares * nowChi(), RAY);
        // shares * nowChi() <= type(uint256).max, hence
        // shares <= type(uint256).max / nowChi()
        bool fail = shares > type(uint256).max / vault.nowChi();
        if (fail) {
            vm.expectRevert(stdError.arithmeticError); vault.previewMint(shares);
            return;
        }
        deal(address(asset), address(this), vault.previewMint(shares));
        asset.approve(address(vault), vault.previewMint(shares));

        // Consider the first expression of `mint`:
        // function mint(uint256 shares, address receiver) public returns (uint256 assets) {
        //     assets = _divup(shares * drip(), RAY);
        // shares * drip() <= type(uint256).max, hence
        // shares <= type(uint256).max / drip()

        // drip() potentially increases the denominator, so just because we succeeded before doesn't
        // mean we will succeed now. This will occur when
        // type(uint256).max / vault.drip() < shares <= type(uint256).max / vault.nowChi()
        fail = shares > type(uint256).max / vault.drip();

        if (fail) {
            vm.expectRevert(stdError.arithmeticError);
        }
        vault.mint(shares, address(this));
    }

    function withdraw(uint256 assets) external {
        numCalls["withdraw"]++;
        assets = _bound(assets, 0, vault.previewWithdraw(vault.balanceOf(address(this))));
        vault.withdraw(assets, address(this), address(this));
    }

    function withdrawAll() external {
        numCalls["withdrawAll"]++;
        vault.withdraw(vault.previewWithdraw(vault.balanceOf(address(this))), address(this), address(this));
    }

    function redeem(uint256 shares) external {
        numCalls["redeem"]++;
        shares = _bound(shares, 0, vault.balanceOf(address(this)));
        vault.redeem(shares, address(this), address(this));
    }

    function redeemAll() external {
        numCalls["redeemAll"]++;
        vault.redeem(vault.balanceOf(address(this)), address(this), address(this));
    }
}
