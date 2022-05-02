async function bean() {
  let tokenJson = fs.readFileSync(`./artifacts/contracts/mocks/MockToken.sol/MockToken.json`);

  await network.provider.send("hardhat_setCode", [
    BEAN,
    JSON.parse(tokenJson).deployedBytecode,
  ]);

  const bean = await ethers.getContractAt("MockToken", BEAN);
  await bean.setDecimals(6);
  return BEAN;
}