const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("Treasury: ", function () {
  const chainIdSrc = 1;
  const chainIdDst = 2;
  const supply = ethers.utils.parseUnits("1000000", 18);

  let owner,
    lzEndpointSrcMock,
    lzEndpointDstMock,
    wethMock,
    daiMock,
    OFTSrc,
    OFTDst,
    LZEndpointMock,
    MugenETH,
    MugenARB,
    TreasuryETH,
    TreasuryARB,
    TreasurySrc,
    TreasuryDst,
    Communicator,
    Comms,
    Dai,
    WETH,
    wethFeed,
    daiFeed;

  before(async function () {
    owner = (await ethers.getSigners())[0];
    wethMock = await ethers.getContractFactory("NotMockAggregator");
    daiMock = await ethers.getContractFactory("NotMockAggregator");
    LZEndpointMock = await ethers.getContractFactory("LZEndpointMock");
    MugenETH = await ethers.getContractFactory("Mugen");
    MugenARB = await ethers.getContractFactory("Mugen");
    TreasuryETH = await ethers.getContractFactory("Treasury");
    TreasuryARB = await ethers.getContractFactory("NonNativeTreasury");
    Dai = await ethers.getContractFactory("MockERC20");
    WETH = await ethers.getContractFactory("MockUSDC");
    Communicator = await ethers.getContractFactory("Communicator");
  });

  beforeEach(async function () {
    wethPrice = await wethMock.deploy(8, 200000000000);
    daiPrice = await daiMock.deploy(8, 100000000);
    lzEndpointSrcMock = await LZEndpointMock.deploy(chainIdSrc);
    lzEndpointDstMock = await LZEndpointMock.deploy(chainIdDst);

    dai = await Dai.deploy("USDC", "USDC", 6, supply);
    weth = await WETH.deploy(supply);
    wethFeed = "0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419";
    daiFeed = "0xaed0c38402a5d19df6e4c03f4e2dced6e29c1ee9";

    OFTDst = await MugenARB.deploy(lzEndpointDstMock.address);
    OFTSrc = await MugenETH.deploy(lzEndpointSrcMock.address);

    TreasurySrc = await TreasuryETH.deploy(OFTSrc.address, owner.address);
    TreasuryDst = await TreasuryARB.deploy(
      OFTDst.address,
      owner.address,
      lzEndpointDstMock.address,
      chainIdSrc
    );
    Comms = await Communicator.deploy(lzEndpointSrcMock.address);

    lzEndpointSrcMock.setDestLzEndpoint(
      TreasuryDst.address,
      lzEndpointDstMock.address
    );
    lzEndpointDstMock.setDestLzEndpoint(
      Comms.address,
      lzEndpointSrcMock.address
    );

    await Comms.setTrustedRemote(chainIdDst, TreasuryDst.address);
    await TreasuryDst.setTrustedRemote(chainIdSrc, Comms.address);
    await Comms.setTreasury(TreasurySrc.address);
    await Comms.addLayerZeroMapping(TreasuryDst.address, chainIdDst);
    await TreasurySrc.setCommunicator(Comms.address);
    await weth.approve(TreasuryDst.address, supply);
    await dai.approve(TreasuryDst.address, supply);
  });
  describe("calculates new prices properly", async function () {
    it("calculates new prices properly", async function () {
      const amount = await ethers.utils.parseUnits("10000", 18);
      await OFTDst.transferOwnership(TreasuryDst.address);
      await TreasuryDst.addTokenInfo(dai.address, daiFeed);
      await TreasuryDst.addTokenInfo(weth.address, wethFeed);
      await TreasuryDst.deposit(dai.address, amount);
      console.log(await OFTDst.totalSupply());
      await TreasuryDst.deposit(weth.address, amount);
      console.log(await OFTDst.totalSupply());
      assert(await TreasurySrc.readSupply(), await OFTDst.totalSupply());
      assert(await OFTDst.totalSupply(), await OFTDst.balanceOf(owner.address));
      assert(await weth.balanceOf(TreasuryDst.address), amount);
    });
  });
});
