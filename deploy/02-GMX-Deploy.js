const { getNamedAccounts, deployments, network } = require("hardhat");

module.exports = async ({ deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  log("----------------------------------------------------");
  log("Deploying GMXStrategy and waiting for confirmations...");
  const gmsStrategy = await deploy("GMXStrategy", {
    from: deployer,
    args: [
      "0xa906f338cb21815cbc4bc87ace9e68c87ef8d8f1",
      "0x82af49447d8a07e3bd95bd0d56f35241523fbab1",
    ],
    log: true,
  });
  log(`FundMe deployed at ${gmsStrategy.address}`);
};

module.exports.tags = ["all", "strategy"];
