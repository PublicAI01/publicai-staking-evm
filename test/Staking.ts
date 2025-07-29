import { ethers } from "hardhat";
import { expect } from "chai";
import {bigint} from "hardhat/internal/core/params/argumentTypes";

describe("StakingContract", function () {
  let owner: any, user: any;
  let staking: any, token: any, stakingAddress: any, tokenAddress: any;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();
    // Deploy ERC20Token
    const ERC20 = await ethers.getContractFactory("MyERC20");
    token = await ERC20.deploy("StakeToken", "STK");
    await token.mint(user.address, ethers.parseEther("1000"));
    tokenAddress = await token.getAddress();
    // Deploy StakingContract
    const Staking = await ethers.getContractFactory("StakingContract");
    staking = await Staking.deploy(tokenAddress);

    stakingAddress = await staking.getAddress();
    // Fund contract with enough reward token
    await token.mint(stakingAddress, ethers.parseEther("1000"));
  });

  it("User can stake and earn", async function () {
    let userAddress = await user.getAddress();
    await token.connect(user).approve(stakingAddress, ethers.parseEther("100"));
    await staking.connect(user).stake(ethers.parseEther("100"));
    await ethers.provider.send("evm_increaseTime", [60 * 60 * 24 * 10]); // 10 days
    await ethers.provider.send("evm_mine", []);
    const reward = await staking.earned(userAddress);
    expect(reward).to.be.gt(0);
    await staking.connect(user).unstake();
    expect(await token.balanceOf(userAddress)).to.be.gt(ethers.parseEther("900"));
  });

  it("Owner can withdraw custom amount", async function () {
    const contractBalance = await token.balanceOf(stakingAddress);
    const withdrawAmount = contractBalance/2n;

    const before = await token.balanceOf(owner.address);
    await staking.ownerWithdraw(withdrawAmount);
    const after = await token.balanceOf(owner.address);

    expect(after - before).to.equal(withdrawAmount);
  });

  it("Owner can transfer ownership", async function () {
    await staking.transferOwnership(user.address);
    expect(await staking.owner()).to.equal(user.address);
  });

});
