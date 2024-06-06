const name = args[0];
const description = args[1];
const image = args[2];
const external_url = args[3];
const width = args[4];
const height = args[5];
const price = parseFloat(args[6]) / Math.pow(10, 18);
const lottery = args.length > 7;

const jsonData = {
  pinataContent: {
    name: name,
    description: description,
    external_url: external_url,
    image: image,
    animation_url: `https://www.onchainconsole.com/preview.html?image=${image}&width=${width}&height=${height}&isLottery=${lottery}`,
    attributes: [{ trait_type: 'Width (cm)', value: `${width}` }, { trait_type: 'Height (cm)', value: `${height}` }, { trait_type: !lottery ? 'Mint Price (USD)' : 'Ticket Price (USD)', value: `${price}` }, !lottery ? {} : { trait_type: 'Ticket Amount', value: args[7] }]
  }
};

const apiResponse = await Functions.makeHttpRequest({
  url: 'https://api.pinata.cloud/pinning/pinJSONToIPFS',
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': `Bearer ${secrets.pinataJWT}`
  },
  data: jsonData
});

if (apiResponse.error) {
  throw new Error(`message: ${apiResponse.message} code: ${apiResponse.code} response: ${JSON.stringify(apiResponse.response)}`);
}

return Functions.encodeString(`https://ipfs.io/ipfs/${apiResponse.data.IpfsHash}`);