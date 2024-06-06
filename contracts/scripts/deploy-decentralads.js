const hre = require("hardhat");
const { networks } = require("../hardhat.config");

async function main() {

  const signers = await ethers.getSigners();
  var signer = signers[0];
  var Factory;
  var Contract;

  console.log("=== START ===");

  Factory = await hre.ethers.getContractFactory("IPFSManager");
  Contract = await Factory.connect(signer).deploy();
  var adsIPFSManagerAddress = (await Contract.deployed()).address;
  console.log("IPFSManager deployed to: ", adsIPFSManagerAddress);

  Factory = await hre.ethers.getContractFactory("LotteryManager");
  Contract = await Factory.connect(signer).deploy();
  var adsLotteryManagerAddress = (await Contract.deployed()).address;
  console.log("LotteryManager deployed to: ", adsLotteryManagerAddress);

  Factory = await hre.ethers.getContractFactory("PriceFeedManager");
  Contract = await Factory.connect(signer).deploy();
  var adsPriceFeedManagerAddress = (await Contract.deployed()).address;
  console.log("PriceFeedManager deployed to: ", adsPriceFeedManagerAddress);

  Factory = await hre.ethers.getContractFactory("AdsManager");
  Contract = await Factory.connect(signer).deploy(adsIPFSManagerAddress, adsLotteryManagerAddress, adsPriceFeedManagerAddress);
  var adsManagerAddress = (await Contract.deployed()).address;
  console.log("AdsManager deployed to: ", adsManagerAddress);

  console.log("=== END ===");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });