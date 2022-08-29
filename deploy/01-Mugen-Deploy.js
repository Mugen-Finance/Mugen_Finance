const { getNamedAccounts, deployments, run, ethers } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = getNamedAccounts();

  log("------------------------");

  const arguements = [0x4d747149a57923beb89f22e6b7b97f7d8c087a00];
  const PRIVATE_KEY = process.env.PRIVATE_KEY;

  const mugen = await deploy("Mugen", {
    from: PRIVATE_KEY,
    args: arguements,
    log: true,
    waitConfirmations: 2,
  });
};
module.exports.tags = ["all", "Mugen"];
