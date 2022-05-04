const { expect } = require("chai");
const { ethers } = require("hardhat");
const { impersonateDai } = require('./../scripts/impersonate.js')

const LockupKind = {
  NO_LOCKUP: 0,
  EIGHT_WEEK_LOCKUP: 1,
  ONE_YEAR_LOCKUP: 2,
}

describe('yDaiVault', function () {
  before(async function () {
    [owner,user,user2] = await ethers.getSigners();
    userAddress = user.address;
    user2Address = user2.address;

    const DAI_ADDRESS = "0x6b175474e89094c44da98b954eedeac495271d0f";
    const yVault = await ethers.getContractFactory("yVault");
    this.yDaiVault = await yVault.deploy("0x6B175474E89094C44Da98b954EedeAC495271d0F");
    const dai = await impersonateDai();
    console.log("dai address", dai)

    this.dai = await ethers.getContractAt('MockToken', DAI_ADDRESS);
    console.log("mocked dai", this.dai)

    vaultOwnerAddress = this.yDaiVault.account;

    await this.yDaiVault.deployed();

    // await user.sendTransaction({
    //   to: daiSigner.address,
    //   value: ethers.utils.parseEther("1.0")
    // });
    
    await this.dai.mint(userAddress, '100000')
    await this.dai.mint(user2Address, '100000')
    await this.dai.mint(this.yDaiVault.address, '1000000000')
    await this.dai.connect(user).approve(this.yDaiVault.address, '100000000000');
    await this.dai.connect(user2).approve(this.yDaiVault.address, '100000000000');
    console.log(`Total Dai: ${await this.dai.balanceOf(user.address)}`)

  });

  // beforeEach (async function () {
  //   await this.season.resetAccount(userAddress)
  //   await this.season.resetAccount(user2Address)
  //   await this.season.resetAccount(ownerAddress)
  //   await this.season.resetState()
  //   await this.season.siloSunrise(0)
  // });

  describe('Vault', function () {
    // beforeEach(async function () {
    //   await this.silo.connect(user).depositBeans('1000', this.updateSettings)
    //   await this.silo.connect(user).depositLP('1', this.partialSiloUpdate)
    //   await this.season.setSoilE('5000')
    //   await this.field.connect(user).sowBeans('1000', false)
    //   await this.field.incrementTotalHarvestableE('1000')
    //   await this.silo.connect(user).withdrawBeans([2],['1000'], this.partialSiloUpdate)
    //   await this.silo.connect(user).withdrawLP([2],['1'], this.partialSiloUpdate)
    //   await this.season.farmSunrises('25')
    // });

    describe('dai initialization', async function () {
      it('Dai Mints Correctly', async function () {
        const initialDai = await this.dai.balanceOf(this.yDaiVault.address)
        expect(initialDai).to.be.equal('1000000000');
      });
    });

    describe('user dai deposits', async function () {
      // it('reverts when plot is not harvestable', async function () {
      //   await expect(this.claim.connect(user).harvest(['1'], false)).to.be.revertedWith('Claim: Plot not harvestable.')
      //   await expect(this.claim.connect(user).harvest(['1000000'], false)).to.be.revertedWith('Claim: Plot not harvestable.')
      // });

      it('successfully deposits dai into no lockup', async function () {
        const dai = await this.dai.balanceOf(userAddress)
        await this.yDaiVault.connect(user).addTokenDeposit('1000', LockupKind.NO_LOCKUP);
        const newdai = await this.dai.balanceOf(userAddress)
        expect(newdai.sub(dai)).to.be.equal('-1000');
      })

      it('successfully deposits dai into 8 week lockup', async function () {
        const dai = await this.dai.balanceOf(userAddress)
        await this.yDaiVault.connect(user).addTokenDeposit('2000', LockupKind.EIGHT_WEEK_LOCKUP);
        const newdai = await this.dai.balanceOf(userAddress)
        expect(newdai.sub(dai)).to.be.equal('-2000');
      })

      it('successfully deposits dai into one year lockup', async function () {
        const dai = await this.dai.balanceOf(userAddress)
        await this.yDaiVault.connect(user).addTokenDeposit('3000', LockupKind.ONE_YEAR_LOCKUP);
        const newdai = await this.dai.balanceOf(userAddress)
        expect(newdai.sub(dai)).to.be.equal('-3000');
      })
    });

    describe('user dai withdrawal', async function () {

      it('successfully partially withdraws dai from no lockup', async function () {
        const dai = await this.dai.balanceOf(userAddress)
        await this.yDaiVault.connect(user).withdrawAmount('100', LockupKind.NO_LOCKUP);
        const newdai = await this.dai.balanceOf(userAddress)
        expect(newdai.sub(dai)).to.be.equal('100');
      });

      it('successfully partially withdraws dai from 8 week lockup', async function () {
        const dai = await this.dai.balanceOf(userAddress)
        await this.yDaiVault.connect(user).withdrawAmount('0', LockupKind.EIGHT_WEEK_LOCKUP);
        const newdai = await this.dai.balanceOf(userAddress)
        expect(newdai.sub(dai)).to.be.equal('2000');
      });

      it('successfully partially withdraws dai from no lockup', async function () {
        const dai = await this.dai.balanceOf(userAddress)
        await this.yDaiVault.connect(user).withdrawAmount('100', LockupKind.ONE_YEAR_LOCKUP);
        const newdai = await this.dai.balanceOf(userAddress)
        expect(newdai.sub(dai)).to.be.equal('3000');
      })
    });

    
  });
});
