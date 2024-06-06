const titleId = '3EA44';
const statisticName = 'level';
const startPosition = 0;
const maxResultsCount = 1;
const getLeaderboardUrl = `https://${titleId}.playfabapi.com/Server/GetLeaderboard?StatisticName=${statisticName}&StartPosition=${startPosition}&MaxResultsCount=${maxResultsCount}`;
const getUserAccountInfoUrl = `https://${titleId}.playfabapi.com/Server/GetUserAccountInfo`;

const leaderboardReq = await Functions.makeHttpRequest({
    url: getLeaderboardUrl,
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'Accept-Encoding': 'identity',
        'X-SecretKey': secrets.playfabApiKey
    },
});

if (leaderboardReq.error) throw new Error(`${leaderboardReq.message}`);

const playFabId = leaderboardReq.data.data.Leaderboard[0].PlayFabId;
const apiResponse = await Functions.makeHttpRequest({
    url: getUserAccountInfoUrl,
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'Accept-Encoding': 'identity',
        'X-SecretKey': secrets.playfabApiKey
    },
    params: {
        'PlayFabID': playFabId,
    }
});

if (apiResponse.error) throw new Error(`${apiResponse.message}`);

return Functions.encodeString(apiResponse.data.data.UserInfo.CustomIdInfo.CustomId);