
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract StakingContract is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public stakingToken;
    IERC20 public rewardToken;

    // Staking token decimals
    uint8 public constant STAKING_TOKEN_DECIMALS = 18;

    // Reward rate (tokens per second)
    uint256 public rewardRate = 1e15; // 0.001 tokens per second

    // Mapping of user address to staked amount
    mapping(address => uint256) public stakedBalance;

    // Mapping of user address to last stake or claim timestamp
    mapping(address => uint256) public lastStakeOrClaimTime;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);

    constructor() Ownable() {
        // Initialize with placeholder addresses. These should be changed after deployment.
        stakingToken = IERC20(address(0x1234567890123456789012345678901234567890));
        rewardToken = IERC20(address(0x0987654321098765432109876543210987654321));
    }

    function setStakingToken(address _stakingToken) external onlyOwner {
        stakingToken = IERC20(_stakingToken);
    }

    function setRewardToken(address _rewardToken) external onlyOwner {
        rewardToken = IERC20(_rewardToken);
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        rewardRate = _rewardRate;
    }

    function stake(uint256 _amount) external {
        require(_amount > 0, "Cannot stake 0 tokens");
        
        // Claim any outstanding rewards before updating stake
        _claimReward(msg.sender);

        stakedBalance[msg.sender] += _amount;
        lastStakeOrClaimTime[msg.sender] = block.timestamp;

        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external {
        require(_amount > 0, "Cannot withdraw 0 tokens");
        require(stakedBalance[msg.sender] >= _amount, "Insufficient staked balance");

        // Claim any outstanding rewards before withdrawing
        _claimReward(msg.sender);

        stakedBalance[msg.sender] -= _amount;
        lastStakeOrClaimTime[msg.sender] = block.timestamp;

        stakingToken.safeTransfer(msg.sender, _amount);

        emit Withdrawn(msg.sender, _amount);
    }

    function claimReward() external {
        _claimReward(msg.sender);
    }

    function _claimReward(address _user) internal {
        uint256 reward = calculateReward(_user);
        if (reward > 0) {
            lastStakeOrClaimTime[_user] = block.timestamp;
            rewardToken.safeTransfer(_user, reward);
            emit RewardClaimed(_user, reward);
        }
    }

    function calculateReward(address _user) public view returns (uint256) {
        uint256 stakedAmount = stakedBalance[_user];
        if (stakedAmount == 0) {
            return 0;
        }

        uint256 duration = block.timestamp - lastStakeOrClaimTime[_user];
        return (stakedAmount * duration * rewardRate) / (10**STAKING_TOKEN_DECIMALS);
    }

    function getStakedBalance(address _user) external view returns (uint256) {
        return stakedBalance[_user];
    }
}
