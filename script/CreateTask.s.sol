// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/RewardToken.sol";
import "../src/TaskRewardPlatform.sol";


contract CreateTaskScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        address platformAddress = vm.envAddress("PLATFORM_ADDRESS");
        
        string memory taskName = vm.envString("TASK_NAME");
        bytes32 merkleRoot = vm.envBytes32("MERKLE_ROOT");
        uint256 rewardAmount = vm.envUint("REWARD_AMOUNT");
        uint256 totalPool = vm.envUint("TOTAL_POOL");
        uint256 maxClaims = vm.envUint("MAX_CLAIMS");
        uint256 duration = vm.envUint("DURATION_DAYS");
        
        RewardToken token = RewardToken(tokenAddress);
        TaskRewardPlatform platform = TaskRewardPlatform(platformAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Approve platform to spend tokens
        token.approve(platformAddress, totalPool);
        
        // Create task
        uint256 startTime = block.timestamp + 1 hours;
        uint256 endTime = block.timestamp + (duration * 1 days);
        
        uint256 taskId = platform.createTask(
            taskName,
            merkleRoot,
            rewardAmount,
            totalPool,
            maxClaims,
            startTime,
            endTime
        );
        
        vm.stopBroadcast();
        
        console.log("\n=== Task Created ===");
        console.log("Task ID:", taskId);
        console.log("Task Name:", taskName);
        console.log("Reward Amount:", rewardAmount / 10**18, "tokens");
        console.log("Total Pool:", totalPool / 10**18, "tokens");
        console.log("Max Claims:", maxClaims);
        console.log("Duration:", duration, "days");
    }
}
