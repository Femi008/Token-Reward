// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/RewardToken.sol";
import "../src/TaskRewardPlatform.sol";

contract GasUsageTest is Test {
    RewardToken token;
    TaskRewardPlatform platform;

    address admin = address(0xA11CE);
    address user = address(0xB0B);

    // ---------------------------
    // Merkle tree helper functions
    // ---------------------------
    function _hashLeaf(address userAddr) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(userAddr));
    }

    function _buildMerkleTree(bytes32[] memory leaves)
        internal
        pure
        returns (bytes32 root, bytes32[][] memory layers)
    {
        uint256 n = leaves.length;
        layers = new bytes32[][](1);
        layers[0] = leaves;

        while (n > 1) {
            uint256 nextSize = (n + 1) / 2;
            bytes32[] memory nextLayer = new bytes32[](nextSize);

            for (uint256 i = 0; i < n; i += 2) {
                if (i + 1 < n) {
                    nextLayer[i / 2] = keccak256(
                        bytes.concat(layers[layers.length - 1][i], layers[layers.length - 1][i + 1])
                    );
                } else {
                    // Odd count -> hash last element with itself
                    nextLayer[i / 2] = keccak256(
                        bytes.concat(layers[layers.length - 1][i], layers[layers.length - 1][i])
                    );
                }
            }

            // append layer
            bytes32[][] memory newLayers = new bytes32[][](layers.length + 1);
            for (uint256 i = 0; i < layers.length; i++) newLayers[i] = layers[i];
            newLayers[layers.length] = nextLayer;
            layers = newLayers;

            n = nextSize;
        }

        root = layers[layers.length - 1][0];
    }

    function _generateProof(bytes32[][] memory layers, uint256 index)
        internal
        pure
        returns (bytes32[] memory proof)
    {
        proof = new bytes32[](layers.length - 1);
        for (uint256 i = 0; i < layers.length - 1; i++) {
            bytes32[] memory layer = layers[i];

            uint256 pairIndex = index % 2 == 0 ? index + 1 : index - 1;
            if (pairIndex < layer.length) proof[i] = layer[pairIndex];
            else proof[i] = layer[index]; // reflect leaf

            index /= 2;
        }
    }

    // ---------------------------
    // Setup
    // ---------------------------
    function setUp() public {
        vm.startPrank(admin);

        token = new RewardToken(
            "RewardToken",
            "RWT",
            1_000_000 ether,
            admin
        );
        token.mint(admin, 1_000_000 ether);

        platform = new TaskRewardPlatform(address(token), admin);

        token.approve(address(platform), type(uint256).max);

        vm.stopPrank();
    }

    // ---------------------------
    // GAS TEST: claimReward
    // ---------------------------
    function testGas_ClaimReward() public {
        // Build Merkle tree with 1 user (simple case)
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = _hashLeaf(user);

        (bytes32 root, bytes32[][] memory layers) = _buildMerkleTree(leaves);

        bytes32[] memory proof = _generateProof(layers, 0);

        vm.prank(admin);
        uint256 taskId = platform.createTask(
            "TestTask",
            root,
            50 ether,
            200 ether,
            10,
            block.timestamp + 1,
            block.timestamp + 1000
        );

        vm.warp(block.timestamp + 2);

        vm.prank(user);
        uint256 gasBefore = gasleft();
        platform.claimReward(taskId, proof);
        uint256 gasAfter = gasleft();

        console.log("Gas used for claimReward():", gasBefore - gasAfter);
    }

    // ---------------------------
    // GAS TEST: createTask
    // ---------------------------
    function testGas_CreateTask() public {
        bytes32 root = keccak256("root");

        vm.prank(admin);
        uint256 gasBefore = gasleft();
        platform.createTask(
            "GasTask",
            root,
            50 ether,
            200 ether,
            10,
            block.timestamp + 10,
            block.timestamp + 1000
        );
        uint256 gasAfter = gasleft();

        console.log("Gas used for createTask():", gasBefore - gasAfter);
    }
}
