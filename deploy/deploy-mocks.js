const { getNamedAccounts, deployments } = require("hardhat")
module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()

    const usdc = await deploy("MockUSDC", {
        from: deployer,
        args: [1000],
        log: true,
    })
    const dai = await deploy("MockDAI", {
        from: deployer,
        args: [1000],
        log: true,
    })
    const ust = await deploy("MockUST", {
        from: deployer,
        args: [1000],
        log: true,
    })
    const MockV3 = await deploy("NotMockV3Aggregator", {
        from: deployer,
        args: [8, 100],
        log: true,
    })
}

module.exports.tags = ["all", "mocks"]
