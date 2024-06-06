const {
  SecretsManager,
} = require("@chainlink/functions-toolkit");
const ethers = require("ethers");
require("@chainlink/env-enc").config();

const makeRequest = async () => {

  // hardcoded for Avalanche Fuji
  const routerAddress = "0xA9d587a00A31A52Ed70D6026794a8FC5E2F5dCb0";
  const donId = "fun-avalanche-fuji-1";

  const secretsUrls = [
    process.env.DEMO_SECRET_URL,
  ];

  // Initialize ethers signer and provider to interact with the contracts onchain
  const privateKey = process.env.PRIVATE_KEY; // fetch PRIVATE_KEY
  if (!privateKey)
    throw new Error(
      "private key not provided - check your environment variables"
    );

  const rpcUrl = process.env.API_URL_FUJI; // fetch fuji RPC URL

  if (!rpcUrl)
    throw new Error(`rpcUrl not provided  - check your environment variables`);

  const provider = new ethers.providers.JsonRpcProvider(rpcUrl);

  const wallet = new ethers.Wallet(privateKey);
  const signer = wallet.connect(provider); // create ethers signer for signing transactions


  //////// MAKE REQUEST ////////

  console.log("\nMake request...");

  // Initialize SecretsManager instance
  const secretsManager = new SecretsManager({
    signer: signer,
    functionsRouterAddress: routerAddress,
    donId: donId,
  });
  await secretsManager.initialize();

  // Encrypt secrets Urls

  console.log(`\nEncrypt the URLs..`);
  const encryptedSecretsUrls = await secretsManager.encryptSecretsUrls(
    secretsUrls
  );

  console.log(encryptedSecretsUrls);
};

makeRequest().catch((e) => {
  console.error(e);
  process.exit(1);
});