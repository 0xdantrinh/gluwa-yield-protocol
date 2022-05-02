var fs = require('fs');

const DAI = '0x6B175474E89094C44Da98b954EedeAC495271d0F';

async function dai() {
  let tokenJson = fs.readFileSync(`./artifacts/contracts/mocks/MockToken.sol/MockToken.json`);
  await network.provider.send("hardhat_setCode", [
    DAI,
    JSON.parse(tokenJson).deployedBytecode,
  ]);
  const dai = await ethers.getContractAt("MockToken", DAI);
  await dai.setDecimals(18);
  return DAI;
}

exports.impersonateDai = dai
