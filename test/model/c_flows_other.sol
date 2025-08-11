import "./b_flows_erc4626.sol";

contract FlowsOther is FlowsErc4626 {
    function setSsr(bool authFail, uint256 failCallerSeed, uint256 ssr) external {
        numCalls["setSsr"]++;
        ssr = bound(ssr, RAY, 1000000021979553151239153027); // between 0% and 100% apy
        if (authFail) {
            uint256 mod = 3 + users.length;
            failCallerSeed = bound(failCallerSeed, 0, mod - 1);
            address caller;
            if (failCallerSeed == 0) {
                caller = address(this); // this contract
            } else if (failCallerSeed == 1) {
                caller = admin; // admin
            } else if (failCallerSeed == 2) {
                caller = taker; // taker
            } else {
                caller = users[failCallerSeed - 3]; // user
            }
            vm.expectRevert(abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, caller, SETTER_ROLE
            ));
            vm.prank(caller); proxy.setSsr(ssr);
            return;
        }
        vm.prank(setter); proxy.setSsr(ssr);
    }
}
