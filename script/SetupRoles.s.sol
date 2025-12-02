// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/RewardToken.sol";
import "../src/TaskRewardPlatform.sol";


contract SetupRolesScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address platformAddress = vm.envAddress("PLATFORM_ADDRESS");
        address[] memory validators = vm.envAddress("VALIDATORS", ",");
        address[] memory admins = vm.envAddress("ADMINS", ",");
        
        TaskRewardPlatform platform = TaskRewardPlatform(platformAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Grant validator roles
        for (uint256 i = 0; i < validators.length; i++) {
            platform.grantRole(platform.VALIDATOR_ROLE(), validators[i]);
            console.log("Granted VALIDATOR_ROLE to:", validators[i]);
        }
        
        // Grant admin roles
        for (uint256 i = 0; i < admins.length; i++) {
            platform.grantRole(platform.ADMIN_ROLE(), admins[i]);
            console.log("Granted ADMIN_ROLE to:", admins[i]);
        }
        
        vm.stopBroadcast();
        
        console.log("\n=== Roles Setup Complete ===");
    }
}