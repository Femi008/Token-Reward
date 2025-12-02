// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/access/AccessControl.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/utils/Pausable.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";


/**
 * @title TaskRewardPlatform
 * @notice Merkle-proof based reward distribution system for task completion
 * @dev Uses Merkle trees for gas-efficient verification of millions of eligible users
 */
contract TaskRewardPlatform is AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    // ============ State Variables ============
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    
    IERC20 public immutable rewardToken;
    
    struct Task {
        bytes32 merkleRoot;
        uint256 rewardAmount;
        uint256 totalRewardPool;
        uint256 claimedAmount;
        uint256 maxClaims;
        uint256 claimCount;
        uint256 startTime;
        uint256 endTime;
        bool active;
        string taskName;
    }
    
    mapping(uint256 => Task) public tasks;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;
    
    uint256 public taskCounter;
    uint256 public totalRewardsDistributed;
    
    // ============ Events ============
    
    event TaskCreated(
        uint256 indexed taskId,
        string taskName,
        bytes32 merkleRoot,
        uint256 rewardAmount,
        uint256 totalRewardPool,
        uint256 maxClaims,
        uint256 startTime,
        uint256 endTime
    );
    
    event RewardClaimed(
        uint256 indexed taskId,
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );
    
    event TaskDeactivated(uint256 indexed taskId, uint256 timestamp);
    event TaskReactivated(uint256 indexed taskId, uint256 timestamp);
    event MerkleRootUpdated(uint256 indexed taskId, bytes32 newRoot);
    event RewardPoolIncreased(uint256 indexed taskId, uint256 additionalAmount);
    event UnclaimedRewardsWithdrawn(uint256 indexed taskId, uint256 amount);
    
    // ============ Errors ============
    
    error TaskNotActive();
    error TaskNotStarted();
    error TaskEnded();
    error AlreadyClaimed();
    error InvalidProof();
    error InsufficientRewardPool();
    error MaxClaimsReached();
    error InvalidTimeRange();
    error InvalidAmount();
    error TaskNotFound();
    
    // ============ Constructor ============
    
    constructor(address _rewardToken, address _admin) {
        require(_rewardToken != address(0), "Invalid token address");
        require(_admin != address(0), "Invalid admin address");
        
        rewardToken = IERC20(_rewardToken);
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(VALIDATOR_ROLE, _admin);
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice Create a new task with Merkle-based reward distribution
     * @param _taskName Name of the task
     * @param _merkleRoot Merkle root of eligible users
     * @param _rewardAmount Reward amount per user
     * @param _totalRewardPool Total rewards allocated for this task
     * @param _maxClaims Maximum number of claims allowed
     * @param _startTime Task start timestamp
     * @param _endTime Task end timestamp
     */
    function createTask(
        string calldata _taskName,
        bytes32 _merkleRoot,
        uint256 _rewardAmount,
        uint256 _totalRewardPool,
        uint256 _maxClaims,
        uint256 _startTime,
        uint256 _endTime
    ) external onlyRole(ADMIN_ROLE) returns (uint256) {
        if (_rewardAmount == 0 || _totalRewardPool == 0) revert InvalidAmount();
        if (_endTime <= _startTime) revert InvalidTimeRange();
        if (_startTime < block.timestamp) revert InvalidTimeRange();
        if (_maxClaims == 0) revert InvalidAmount();
        
        uint256 taskId = ++taskCounter;
        
        Task storage task = tasks[taskId];
        task.taskName = _taskName;
        task.merkleRoot = _merkleRoot;
        task.rewardAmount = _rewardAmount;
        task.totalRewardPool = _totalRewardPool;
        task.maxClaims = _maxClaims;
        task.startTime = _startTime;
        task.endTime = _endTime;
        task.active = true;
        
        rewardToken.safeTransferFrom(msg.sender, address(this), _totalRewardPool);
        
        emit TaskCreated(
            taskId,
            _taskName,
            _merkleRoot,
            _rewardAmount,
            _totalRewardPool,
            _maxClaims,
            _startTime,
            _endTime
        );
        
        return taskId;
    }
    
    /**
     * @notice Update Merkle root for a task (if users list changes)
     */
    function updateMerkleRoot(
        uint256 _taskId,
        bytes32 _newMerkleRoot
    ) external onlyRole(VALIDATOR_ROLE) {
        if (tasks[_taskId].totalRewardPool == 0) revert TaskNotFound();
        
        tasks[_taskId].merkleRoot = _newMerkleRoot;
        emit MerkleRootUpdated(_taskId, _newMerkleRoot);
    }
    
    /**
     * @notice Deactivate a task
     */
    function deactivateTask(uint256 _taskId) external onlyRole(ADMIN_ROLE) {
        if (tasks[_taskId].totalRewardPool == 0) revert TaskNotFound();
        
        tasks[_taskId].active = false;
        emit TaskDeactivated(_taskId, block.timestamp);
    }
    
    /**
     * @notice Reactivate a task
     */
    function reactivateTask(uint256 _taskId) external onlyRole(ADMIN_ROLE) {
        if (tasks[_taskId].totalRewardPool == 0) revert TaskNotFound();
        
        tasks[_taskId].active = true;
        emit TaskReactivated(_taskId, block.timestamp);
    }
    
    /**
     * @notice Increase reward pool for a task
     */
    function increaseRewardPool(
        uint256 _taskId,
        uint256 _additionalAmount
    ) external onlyRole(ADMIN_ROLE) {
        if (tasks[_taskId].totalRewardPool == 0) revert TaskNotFound();
        if (_additionalAmount == 0) revert InvalidAmount();
        
        tasks[_taskId].totalRewardPool += _additionalAmount;
        
        rewardToken.safeTransferFrom(msg.sender, address(this), _additionalAmount);
        
        emit RewardPoolIncreased(_taskId, _additionalAmount);
    }
    
    /**
     * @notice Withdraw unclaimed rewards after task ends
     */
    function withdrawUnclaimedRewards(
        uint256 _taskId
    ) external onlyRole(ADMIN_ROLE) {
        Task storage task = tasks[_taskId];
        
        if (task.totalRewardPool == 0) revert TaskNotFound();
        if (block.timestamp <= task.endTime) revert TaskNotEnded();
        
        uint256 unclaimedAmount = task.totalRewardPool - task.claimedAmount;
        
        if (unclaimedAmount > 0) {
            task.totalRewardPool = task.claimedAmount;
            rewardToken.safeTransfer(msg.sender, unclaimedAmount);
            
            emit UnclaimedRewardsWithdrawn(_taskId, unclaimedAmount);
        }
    }
    
    // ============ User Functions ============
    
    /**
     * @notice Claim reward for completed task using Merkle proof
     * @param _taskId Task ID
     * @param _merkleProof Merkle proof of eligibility
     */
    function claimReward(
        uint256 _taskId,
        bytes32[] calldata _merkleProof
    ) external nonReentrant whenNotPaused {
        Task storage task = tasks[_taskId];
        
        // Validation checks
        if (!task.active) revert TaskNotActive();
        if (block.timestamp < task.startTime) revert TaskNotStarted();
        if (block.timestamp > task.endTime) revert TaskEnded();
        if (hasClaimed[_taskId][msg.sender]) revert AlreadyClaimed();
        if (task.claimCount >= task.maxClaims) revert MaxClaimsReached();
        if (task.claimedAmount + task.rewardAmount > task.totalRewardPool) {
            revert InsufficientRewardPool();
        }
        
        // Verify Merkle proof
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (!MerkleProof.verify(_merkleProof, task.merkleRoot, leaf)) {
            revert InvalidProof();
        }
        
        // Update state
        hasClaimed[_taskId][msg.sender] = true;
        task.claimedAmount += task.rewardAmount;
        task.claimCount++;
        totalRewardsDistributed += task.rewardAmount;
        
        // Transfer reward
        rewardToken.safeTransfer(msg.sender, task.rewardAmount);
        
        emit RewardClaimed(_taskId, msg.sender, task.rewardAmount, block.timestamp);
    }
    
    // ============ View Functions ============
    
    function getTask(uint256 _taskId) external view returns (Task memory) {
        return tasks[_taskId];
    }
    
    function isEligible(
        uint256 _taskId,
        address _user,
        bytes32[] calldata _merkleProof
    ) external view returns (bool) {
        if (hasClaimed[_taskId][_user]) return false;
        
        bytes32 leaf = keccak256(abi.encodePacked(_user));
        return MerkleProof.verify(_merkleProof, tasks[_taskId].merkleRoot, leaf);
    }
    
    function getRemainingRewards(uint256 _taskId) external view returns (uint256) {
        Task storage task = tasks[_taskId];
        return task.totalRewardPool - task.claimedAmount;
    }
    
    function getRemainingClaims(uint256 _taskId) external view returns (uint256) {
        Task storage task = tasks[_taskId];
        return task.maxClaims - task.claimCount;
    }
    
    // ============ Emergency Functions ============
    
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    // ============ Custom Errors ============
    
    error TaskNotEnded();
}