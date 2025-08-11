import "./a_init.sol";

contract FlowsErc4626 is Init {

    function deposit(uint256 assets) external {
        numCalls["deposit"]++;
        deal(address(asset), address(this), assets);
        asset.approve(address(proxy), assets);

        // Consider the first expression of `deposit`:
        // function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        //     shares = assets * RAY / drip();
        // assets * RAY <= type(uint256).max, hence
        // assets <= type(uint256).max / RAY

        bool fail = assets > type(uint256).max / RAY;
        if (fail) {
            vm.expectRevert(stdError.arithmeticError);
        }
        proxy.deposit(assets, address(this));
    }

    function mint(uint256 shares) external {
        numCalls["mint"]++;

        // Consider the first expression of `previewMint`:
        // function previewMint(uint256 shares) external view returns (uint256) {
        //     return _divup(shares * nowChi(), RAY);
        // shares * nowChi() <= type(uint256).max, hence
        // shares <= type(uint256).max / nowChi()
        bool fail = shares > type(uint256).max / proxy.nowChi();
        if (fail) {
            console.log("shares:", shares);
            vm.expectRevert(stdError.arithmeticError); proxy.previewMint(shares);
            return;
        }
        deal(address(asset), address(this), proxy.previewMint(shares));
        asset.approve(address(proxy), proxy.previewMint(shares));

        // Consider the first expression of `mint`:
        // function mint(uint256 shares, address receiver) public returns (uint256 assets) {
        //     assets = _divup(shares * drip(), RAY);
        // shares * drip() <= type(uint256).max, hence
        // shares <= type(uint256).max / drip()

        // drip() potentially increases the denominator, so just because we succeeded before doesn't
        // mean we will succeed now. This will occur when
        // type(uint256).max / proxy.drip() < shares <= type(uint256).max / proxy.nowChi()
        fail = shares > type(uint256).max / proxy.drip();

        if (fail) {
            vm.expectRevert(stdError.arithmeticError);
        }
        proxy.mint(shares, address(this));
    }

    function withdraw(uint256 assets) external {
        numCalls["withdraw"]++;
        assets = bound(assets, 0, proxy.previewWithdraw(proxy.balanceOf(address(this))));
        proxy.withdraw(assets, address(this), address(this));
    }

    function withdrawAll() external {
        numCalls["withdrawAll"]++;
        proxy.withdraw(proxy.previewWithdraw(proxy.balanceOf(address(this))), address(this), address(this));
    }

    function redeem(uint256 shares) external {
        numCalls["redeem"]++;
        shares = bound(shares, 0, proxy.balanceOf(address(this)));
        proxy.redeem(shares, address(this), address(this));
    }

    function redeemAll() external {
        numCalls["redeemAll"]++;
        proxy.redeem(proxy.balanceOf(address(this)), address(this), address(this));
    }
}
