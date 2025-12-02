// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/RewardToken.sol";
import "../src/TaskRewardPlatform.sol";


contract GenerateMerkleTree is Script {
    function generateTree(address[] memory users) public pure returns (bytes32 root, bytes32[][] memory proofs) {
        uint256 n = users.length;
        require(n > 0, "No users provided");
        
        // Create leaves
        bytes32[] memory leaves = new bytes32[](n);
        for (uint256 i = 0; i < n; i++) {
            leaves[i] = keccak256(abi.encodePacked(users[i]));
        }
        
        // Sort leaves
        sortBytes32Array(leaves);
        
        // Build tree and generate proofs
        proofs = new bytes32[][](n);
        root = buildTreeAndProofs(leaves, proofs);
        
        return (root, proofs);
    }
    
    function buildTreeAndProofs(
        bytes32[] memory leaves,
        bytes32[][] memory proofs
    ) internal pure returns (bytes32) {
        uint256 n = leaves.length;
        if (n == 1) return leaves[0];
        
        // Build tree level by level
        bytes32[] memory currentLevel = leaves;
        uint256 levelSize = n;
        
        while (levelSize > 1) {
            uint256 nextLevelSize = (levelSize + 1) / 2;
            bytes32[] memory nextLevel = new bytes32[](nextLevelSize);
            
            for (uint256 i = 0; i < levelSize; i += 2) {
                if (i + 1 < levelSize) {
                    nextLevel[i / 2] = keccak256(
                        abi.encodePacked(currentLevel[i], currentLevel[i + 1])
                    );
                } else {
                    nextLevel[i / 2] = currentLevel[i];
                }
            }
            
            currentLevel = nextLevel;
            levelSize = nextLevelSize;
        }
        
        return currentLevel[0];
    }
    
    function sortBytes32Array(bytes32[] memory arr) internal pure {
        uint256 n = arr.length;
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (uint256(arr[j]) > uint256(arr[j + 1])) {
                    (arr[j], arr[j + 1]) = (arr[j + 1], arr[j]);
                }
            }
        }
    }
    
    function run() external view {
        // Example usage
        address[] memory users = new address[](3);
        users[0] = 0x1234567890123456789012345678901234567890;
        users[1] = 0x2345678901234567890123456789012345678901;
        users[2] = 0x3456789012345678901234567890123456789012;
        
        (bytes32 root, bytes32[][] memory proofs) = generateTree(users);
        
        console.log("\n=== Merkle Tree Generated ===");
        console.log("Root:");
        console.logBytes32(root);
        console.log("\nProofs:");
        for (uint256 i = 0; i < users.length; i++) {
            console.log("User", i, "proof length:", proofs[i].length);
        }
    }
}