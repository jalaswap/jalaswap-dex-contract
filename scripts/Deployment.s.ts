import "@nomiclabs/hardhat-ethers";

import { ethers } from "hardhat";
import { wethAddresses } from "./constants";

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();
  const chainId = network.chainId;
  console.log(`Deployer: ${deployer.address} (${ethers.utils.formatEther(await deployer.getBalance())} ETH)`);

  // Deploy JALAFactory with the address of the JALA token
  const feeSetter = deployer.address;
  const jalaFactoryFactory = await ethers.getContractFactory("JALAFactory");
  const jalaFactory = await jalaFactoryFactory.deploy(feeSetter);
  await jalaFactory.deployed();
  console.log(`JALA Factory deployed to: ${jalaFactory.address}`);

  // Deploy JALARouter02 with the address of the JALA factory and WETH token
  const WETH = wethAddresses[chainId];
  const JALARouter02 = await ethers.getContractFactory("JALARouter02");
  const jalaRouter = await JALARouter02.deploy(jalaFactory.address, WETH);
  await jalaRouter.deployed();
  console.log(`JALA Router deployed to: ${jalaRouter.address}`);
}

main()
  .then(() => {
    console.log("Deployment completed successfully!");
  })
  .catch((error) => {
    console.error(error);
    throw new Error(error);
  });
