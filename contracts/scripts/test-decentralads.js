const hre = require("hardhat");
const fs = require("fs");
const path = require("path");
const { networks } = require("../hardhat.config");

async function main() {
  
  const signers = await ethers.getSigners();
  var signer = signers[0]; 

  // ================================================ //

  const deployIPFSManagerContract = false;
  const deployLotteryManagerContract = false;
  const deployPriceFeedManagerContract = false;
  const deployAdsManagerContracts = false;

  const updateIPFSManager = false;
  const updatePriceFeedManager = false;

  const addAdsFactory = false;
  const getAdsFactories = false;

  const addAd = false;
  const buyAd = false;
  const getAd = false;

  const addLottery = false;
  const buyTicket = false;
  const claimAd = false;

  const updateAd = false;

  const updateIPFSSource = false;

  const testPriceFeed = false;

  // ================================================ //

  var adsIPFSManagerAddress = networks["snowtrace"]["adsIPFSManager"];
  var adsLotteryManagerAddress = networks["snowtrace"]["adsLotteryManager"];
  var adsPriceFeedManagerAddress = networks["snowtrace"]["adsPriceFeedManager"];
  var adsManagerAddress = networks["snowtrace"]["adsManager"];

  var adsFactoryAddress = networks["snowtrace"]["adsFactory"];
  
  // ================================================ //

  var Factory;
  var Contract;
  var Transaction;

  // ================================================ //

  console.log("=== START ===");

  if(deployIPFSManagerContract) {
    Factory = await hre.ethers.getContractFactory("IPFSManager");
    Contract = await Factory.connect(signer).deploy();
    adsIPFSManagerAddress = (await Contract.deployed()).address;
    console.log("IPFSManager deployed to:", adsIPFSManagerAddress);
  }

  if(deployLotteryManagerContract){
    Factory = await hre.ethers.getContractFactory("LotteryManager");
    Contract = await Factory.connect(signer).deploy();
    adsLotteryManagerAddress = (await Contract.deployed()).address;
    console.log("LotteryManager deployed to:", adsLotteryManagerAddress);
  }

  if(deployPriceFeedManagerContract){
    Factory = await hre.ethers.getContractFactory("PriceFeedManager");
    Contract = await Factory.connect(signer).deploy();
    adsPriceFeedManagerAddress = (await Contract.deployed()).address;
    console.log("PriceFeedManager deployed to:", adsPriceFeedManagerAddress);
  }

  if(deployAdsManagerContracts){
    Factory = await hre.ethers.getContractFactory("AdsManager");
    Contract = await Factory.connect(signer).deploy(adsIPFSManagerAddress, adsLotteryManagerAddress, adsPriceFeedManagerAddress);
    adsManagerAddress = (await Contract.deployed()).address;
    console.log("AdsManager deployed to:", adsManagerAddress);

    Factory = await hre.ethers.getContractFactory("IPFSManager");
    Contract = await Factory.attach(adsIPFSManagerAddress);
    Transaction = await Contract.updateAdsManager(adsManagerAddress);
    console.log("updateAdsManager to IPFSManager");

    Factory = await hre.ethers.getContractFactory("LotteryManager");
    Contract = await Factory.attach(adsLotteryManagerAddress);
    Transaction = await Contract.updateAdsManager(adsManagerAddress);
    console.log("updateAdsManager to LotteryManager");
  }

  if(updateIPFSManager){
    Factory = await hre.ethers.getContractFactory("AdsManager");
    Contract = await Factory.attach(adsManagerAddress);
    Transaction = await Contract.updateIPFSManager(adsIPFSManagerAddress);
    console.log("Update IPFSManager");
  }

  if(updatePriceFeedManager){
    Factory = await hre.ethers.getContractFactory("AdsManager");
    Contract = await Factory.attach(adsManagerAddress);
    Transaction = await Contract.updatePriceFeedManager(adsPriceFeedManagerAddress);
    console.log("Update PriceFeedManager");
  }

  if(addAdsFactory){
    if(deployAdsManagerContracts) wait(5000);

    Factory = await hre.ethers.getContractFactory("AdsManager");
    Contract = await Factory.attach(adsManagerAddress);

    var name = "Name";
    var symbol = "S";
    var description = "Description";
    var logo = "https://raw.githubusercontent.com/andreatedesco/DecentralAds/main/demo/assets/images/games/game-00.jpg";
    var banner = "https://raw.githubusercontent.com/andreatedesco/DecentralAds/main/demo/assets/images/games/game-00.jpg";
    var link = "https://www.linkedin.com/in/andrea-tedesco-041858199//";
    var royalty = 200;

    Transaction = await Contract.createFactory(name, symbol, description, logo, banner, link, royalty);
    console.log("Added Factory");
  }

  if(getAdsFactories){
    if(addAdsFactory) wait(5000);

    Factory = await hre.ethers.getContractFactory("AdsManager");
    Contract = await Factory.attach(adsManagerAddress);
    adsFactoryAddress = await Contract.getFactories(0, 1);
    console.log("Get Ads Factories: [ " + adsFactoryAddress + " ]");

    Factory = await hre.ethers.getContractFactory("AdsFactory");
    Contract = await Factory.attach(adsFactoryAddress[0]);
    Transaction = await Contract.contractURI();

    console.log("Get Ads Factories Uri: " + Transaction);
  }

  if(addAd){
    Factory = await hre.ethers.getContractFactory("AdsFactory");
    Contract = await Factory.attach(adsFactoryAddress);

    var price = 0;
    var width = 1000;
    var height = 2000;

    Transaction = await Contract.addAd(price, width, height, 0, "0x0000000000000000000000000000000000000000");
    console.log("Added Adv");
  }

  if(buyAd){
    if(addAd) wait(5000);

    var id = 0;
    var name =  "Name #" + id;
    var description = "Descrption #" + id;
    var image = "https://raw.githubusercontent.com/andreatedesco/DecentralAds/main/demo/assets/images/games/game-00.jpg";
    var url = "https://www.linkedin.com/in/andrea-tedesco-041858199/";

    Factory = await hre.ethers.getContractFactory("AdsFactory");
    Contract = await Factory.attach(adsFactoryAddress);
    Transaction = await Contract.mintAd(id, name, description, image, url);
    console.log("Minted Adv");
  }

  if(getAd){
    if(buyAd) wait(5000);

    var id = 0;
    Factory = await hre.ethers.getContractFactory("AdsFactory");
    Contract = await Factory.attach(adsFactoryAddress);
    Transaction = await Contract.tokenURI(id);
    console.log("Uri #"+ id + ": " + Transaction);
  }

  if(addLottery){
    Factory = await hre.ethers.getContractFactory("AdsFactory");
    Contract = await Factory.attach(adsFactoryAddress);

    var price = 0;
    var width = 200;
    var height = 300;
    var ticketAmount = 3;

    Transaction = await Contract.addAd(price, width, height, ticketAmount, "0x0000000000000000000000000000000000000000");
    console.log("Added Lottery");
  }

  if(buyTicket){
    if(addLottery) wait(5000);

    var id = 1;

    Factory = await hre.ethers.getContractFactory("AdsFactory");
    Contract = await Factory.attach(adsFactoryAddress);
    Transaction = await Contract.buyTicket(id);
    console.log("Buy Ticket");
  }

  if(claimAd){
    var id = 1;
    var name =  "Name #" + id;
    var description = "Descrption #" + id;
    var image = "https://raw.githubusercontent.com/andreatedesco/DecentralAds/main/demo/assets/images/games/game-00.jpg";
    var url = "https://www.linkedin.com/in/andrea-tedesco-041858199/";

    Factory = await hre.ethers.getContractFactory("AdsFactory");
    Contract = await Factory.attach(adsFactoryAddress);
    Transaction = await Contract.mintAd(id, name, description, image, url);
    console.log("Claimed Adv");
  }

  if(updateAd){
    var id = 0;
    var name =  "Name #" + id;
    var description = "Descrption #" + id;
    var image = "https://raw.githubusercontent.com/andreatedesco/DecentralAds/main/demo/assets/images/games/game-01.jpg";
    var url = "https://www.linkedin.com/in/andrea-tedesco-041858199/";

    Factory = await hre.ethers.getContractFactory("AdsFactory");
    Contract = await Factory.attach(adsFactoryAddress);
    Transaction = await Contract.updateAd(id, name, description, image, url);
    console.log("Updated Adv");
  }

  if(updateIPFSSource){
    const source = fs
      .readFileSync(path.resolve("scripts", "func-loadonipfs.js"))
      .toString();

    Factory = await hre.ethers.getContractFactory("IPFSManager");
    Contract = await Factory.attach(adsIPFSManagerAddress);
    Transaction = await Contract.updateSource(false, source);
    console.log("Update IPFSManager");
  }

  if(testPriceFeed){
    Factory = await hre.ethers.getContractFactory("PriceFeed");
    Contract = await Factory.attach(adsPriceFeedManagerAddress);

    const usdAmount = "1000000000000000000";

    Transaction = await Contract.getCoinPrice(usdAmount);
    console.log("Token Price: " + Transaction);
  }

  console.log("=== END ===");
}

function wait(ms){
    var start = new Date().getTime();
    var end = start;
    while(end < start + ms) {
      end = new Date().getTime();
   }
  }

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
