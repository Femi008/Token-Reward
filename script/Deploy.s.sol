// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/RewardToken.sol";
import "../src/TaskRewardPlatform.sol";

// ============================================================================
// FILE: script/Deploy.s.sol
// ============================================================================

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy RewardToken
        uint256 tokenCap = 10_000_000 * 10**18; // 10 million tokens
        RewardToken token = new RewardToken(
            "Reward Token",
            "RWD",
            tokenCap,
            deployer
        );
        
        console.log("RewardToken deployed at:", address(token));
        
        // Deploy TaskRewardPlatform
        TaskRewardPlatform platform = new TaskRewardPlatform(
            address(token),
            deployer
        );
        
        console.log("TaskRewardPlatform deployed at:", address(platform));
        
        // Mint initial supply
        token.mint(deployer, tokenCap);
        console.log("Minted", tokenCap / 10**18, "tokens to deployer");
        
        vm.stopBroadcast();
        
        // Log deployment info
        console.log("\n=== Deployment Summary ===");
        console.log("RewardToken:", address(token));
        console.log("TaskRewardPlatform:", address(platform));
        console.log("Token Cap:", tokenCap / 10**18);
        console.log("Admin:", deployer);
    }
}
