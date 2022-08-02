const { expect, assert, Assertion } = require("chai")
const { ethers } = require("hardhat")

describe("Treasury: ", function () {
    const chainIdSrc = 1

    const supply = ethers.utils.parseUnits("1000000", 18)

    let owner, lzEndpointSrcMock, OFTSrc, LZEndpointMock, MugenETH, Dai, xMugen

    before(async function () {
        owner = (await ethers.getSigners())[0]

        LZEndpointMock = await ethers.getContractFactory("LZEndpointMock")
        MugenETH = await ethers.getContractFactory("Mugen")
        xMugen = await ethers.getContractFactory("xMugen")
        Dai = await ethers.getContractFactory("MockDAI")
    })

    beforeEach(async function () {
        lzEndpointSrcMock = await LZEndpointMock.deploy(chainIdSrc)
        OFTSrc = await MugenETH.deploy(lzEndpointSrcMock.address)
        dai = await Dai.deploy(supply)
        xmugen = await xMugen.deploy(OFTSrc.address, dai.address, owner.address)
        dai.approve(xmugen.address, supply)
        OFTSrc.mint(owner.address, supply)
        OFTSrc.approve(xmugen.address, supply)
    })
    describe("xMugen tests", async function () {
        it("mints 1:1 ratio", async function () {
            await xmugen.deposit(supply, owner.address)
            expect(OFTSrc.balanceOf(xmugen.address) == supply)
            expect(OFTSrc.balanceOf(xmugen.address) > 0)
            assert(OFTSrc.balanceOf(xmugen.address), xmugen.totalSupply())
        })
        it("uses mint function similar to deposits", async function () {
            await xmugen.mint(supply, owner.address)
            expect(OFTSrc.balanceOf(xmugen.address) == supply)
            expect(OFTSrc.balanceOf(xmugen.address) > 0)
            assert(OFTSrc.balanceOf(xmugen.address), xmugen.totalSupply())
        })
        it("sets up the issuance rate properly", async function () {
            await xmugen.deposit(supply, owner.address)
            await xmugen.issuanceRate(supply, 200000)
            const rate = supply / 200000
            assert(dai.balanceOf(xmugen.address), supply)
            expect(dai.balanceOf(xmugen.address) > 0)
            assert(xmugen.checkRR(), rate)
        })
        it("lets you withdraw and burns the tokens", async function () {
            await xmugen.deposit(supply, owner.address)
            assert(xmugen.totalSupply(), supply)
            await xmugen.withdraw(supply, owner.address, owner.address)
            assert(xmugen.totalSupply(), 0)
        })
        it("lets you redeem and burns the tokens", async function () {
            await xmugen.deposit(supply, owner.address)
            assert(xmugen.totalSupply(), supply)
            await xmugen.redeem(supply, owner.address, owner.address)
            assert(xmugen.totalSupply(), 0)
        })
    })
    describe("Calculates rewards properly", async function () {
        it("calculates reward per token", async function () {
            await xmugen.deposit(supply, owner.address)
            const tx = await xmugen.issuanceRate(supply, 2)
            await tx.wait(1)
            const expect = await xmugen.earned(owner.address)
            assert(expect, supply / 2)
            await tx.wait(1)
            assert(expect, supply)
            xmugen.withdraw(supply, owner.address, owner.address)
            assert(xmugen.totalSupply(), 0)
            assert(dai.balanceOf(owner.address), supply)
        })
    })
})
