// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {LowkickStarter} from "../src/LowkickStarter.sol";

contract DeployLowkickStarter is Script {
    LowkickStarter public lowkickStarter;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        lowkickStarter = new LowkickStarter();
        vm.stopBroadcast();
    }
}

contract DeployLowkickStarterSepolia is Script {
    function run() external {
        require(
            block.chainid == 11155111,
            "DeployGovernanceSepolia: wrong network (not Sepolia)"
        );

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);
        LowkickStarter lowkickStarter = new LowkickStarter();
        vm.stopBroadcast();

        console2.log("Sepolia LowkickStarter:  %s", address(lowkickStarter));
        console2.log("Deployer:                %s", vm.addr(deployerKey));
        console2.log("Chain ID:                %s", block.chainid);
    }
}
