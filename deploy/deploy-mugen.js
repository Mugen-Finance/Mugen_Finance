const { getNamedAccounts, deployments } = require("hardhat")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const dai = await deploy("MockDAI", {
        from: deployer,
        args: [100],
        log: true,
    })
    const mugen = await deploy("Mugen", { from: deployer, args: [], log: true })
    const treasury = await deploy("Treasury", {
        from: deployer,
        args: [mugen.address],
        log: true,
    })
    const xMugen = await deploy("xMugen", {
        from: deployer,
        args: [
            "xMugen",
            "xMGN",
            deployer,
            mugen.address,
            dai.address,
            1000000000000000000,
        ],
        log: true,
    })
}

module.exports.tags = ["all", "mugen"]
