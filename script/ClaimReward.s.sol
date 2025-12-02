// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/RewardToken.sol";
import "../src/TaskRewardPlatform.sol";


contract ClaimRewardScript is Script {
    function run() external {
        uint256 userPrivateKey = vm.envUint("PRIVATE_KEY");
        address platformAddress = vm.envAddress("PLATFORM_ADDRESS");
        uint256 taskId = vm.envUint("TASK_ID");
        bytes32[] memory proof = vm.envBytes32("MERKLE_PROOF", ",");
        
        TaskRewardPlatform platform = TaskRewardPlatform(platformAddress);
        
        vm.startBroadcast(userPrivateKey);
        
        platform.claimReward(taskId, proof);
        
        vm.stopBroadcast();
        
        console.log("\n=== Reward Claimed ===");
        console.log("Task ID:", taskId);
        console.log("User:", vm.addr(userPrivateKey));
    }
}