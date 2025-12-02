// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/RewardToken.sol";
import "../src/TaskRewardPlatform.sol";

contract GenerateMerkleTree is Script {
    struct TreeNode {
        bytes32 hash;
        uint256 index;
    }
    
    /**
     * @notice Generate Merkle tree and proofs for a list of users
     * @param users Array of user addresses
     * @return root The Merkle root
     * @return proofs Array of proofs for each user
     */
    function generateTree(address[] memory users) public pure returns (bytes32 root, bytes32[][] memory proofs) {
        uint256 n = users.length;
        require(n > 0, "No users provided");
        
        // Create and sort leaves
        bytes32[] memory leaves = new bytes32[](n);
        uint256[] memory originalIndices = new uint256[](n);
        
        for (uint256 i = 0; i < n; i++) {
            leaves[i] = keccak256(abi.encodePacked(users[i]));
            originalIndices[i] = i;
        }
        
        // Sort leaves (bubble sort for simplicity)
        sortLeavesWithIndices(leaves, originalIndices);
        
        // Build complete tree structure
        bytes32[][] memory tree = buildCompleteTree(leaves);
        root = tree[tree.length - 1][0];
        
        // Generate proofs for each user
        proofs = new bytes32[][](n);
        for (uint256 i = 0; i < n; i++) {
            // Find sorted position of this user's leaf
            bytes32 userLeaf = keccak256(abi.encodePacked(users[i]));
            uint256 sortedIndex = findLeafIndex(leaves, userLeaf);
            proofs[i] = generateProof(tree, sortedIndex);
        }
        
        return (root, proofs);
    }
    
    /**
     * @notice Build complete Merkle tree level by level
     */
    function buildCompleteTree(bytes32[] memory leaves) internal pure returns (bytes32[][] memory) {
        uint256 n = leaves.length;
        uint256 height = 0;
        uint256 temp = n;
        
        // Calculate tree height
        while (temp > 1) {
            temp = (temp + 1) / 2;
            height++;
        }
        
        // Create tree structure
        bytes32[][] memory tree = new bytes32[][](height + 1);
        tree[0] = leaves;
        
        // Build tree bottom-up
        for (uint256 level = 0; level < height; level++) {
            uint256 currentLevelSize = tree[level].length;
            uint256 nextLevelSize = (currentLevelSize + 1) / 2;
            tree[level + 1] = new bytes32[](nextLevelSize);
            
            for (uint256 i = 0; i < currentLevelSize; i += 2) {
                if (i + 1 < currentLevelSize) {
                    // Combine two nodes
                    tree[level + 1][i / 2] = hashPair(tree[level][i], tree[level][i + 1]);
                } else {
                    // Odd node, promote to next level
                    tree[level + 1][i / 2] = tree[level][i];
                }
            }
        }
        
        return tree;
    }
    
    /**
     * @notice Generate proof for a specific leaf
     */
    function generateProof(bytes32[][] memory tree, uint256 leafIndex) internal pure returns (bytes32[] memory) {
        uint256 proofLength = 0;
        uint256 tempIndex = leafIndex;
        
        // Calculate proof length
        for (uint256 level = 0; level < tree.length - 1; level++) {
            uint256 siblingIndex = tempIndex % 2 == 0 ? tempIndex + 1 : tempIndex - 1;
            if (siblingIndex < tree[level].length) {
                proofLength++;
            }
            tempIndex = tempIndex / 2;
        }
        
        // Build proof
        bytes32[] memory proof = new bytes32[](proofLength);
        uint256 proofIndex = 0;
        uint256 currentIndex = leafIndex;
        
        for (uint256 level = 0; level < tree.length - 1; level++) {
            uint256 siblingIndex = currentIndex % 2 == 0 ? currentIndex + 1 : currentIndex - 1;
            
            if (siblingIndex < tree[level].length) {
                proof[proofIndex] = tree[level][siblingIndex];
                proofIndex++;
            }
            
            currentIndex = currentIndex / 2;
        }
        
        return proof;
    }
    
    /**
     * @notice Hash two nodes in correct order
     */
    function hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }
    
    /**
     * @notice Find index of a leaf in sorted array
     */
    function findLeafIndex(bytes32[] memory leaves, bytes32 leaf) internal pure returns (uint256) {
        for (uint256 i = 0; i < leaves.length; i++) {
            if (leaves[i] == leaf) {
                return i;
            }
        }
        revert("Leaf not found");
    }
    
    /**
     * @notice Sort leaves with their original indices
     */
    function sortLeavesWithIndices(bytes32[] memory leaves, uint256[] memory indices) internal pure {
        uint256 n = leaves.length;
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (uint256(leaves[j]) > uint256(leaves[j + 1])) {
                    // Swap leaves
                    (leaves[j], leaves[j + 1]) = (leaves[j + 1], leaves[j]);
                    // Swap indices
                    (indices[j], indices[j + 1]) = (indices[j + 1], indices[j]);
                }
            }
        }
    }
    
    /**
     * @notice Verify a proof (for testing)
     */
    function verifyProof(
        bytes32 root,
        bytes32 leaf,
        bytes32[] memory proof
    ) public pure returns (bool) {
        bytes32 computedHash = leaf;
        
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = hashPair(computedHash, proof[i]);
        }
        
        return computedHash == root;
    }
    
    /**
     * @notice Example usage script
     */
    function run() external view {
        console.log("\n=== Merkle Tree Generator ===\n");
        
        // Example with 5 users
        address[] memory users = new address[](5);
        users[0] = 0x1111111111111111111111111111111111111111;
        users[1] = 0x2222222222222222222222222222222222222222;
        users[2] = 0x3333333333333333333333333333333333333333;
        users[3] = 0x4444444444444444444444444444444444444444;
        users[4] = 0x5555555555555555555555555555555555555555;
        
        (bytes32 root, bytes32[][] memory proofs) = generateTree(users);
        
        console.log("Merkle Root:");
        console.logBytes32(root);
        console.log("");
        
        // Display proofs for each user
        for (uint256 i = 0; i < users.length; i++) {
            console.log("User", i, ":", users[i]);
            console.log("  Proof length:", proofs[i].length);
            console.log("  Proof:");
            for (uint256 j = 0; j < proofs[i].length; j++) {
                console.log("    [", j, "]:");
                console.logBytes32(proofs[i][j]);
            }
            
            // Verify proof
            bytes32 leaf = keccak256(abi.encodePacked(users[i]));
            bool valid = verifyProof(root, leaf, proofs[i]);
            console.log("  Verification:", valid ? "VALID" : "INVALID");
            console.log("");
        }
    }
    
    /**
     * @notice Generate tree from file (to be called by other scripts)
     */
    function generateFromAddresses(address[] memory users) external pure returns (bytes32 root) {
        (root, ) = generateTree(users);
        return root;
    }
    
    /**
     * @notice Get proof for specific user
     */
    function getProofForUser(address[] memory users, address user) external pure returns (bytes32[] memory) {
        (, bytes32[][] memory proofs) = generateTree(users);
        
        // Find user index
        for (uint256 i = 0; i < users.length; i++) {
            if (users[i] == user) {
                return proofs[i];
            }
        }
        
        revert("User not found in list");
    }
}