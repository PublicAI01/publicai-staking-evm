// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title StakingContract
 * @dev Users stake a token and earn reward in the same token. Owner can withdraw any amount of token and change ownership.
 */
contract StakingContract is Ownable {
    using SafeERC20 for IERC20;
    IERC20 public immutable token;

    struct StakeInfo {
        uint256 amount;         // User's staked amount
        uint256 rewardDebt;     // Accumulated reward
        uint256 lastStakedTime; // Last update time
    }

    mapping(address => StakeInfo) public stakes;

    uint256 public totalStaked;                                 // Total amount staked
    uint256 public totalClaimedReward;                          // Total amount of claimed reward
    bool    public stakePaused;                                // Pause stake
    uint256 public stakeEndTime; // Stake end time,after this time, there will be no rewards for stake,0 means no end time.
    uint256 public totalReward;                          // Total amount of reward
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    uint256 public constant AAR = 8e16; // 8% annual rate, scaled by 1e18

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event OwnerWithdraw(address indexed owner, uint256 amount);
    event PauseStake(address indexed owner, bool pause);
    event SetNewEndTime(address indexed owner, uint256 endTime);
    event SetTotalReward(address indexed owner, uint256 totalReward);

    constructor(address _token, uint256 _totalReward) {
        require(_token != address(0), "Zero address");
        require(_totalReward > 0, "Total reward should gt 0");
        token = IERC20(_token);
        stakePaused = false;
        stakeEndTime = 0;
        totalReward = _totalReward;
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
        require(stakePaused == false, "Stake paused");
        token.safeTransferFrom(msg.sender, address(this), amount);
        stakes[msg.sender].amount += amount;
        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    /// @notice View function to get the user's current earned (pending) reward.
    function earned(address account) public view returns (uint256) {
        StakeInfo memory info = stakes[account];
        uint256 userReward = info.rewardDebt;
        if (info.amount > 0) {
            uint256 currentTime = block.timestamp;
            uint256 rewardEndTime = 0;
            if(stakeEndTime == 0) {
                rewardEndTime = currentTime;
            } else {
                rewardEndTime = Math.min(currentTime, stakeEndTime);
            }
            uint256 delta = 0;
            if(rewardEndTime >= info.lastStakedTime) {
                delta =  rewardEndTime - info.lastStakedTime;
            }
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
        uint256 afterTotalClaimedReward = totalClaimedReward + reward;
        uint256 claimReward = 0;
        // The user can only claim the portion that does not exceed the total reward.
        if(afterTotalClaimedReward >= totalReward) {
            if(totalReward >= totalClaimedReward) {
                claimReward = totalReward - totalClaimedReward;
            }
        } else {
            claimReward = reward;
        }
        totalClaimedReward += claimReward;

        token.safeTransfer(msg.sender, amount + claimReward);

        emit Unstaked(msg.sender, amount, claimReward);
    }

    /// @notice Owner can withdraw a custom amount of tokens from the contract.
    function ownerWithdraw(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        require( stakePaused == true, "Stake should paused");
        uint256 balance = token.balanceOf(address(this));
        require( balance >= amount, "Insufficient contract balance");
        uint256 available = 0;
        uint256 frozen = totalStaked;
        if(totalReward >= totalClaimedReward) {
            frozen += totalReward - totalClaimedReward;
        }
        if(balance > frozen) {
            available = balance - frozen;
        }
        require( amount <= available, "Only part of the balance can be withdrawn");
        token.safeTransfer(owner(), amount);
        emit OwnerWithdraw(owner(), amount);
    }

    /// @notice Owner can pause stake.
    function pauseStake(bool pause) external onlyOwner {
        stakePaused = pause;
        emit PauseStake(owner(), pause);
    }

    /// @notice Owner can set stake end time.
    function setStakeEndTime(uint256 endTime) external onlyOwner {
        if(endTime == 0){
            require(stakePaused == false, "Need to start stake first.");
        } else {
            require(stakePaused == true, "Need to pause stake first.");
        }
        stakeEndTime = endTime;
        emit SetNewEndTime(owner(), endTime);
    }

    /// @notice Owner can set total reward.
    function setTotalReward(uint256 _totalReward) external onlyOwner {
        require(_totalReward > 0, "Total reward should gt 0");
        totalReward = _totalReward;
        emit SetTotalReward(owner(), _totalReward);
    }
}
