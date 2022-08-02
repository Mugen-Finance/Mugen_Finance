const { expect, assert } = require("chai")
const { ethers } = require("hardhat")
const {
    isCallTrace,
} = require("hardhat/internal/hardhat-network/stack-traces/message-trace")

describe("Treasury: ", function () {
    const chainIdSrc = 1
    const chainIdDst = 2
    const supply = ethers.utils.parseUnits("1000000", 18)

    let owner,
        lzEndpointSrcMock,
        lzEndpointDstMock,
        OFTSrc,
        OFTDst,
        LZEndpointMock,
        MugenETH,
        MugenARB,
        TreasuryETH,
        TreasuryARB,
        TreasurySrc,
        TreasuryDst,
        Dai,
        WETH

    before(async function () {
        owner = (await ethers.getSigners())[0]

        LZEndpointMock = await ethers.getContractFactory("LZEndpointMock")
        MugenETH = await ethers.getContractFactory("Mugen")
        MugenARB = await ethers.getContractFactory("Mugen")
        TreasuryETH = await ethers.getContractFactory("Treasury")
        TreasuryARB = await ethers.getContractFactory("NonNativeTreasury")
        Dai = await ethers.getContractFactory("MockDAI")
        WETH = await ethers.getContractFactory("MockUSDC")
    })

    beforeEach(async function () {
        const wethPrice = "0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419"
        const daiPrice = "0xaed0c38402a5d19df6e4c03f4e2dced6e29c1ee9"
        lzEndpointSrcMock = await LZEndpointMock.deploy(chainIdSrc)
        lzEndpointDstMock = await LZEndpointMock.deploy(chainIdDst)

        dai = await Dai.deploy(supply)
        weth = await WETH.deploy(supply)

        OFTDst = await MugenARB.deploy(lzEndpointDstMock.address)
        OFTSrc = await MugenETH.deploy(lzEndpointSrcMock.address)

        TreasurySrc = await TreasuryETH.deploy(
            OFTSrc.address,

            owner.address,
            lzEndpointSrcMock.address
        )
        TreasuryDst = await TreasuryARB.deploy(
            OFTDst.address,
            owner.address,
            lzEndpointDstMock.address
        )

        lzEndpointSrcMock.setDestLzEndpoint(
            TreasuryDst.address,
            lzEndpointDstMock.address
        )
        lzEndpointDstMock.setDestLzEndpoint(
            TreasurySrc.address,
            lzEndpointSrcMock.address
        )

        await TreasurySrc.setTrustedRemote(chainIdDst, TreasuryDst.address)
        await TreasuryDst.setTrustedRemote(chainIdSrc, TreasurySrc.address)
        await TreasurySrc.addTokenInfo(weth.address, wethPrice)
        await TreasuryDst.addTokenInfo(weth.address, wethPrice)
        await TreasurySrc.addTokenInfo(dai.address, daiPrice)
        await TreasuryDst.addTokenInfo(dai.address, daiPrice)
    })
    //TreasuryDst is NonNativeTreasury contract
    describe("setting up the treasury", async function () {
        beforeEach(async function () {
            await weth.approve(TreasurySrc.address, supply)
            await weth.approve(TreasuryDst.address, supply)
        })

        it("lets the owner add the token", async function () {
            expect(await TreasurySrc.checkDepositable(dai.address)).to.equal(
                true
            )
        })
        it("takes native treasury deposits", async function () {
            const deposit = await ethers.utils.parseUnits("234232", 18)
            await OFTSrc.transferOwnership(TreasurySrc.address)
            assert(OFTSrc.owner(), TreasurySrc.address)
            await weth.approve(TreasurySrc.address, supply)
            await TreasurySrc.deposit(weth.address, deposit)
        })
        it("takes non native treasury deposits", async function () {
            const deposit = await ethers.utils.parseUnits("100", 18)
            await OFTDst.transferOwnership(TreasuryDst.address)
            await await OFTSrc.transferOwnership(TreasurySrc.address)
            assert(OFTDst.owner(), TreasuryDst.address)
            await TreasurySrc.addLayerZeroMapping(
                TreasuryDst.address,
                chainIdDst
            )
            await dai.approve(TreasuryDst.address, supply)
            await weth.approve(TreasuryDst.address, supply)
            await dai.approve(TreasurySrc.address, supply)
            await weth.approve(TreasurySrc.address, supply)
            await TreasurySrc.deposit(weth.address, deposit)
            await TreasurySrc.updateCrossChainPrice(chainIdDst)
            await TreasuryDst.deposit(dai.address, deposit, chainIdSrc)
            await TreasuryDst.deposit(weth.address, deposit, chainIdSrc)
            console.log(await TreasuryDst.readPrice())
            await TreasuryDst.deposit(weth.address, deposit, chainIdSrc)
        })
        it("updates cross chain prices", async function () {
            const price = await ethers.utils.parseUnits("100", 18)
            const deposit = await ethers.utils.parseUnits("234232", 18)
            await OFTSrc.transferOwnership(TreasurySrc.address)
            assert(OFTSrc.owner(), TreasurySrc.address)
            const txResponse = await TreasurySrc.deposit(weth.address, deposit)
            await txResponse.wait(1)
            await TreasurySrc.deposit(weth.address, deposit)
            const newPrice = await TreasurySrc.readPrice()
            assert(OFTSrc.totalSupply(), OFTSrc.balanceOf(this.address))
            expect(OFTSrc.totalSupply > 0)
            expect(TreasurySrc.readPrice() > price)
            expect((await TreasuryDst.readPrice()) == 0)
            const updatedValue = TreasurySrc.readValue()
            await TreasurySrc.updateCrossChainPrice(chainIdDst)
            expect((await TreasuryDst.readValue()) == updatedValue)
            console.log(await TreasuryDst.readPrice())
            expect(TreasuryDst.readPrice() == TreasurySrc.readPrice())
            console.log(await OFTSrc.totalSupply())
            console.log(await TreasurySrc.readValue())
        })
    })
})
