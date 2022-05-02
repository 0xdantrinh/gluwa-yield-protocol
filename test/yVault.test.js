const { expect } = require("chai");
const { ethers } = require("hardhat");
const ERC20ABI = require('./ERC20.json');

describe('yDaiVault', function () {
  before(async function () {
    [owner,user,user2] = await ethers.getSigners();
    userAddress = user.address;
    user2Address = user2.address;

    const DAI_ADDRESS = "0x6b175474e89094c44da98b954eedeac495271d0f";
    const yVault = await ethers.getContractFactory("yVault");
    this.yDaiVault = await yVault.deploy("0x6B175474E89094C44Da98b954EedeAC495271d0F");
    
    this.DAI = new ethers.Contract(DAI_ADDRESS, ERC20ABI, ethers.getDefaultProvider());    

    console.log(`Total Dai: ${await this.DAI.balanceOf(owner.address)}`)

    ownerAddress = this.yDaiVault.account;

    await this.yDaiVault.deployed();

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: ["0x6B175474E89094C44Da98b954EedeAC495271d0F"],
    });    
    daiSigner = await ethers.getSigner("0x6B175474E89094C44Da98b954EedeAC495271d0F");

    await user.sendTransaction({
      to: daiSigner.address,
      value: ethers.utils.parseEther("1.0")
    });

    console.log(`Total Dai: ${await this.DAI.balanceOf(daiSigner.address)}`)

    await this.DAI.connect(daiSigner).approve(this.yDaiVault.address, "100000");
    
    // await DAI.approve(this.dai.address, "10000")
    const success = await this.DAI.connect(daiSigner).transfer(this.yDaiVault.address, "10000");
    console.log(success)
    console.log(`Total Dai: ${await this.DAI.balanceOf(this.yDaiVault.address)}`)
    
    // await this.bean.mint(userAddress, '1000000000')
    // await this.bean.mint(user2Address, '1000000000')
    // await this.bean.mint(this.pair.address, '100000')
    // await this.weth.mint(this.pair.address, '100')
    // await this.pair.connect(user).approve(this.silo.address, '100000000000')
    // await this.pair.connect(user2).approve(this.silo.address, '100000000000')
    // await this.bean.connect(user).approve(this.silo.address, '100000000000')
    // await this.bean.connect(user2).approve(this.silo.address, '100000000000')
    // await this.pair.faucet(userAddress, '100');
    // await this.pair.set('100000', '100','1');

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
        const initialDai = await this.DAI.balanceOf(this.yDaiVault.address)
        expect(initialDai).to.be.equal('100000');
      });
    });

    // describe('harvest beans', async function () {
    //   it('reverts when plot is not harvestable', async function () {
    //     await expect(this.claim.connect(user).harvest(['1'], false)).to.be.revertedWith('Claim: Plot not harvestable.')
    //     await expect(this.claim.connect(user).harvest(['1000000'], false)).to.be.revertedWith('Claim: Plot not harvestable.')
    //   });

    //   it('successfully harvests beans', async function () {
    //     const beans = await this.bean.balanceOf(userAddress)
    //     await this.claim.connect(user).harvest(['0'], false)
    //     const newBeans = await this.bean.balanceOf(userAddress)
    //     expect(await this.field.plot(userAddress, '27')).to.be.equal('0');
    //     expect(newBeans.sub(beans)).to.be.equal('1000');
    //   })
    // });

    
  });
});
