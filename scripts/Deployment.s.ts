import "@nomiclabs/hardhat-ethers";

import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deployer: ${deployer.address} (${ethers.utils.formatEther(await deployer.getBalance())} CHZ)`);

  // Deploy LENXFactory with the address of the LENX token
  const lenxFactoryFactory = await ethers.getContractFactory("LENXFactory");
  const lenxFactory = await lenxFactoryFactory.deploy(deployer.address, "0x0000000000000000000000000000000000000000");
  await lenxFactory.deployed();
  console.log(`LENX Factory deployed to: ${lenxFactory.address}`);

  // Deploy LENXRouter02 with the address of the LENX factory and WCHZ token
  const LENXRouter02 = await ethers.getContractFactory("LENXRouter02");
  const lenxRouter = await LENXRouter02.deploy(lenxFactory.address, "0x678c34581db0a7808d0aC669d7025f1408C9a3C6");
  await lenxRouter.deployed();
  console.log(`LENX Router deployed to: ${lenxRouter.address}`);
}

main()
  .then(() => {
    console.log("Deployment completed successfully!");
  })
  .catch((error) => {
    console.error(error);
    throw new Error(error);
  });
