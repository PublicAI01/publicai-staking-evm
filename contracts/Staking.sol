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
        uint256 firstStakeTime;    // Time of first stake
    }

    mapping(address => StakeInfo) public stakes;

    uint256 public totalStaked;                                 // Total amount staked
    uint256 public totalClaimedReward;                          // Total amount of claimed reward
    bool    public stakePaused;                                // Pause stake
    uint256 public stakeEndTime; // Stake end time,after this time, there will be no rewards for stake,0 means no end time.
    uint256 public totalReward;                          // Total amount of reward
    uint256 public immutable stakeStartTime;                                    // Start time of stake
    uint256 public lockDuration;                                       // Lock duration
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    uint256 public constant WEEK = 7 * 24 * 60 * 60;
    uint256 public constant AAR = 8e16; // 8% annual rate, scaled by 1e18
    uint256[5] public AAR_EARLY = [500e16, 400e16, 300e16, 200e16, 100e16];
    uint256 public constant MAX_TOTAL_REWARD = 100000000e18;
    uint256 public constant MAX_LOCK_DURATION = 4*WEEK;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event OwnerWithdraw(address indexed owner, uint256 amount);
    event PauseStake(address indexed owner, bool pause);
    event SetNewEndTime(address indexed owner, uint256 endTime);
    event SetTotalReward(address indexed owner, uint256 totalReward);
    event SetLockDuration(address indexed owner, uint256 lockDuration);

    constructor(address _token, uint256 _totalReward) {
        require(_token != address(0), "Zero address");
        require(_totalReward > 0, "Total reward should gt 0");
        token = IERC20(_token);
        stakePaused = false;
        stakeEndTime = 0;
        totalReward = _totalReward;
        stakeStartTime = block.timestamp;
        lockDuration = 2 * WEEK;
    }

    modifier updateReward(address account) {
        if (account != address(0)) {
            stakes[account].rewardDebt = earned(account);
            stakes[account].lastStakedTime = block.timestamp;
            if(stakes[account].firstStakeTime == 0) {
                stakes[account].firstStakeTime = block.timestamp;
            }
        }
        _;
    }

    /// @notice Stake tokens to earn rewards. Multiple stakes are allowed.
    function stake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        require(!stakePaused, "Stake paused");
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
            uint256 start_time = 0;
            if(rewardEndTime >= info.lastStakedTime) {
                start_time =  info.lastStakedTime;
            } else {
                start_time = rewardEndTime;
            }
            // reward = amount * AAR * delta / SECONDS_PER_YEAR / 1e18
            uint256 reward = 0;
            uint256 reward_duration = 0;
            for (uint i = 0; i < AAR_EARLY.length; i++) {
                uint256 aar_start_at = stakeStartTime + i * WEEK;
                uint256 aar_end_at = stakeStartTime + (i + 1) * WEEK;
                if(rewardEndTime < aar_start_at || start_time >= aar_end_at) {
                    continue;
                }
                if(start_time >= aar_start_at) {
                    if(rewardEndTime <= aar_end_at) {
                        reward_duration = rewardEndTime - start_time;
                    } else {
                        reward_duration = aar_end_at - start_time;
                    }
                } else {
                    if(rewardEndTime <= aar_end_at) {
                        reward_duration = rewardEndTime - aar_start_at;
                    } else {
                        reward_duration = aar_end_at - aar_start_at;
                    }
                }
                reward += info.amount * AAR_EARLY[i] * reward_duration;
            }
            uint256 last_interval_end = stakeStartTime + (AAR_EARLY.length * WEEK);
            if(rewardEndTime >= last_interval_end) {
                if(start_time >= last_interval_end) {
                    reward_duration = rewardEndTime - start_time;
                } else {
                    reward_duration = rewardEndTime - last_interval_end;
                }
                reward += info.amount * AAR * reward_duration;
            }
            userReward += reward / (SECONDS_PER_YEAR * 1e18);
        }
        return userReward;
    }

    /// @notice View function to get the user's current stake info.
    function getStakeInfo(address account) public view returns (StakeInfo memory) {
        StakeInfo memory info = stakes[account];
        uint256 userReward = earned(account);
        info.rewardDebt = userReward;
        return info;
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

        uint256 current_time = block.timestamp;
        if(current_time < info.firstStakeTime + lockDuration) {
            claimReward = 0;
        }
        info.firstStakeTime = 0;
        info.lastStakedTime = 0;
        token.safeTransfer(msg.sender, amount + claimReward);

        emit Unstaked(msg.sender, amount, claimReward);
    }

    /// @notice Owner can withdraw a custom amount of tokens from the contract.
    function ownerWithdraw(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        require( stakePaused, "Stake should paused");
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
            require(!stakePaused, "Need to start stake first.");
        } else {
            require(stakePaused, "Need to pause stake first.");
        }
        stakeEndTime = endTime;
        emit SetNewEndTime(owner(), endTime);
    }

    /// @notice Owner can set total reward.
    function setTotalReward(uint256 _totalReward) external onlyOwner {
        require(_totalReward > 0, "Total reward should gt 0");
        require(_totalReward <= MAX_TOTAL_REWARD, "Total reward should le MAX_TOTAL_REWARD");
        totalReward = _totalReward;
        emit SetTotalReward(owner(), _totalReward);
    }

    /// @notice Owner can set lock duration.
    function setLockDuration(uint256 _lockDuration) external onlyOwner {
        require(_lockDuration > 0, "Lock duration should gt 0");
        require(_lockDuration <= MAX_LOCK_DURATION, "Cannot exceed MAX_LOCK_DURATION");
        lockDuration = _lockDuration;
        emit SetLockDuration(owner(), _lockDuration);
    }
}
