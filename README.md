
---

# StakingContract

A simple and secure ERC20 staking contract written in Solidity, designed for use with [Hardhat](https://hardhat.org/).  
Users can stake an ERC20 token and earn rewards in the same token at a fixed annual average return rate (AAR, set to 8%).  
The contract supports multiple stakes, single unstake with all rewards, owner withdrawal, and ownership transfer.

---

## Features

- **Stake & Unstake**: Users can stake tokens multiple times and unstake once to withdraw principal plus all earned rewards.
- **Reward Calculation**: Rewards are calculated at 8% annualized (AAR), precise to the second.
- **Owner Functions**: The owner can withdraw any custom amount of tokens and transfer ownership.
- **Reward Query**: Anyone can check a user’s current earned (pending) rewards at any time.
- **Uses a single ERC20 token** for both staking and rewards.

---

## Contract Methods

### Constructor

```solidity
constructor(address _token)
```
- `_token`: The ERC20 token address to be used for both staking and rewards.

### Staking

```solidity
function stake(uint256 amount) external
```
- Stake any positive amount of tokens. Multiple stakes are allowed.

### Query Rewards

```solidity
function earned(address account) public view returns (uint256)
```
- Return the total earned rewards for a given account, including any pending rewards since last stake/unstake.

### Unstake

```solidity
function unstake() external
```
- Withdraw all staked tokens plus accrued rewards for the caller.
- After unstake, that account’s stake is reset to zero.

### Owner Withdraw

```solidity
function ownerWithdraw(uint256 amount) external onlyOwner
```
- Owner can withdraw any specified amount of tokens from the contract (including both staked and reward tokens).

### Ownership Transfer

Supported via OpenZeppelin Ownable’s `transferOwnership(address newOwner)`.

---

## Reward Calculation

- **Annual Average Return (AAR):** 8%
- **Reward formula:**  
  `reward = staked_amount * 8% * (time_elapsed_in_seconds / seconds_per_year)`
- **All math uses 18 decimals for precision.**

---

## Usage Example

1. **Deploy an ERC20 token** (can use OpenZeppelin’s ERC20PresetMinterPauser for testing).
2. **Deploy StakingContract** with the token address.
3. **Fund StakingContract** with enough tokens for rewards.
4. **User approves StakingContract** to spend their tokens, then calls `stake(amount)`.
5. **User can check rewards** with `earned(address)`.
6. **User calls `unstake()`** to withdraw staked tokens and rewards.
7. **Owner can withdraw tokens** at any time with `ownerWithdraw(amount)`.

---

## Example Test (Hardhat + ethers.js)

```typescript
it("User can stake, earn rewards, and unstake", async function () {
  await token.connect(user).approve(staking.address, ethers.utils.parseEther("100"));
  await staking.connect(user).stake(ethers.utils.parseEther("100"));
  await ethers.provider.send("evm_increaseTime", [60 * 60 * 24 * 10]); // 10 days
  await ethers.provider.send("evm_mine", []);
  const reward = await staking.earned(user.address);
  expect(reward).to.be.gt(0);
  await staking.connect(user).unstake();
});
```

---

## Security Notes

- Make sure the contract holds enough tokens to pay rewards.
- Owner can withdraw all tokens at any time; only trust contracts where the owner is trustworthy or is a DAO/multisig.
- The contract does not have slashing, lockups, or minimum staking periods.

---

## License

MIT

---

**Enjoy staking!**