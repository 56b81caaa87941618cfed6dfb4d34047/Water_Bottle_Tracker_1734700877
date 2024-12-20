
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract StakingContract is Ownable2Step, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public stakingToken;
    IERC20 public rewardToken;

    // Staking token decimals
    uint256 public constant STAKING_TOKEN_DECIMALS = 18;

    // Reward rate (tokens per second)
    uint256 public rewardRate = 1e15; // 0.001 tokens per second

    // Timestamp for the last reward rate update
    uint256 public lastUpdateTime;

    // Accumulated rewards per token stored
    uint256 public rewardPerTokenStored;

    // Total staked tokens
    uint256 public totalSupply;

    // Mapping of user address to staked amount
    mapping(address => uint256) public stakedBalance;

    // Mapping of user address to rewards per token paid
    mapping(address => uint256) public userRewardPerTokenPaid;

    // Mapping of user address to rewards
    mapping(address => uint256) public rewards;

    // Time delay for parameter changes
    uint256 public constant PARAMETER_CHANGE_DELAY = 2 days;

    // Pending parameter changes
    uint256 public pendingRewardRate;
    uint256 public pendingRewardRateTimestamp;
    address public pendingStakingToken;
    uint256 public pendingStakingTokenTimestamp;
    address public pendingRewardToken;
    uint256 public pendingRewardTokenTimestamp;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);
    event StakingTokenUpdated(address newToken);
    event RewardTokenUpdated(address newToken);

    constructor() Ownable() {
        // Initialize with placeholder addresses. These should be changed after deployment.
        stakingToken = IERC20(address(0x1234567890123456789012345678901234567890));
        rewardToken = IERC20(address(0x0987654321098765432109876543210987654321));
        lastUpdateTime = block.timestamp;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function setStakingToken(address _stakingToken) external onlyOwner {
        require(_stakingToken != address(0), "Invalid staking token address");
        pendingStakingToken = _stakingToken;
        pendingStakingTokenTimestamp = block.timestamp + PARAMETER_CHANGE_DELAY;
    }

    function setRewardToken(address _rewardToken) external onlyOwner {
        require(_rewardToken != address(0), "Invalid reward token address");
        pendingRewardToken = _rewardToken;
        pendingRewardTokenTimestamp = block.timestamp + PARAMETER_CHANGE_DELAY;
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        require(_rewardRate > 0 && _rewardRate <= 1e18, "Invalid reward rate");
        pendingRewardRate = _rewardRate;
        pendingRewardRateTimestamp = block.timestamp + PARAMETER_CHANGE_DELAY;
    }

    function applyPendingChanges() external onlyOwner {
        if (pendingRewardRateTimestamp != 0 && block.timestamp >= pendingRewardRateTimestamp) {
            rewardRate = pendingRewardRate;
            pendingRewardRate = 0;
            pendingRewardRateTimestamp = 0;
            emit RewardRateUpdated(rewardRate);
        }
        if (pendingStakingTokenTimestamp != 0 && block.timestamp >= pendingStakingTokenTimestamp) {
            stakingToken = IERC20(pendingStakingToken);
            pendingStakingToken = address(0);
            pendingStakingTokenTimestamp = 0;
            emit StakingTokenUpdated(address(stakingToken));
        }
        if (pendingRewardTokenTimestamp != 0 && block.timestamp >= pendingRewardTokenTimestamp) {
            rewardToken = IERC20(pendingRewardToken);
            pendingRewardToken = address(0);
            pendingRewardTokenTimestamp = 0;
            emit RewardTokenUpdated(address(rewardToken));
        }
    }

    function stake(uint256 _amount) external updateReward(msg.sender) whenNotPaused {
        require(_amount > 0, "Cannot stake 0 tokens");
        totalSupply += _amount;
        stakedBalance[msg.sender] += _amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external updateReward(msg.sender) whenNotPaused {
        require(_amount > 0, "Cannot withdraw 0 tokens");
        require(stakedBalance[msg.sender] >= _amount, "Insufficient staked balance");
        totalSupply -= _amount;
        stakedBalance[msg.sender] -= _amount;
        stakingToken.safeTransfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    function claimReward() external updateReward(msg.sender) whenNotPaused {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.safeTransfer(msg.sender, reward);
            emit RewardClaimed(msg.sender, reward);
        }
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalSupply);
    }

    function earned(address account) public view returns (uint256) {
        return ((stakedBalance[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) + rewards[account];
    }

    function getStakedBalance(address _user) external view returns (uint256) {
        return stakedBalance[_user];
    }

    function getTotalSupply() external view returns (uint256) {
        return totalSupply;
    }

    function pauseContract() external onlyOwner {
        _pause();
    }

    function unpauseContract() external onlyOwner {
        _unpause();
    }
}
