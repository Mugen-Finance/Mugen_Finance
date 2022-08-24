const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("OFT: ", function () {
  const chainIdSrc = 1;
  const chainIdDst = 2;
  const name = "OmnichainFungibleToken";
  const symbol = "OFT";
  const globalSupply = ethers.utils.parseUnits("1000000", 18);

  let owner,
    lzEndpointSrcMock,
    lzEndpointDstMock,
    OFTSrc,
    OFTDst,
    LZEndpointMock,
    BasedOFT,
    OFT,
    Treasury;

  before(async function () {
    owner = (await ethers.getSigners())[0];

    LZEndpointMock = await ethers.getContractFactory("LZEndpointMock");
    BasedOFT = await ethers.getContractFactory("Mugen");
    OFT = await ethers.getContractFactory("Mugen");
    Treasury = await ethers.getContractFactory("Treasury");
  });

  beforeEach(async function () {
    lzEndpointSrcMock = await LZEndpointMock.deploy(chainIdSrc);
    lzEndpointDstMock = await LZEndpointMock.deploy(chainIdDst);

    // create two OmnichainFungibleToken instances
    OFTSrc = await BasedOFT.deploy(lzEndpointSrcMock.address);
    OFTDst = await OFT.deploy(lzEndpointDstMock.address);
    TreasuryDst = await Treasury.deploy(
      OFTDst.address,
      owner.address,
      owner.address
    );

    // internal bookkeeping for endpoints (not part of a real deploy, just for this test)
    lzEndpointSrcMock.setDestLzEndpoint(
      OFTDst.address,
      lzEndpointDstMock.address
    );
    lzEndpointDstMock.setDestLzEndpoint(
      OFTSrc.address,
      lzEndpointSrcMock.address
    );

    // set each contracts source address so it can send to each other
    await OFTSrc.setTrustedRemote(chainIdDst, OFTDst.address); // for A, set B
    await OFTDst.setTrustedRemote(chainIdSrc, OFTSrc.address); // for B, set A
  });
  describe("setting up stored payload", async function () {
    // v1 adapterParams, encoded for version 1 style, and 200k gas quote
    const adapterParam = ethers.utils.solidityPack(
      ["uint16", "uint256"],
      [1, 225000]
    );
    const sendQty = ethers.utils.parseUnits("10", 18); // amount to be sent across

    beforeEach(async function () {
      await OFTSrc.mint(owner.address, globalSupply);
      // ensure they're both starting with correct amounts
      await OFTDst.transferOwnership(TreasuryDst.address);
      expect(await OFTSrc.balanceOf(owner.address)).to.be.equal(globalSupply);
      expect(await OFTDst.balanceOf(owner.address)).to.be.equal("0");

      // block receiving msgs on the dst lzEndpoint to simulate ua reverts which stores a payload
      await lzEndpointDstMock.blockNextMsg();

      // stores a payload
      await OFTSrc.sendFrom(
        owner.address,
        chainIdDst,
        ethers.utils.solidityPack(["address"], [owner.address]),
        sendQty,
        owner.address,
        ethers.constants.AddressZero,
        adapterParam
      );
    });
    it("it transfer and mints properly", async function () {
      assert(OFTDst.balanceOf(owner.address), sendQty);
    });
  });
});
