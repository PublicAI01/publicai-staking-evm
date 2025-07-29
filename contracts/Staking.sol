// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StakingContract
 * @dev Users stake a token and earn reward in the same token. Owner can withdraw any amount of token and change ownership.
 */
contract StakingContract is Ownable {
    IERC20 public immutable token;

    struct StakeInfo {
        uint256 amount;         // User's staked amount
        uint256 rewardDebt;     // Accumulated reward
        uint256 lastStakedTime; // Last update time
    }

    mapping(address => StakeInfo) public stakes;

    uint256 public totalStaked;
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    uint256 public constant AAR = 8e16; // 8% annual rate, scaled by 1e18

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event OwnerWithdraw(address indexed owner, uint256 amount);

    constructor(address _token) {
        require(_token != address(0), "Zero address");
        token = IERC20(_token);
    }

    modifier updateReward(address account) {
        if (account != address(0)) {
            stakes[account].rewardDebt = earned(account);
            stakes[account].lastStakedTime = block.timestamp;
        }
        _;
    }

    /// @notice Stake tokens to earn rewards. Multiple stakes are allowed.
    function stake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        token.transferFrom(msg.sender, address(this), amount);
        stakes[msg.sender].amount += amount;
        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    /// @notice View function to get the user's current earned (pending) reward.
    function earned(address account) public view returns (uint256) {
        StakeInfo memory info = stakes[account];
        uint256 userReward = info.rewardDebt;
        if (info.amount > 0) {
            uint256 delta = block.timestamp - info.lastStakedTime;
            // reward = amount * AAR * delta / SECONDS_PER_YEAR / 1e18
            userReward += (info.amount * AAR * delta) / (SECONDS_PER_YEAR * 1e18);
        }
        return userReward;
    }

    /// @notice Unstake all and claim all rewards.
    function unstake() external updateReward(msg.sender) {
        StakeInfo storage info = stakes[msg.sender];
        uint256 amount = info.amount;
        uint256 reward = info.rewardDebt;
        require(amount > 0, "Nothing to unstake");

        info.amount = 0;
        info.rewardDebt = 0;
        totalStaked -= amount;

        token.transfer(msg.sender, amount + reward);

        emit Unstaked(msg.sender, amount, reward);
    }

    /// @notice Owner can withdraw a custom amount of tokens from the contract.
    function ownerWithdraw(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        require(token.balanceOf(address(this)) >= amount, "Insufficient contract balance");
        token.transfer(owner(), amount);
        emit OwnerWithdraw(owner(), amount);
    }
}
