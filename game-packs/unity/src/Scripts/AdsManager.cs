using System;
using System.Numerics;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Nethereum.Contracts;
using Nethereum.ABI.FunctionEncoding.Attributes;
using Nethereum.Unity.Rpc;
using Nethereum.RPC.Eth.DTOs;
using Nethereum.Unity.Metamask;

namespace DecentralAds
{
    /// <summary>
    /// Manages ads functionality.
    /// </summary>
    public class AdsManager : MonoBehaviour
    {
        /// <summary>
        /// Singleton instance of AdsManager.
        /// </summary>
        public static AdsManager Instance { get; private set; }

        [Header("AdsManager")]

        /// <summary>
        /// Contract address to interact with.
        /// </summary>
        [SerializeField] private string contractAddress = null;

        [Space]

        /// <summary>
        /// Use Metamask in WebGL build.
        /// </summary>
        [SerializeField] private bool useMetamaskInWebGL = false;

        /// <summary>
        ///  Node URL for Ethereum RPC calls.
        /// </summary>
        [SerializeField] private string nodeUrl = "https://avalanche-fuji.infura.io/v3/<key>";

        [Space]

        /// <summary>
        /// IPFS gateway for fetching IPFS content.
        /// </summary>
        [SerializeField] private string ipfsGateway = "https://<gateway>.mypinata.cloud/ipfs/{0}/?pinataGatewayToken=<gatewayToken>";

        [Space(20f)]
        [SerializeField] private Sprite errorSprite = null;
        [SerializeField] private Sprite mintableSprite = null;

        private int currentSupply = 0;
        private Dictionary<BigInteger, AdInfo> ads = new Dictionary<BigInteger, AdInfo>();
        private Action<BigInteger, AdInfo> onAdInfoLoaded;
        private Coroutine refreshRoutine = null;

        /// <summary>
        /// Gets the error sprite.
        /// </summary>
        public Sprite ErrorSprite { get => errorSprite; }

        /// <summary>
        /// Gets the mintable sprite.
        /// </summary>
        public Sprite MintableSprite { get => mintableSprite; }

        /// <summary>
        /// Checks if the IPFS gateway is active.
        /// </summary>
        /// <returns>True if IPFS gateway is active, otherwise false.</returns>
        public bool IsIPFSGatewayActive() => !string.IsNullOrEmpty(ipfsGateway);

        /// <summary>
        /// Gets the IPFS gateway with the given CID.
        /// </summary>
        /// <param name="cid">Content IDentifier.</param>
        /// <returns>Formatted IPFS gateway.</returns>
        public string GetIPFSGateway(string cid) => string.Format(ipfsGateway, cid);

        /// <summary>
        /// Checks if the URI contains the IPFS gateway.
        /// </summary>
        /// <param name="uri">Uniform Resource Identifier.</param>
        /// <returns>True if URI contains IPFS gateway, otherwise false.</returns>
        public bool UriContainsIPFSGateway(string uri) => uri.Contains(ipfsGateway.Split("/")[2], StringComparison.OrdinalIgnoreCase);

        /// <summary>
        /// Awake method.
        /// </summary>
        private void Awake()
        {
            if (Instance == null)
            {
                Instance = this;
            }
            else
            {
                Destroy(gameObject);
            }
        }

        /// <summary>
        /// Start method.
        /// </summary>
        /// <returns>Coroutine.</returns>
        private IEnumerator Start()
        {
            yield return Refresh();
        }

        /// <summary>
        /// Subscribes to the AdInfoLoaded event.
        /// </summary>
        /// <param name="action">Action to be executed when AdInfoLoaded event is triggered.</param>
        public void SubscribeOnAdInfoLoaded(Action<BigInteger, AdInfo> action)
        {
            onAdInfoLoaded += action;
        }

        /// <summary>
        /// Refreshes AdsInfo data.
        /// </summary>
        [ContextMenu("Refresh")]
        public Coroutine Refresh()
        {
            if (refreshRoutine == null) refreshRoutine = StartCoroutine(CoRefreshAdsInfos());
            return refreshRoutine;
        }

        /// <summary>
        /// Coroutine for refreshing AdsInfos.
        /// </summary>
        /// <param name="onCompleted">Action to be executed when the refresh is completed.</param>
        /// <param name="step">Step size for the refresh.</param>
        /// <returns>Coroutine.</returns>
        private IEnumerator CoRefreshAdsInfos(Action onCompleted = null, int step = 1)
        {
            bool actionCompleted = false;
            bool actionResult = false;
            Action<bool> action = result =>
            {
                actionCompleted = true;
                actionResult = result;
            };

            // Get Supply
            while (!actionResult)
            {
                actionCompleted = false;
                GetSupply
                (
                    (result) =>
                    {
                        currentSupply = (int)result.Supply;
                        action.Invoke(true);
                    },
                    (error) =>
                    {
                        action.Invoke(false);
                    }
                );
                yield return new WaitUntil(() => actionCompleted);
            }

            // Get TokenUri
            for (int i = 0; i < currentSupply; i += step)
            {
                actionCompleted = false;
                GetUri(i, action);
                yield return new WaitUntil(() => actionCompleted);
            }

            onCompleted?.Invoke();
            refreshRoutine = null;
        }

        /// <summary>
        /// Gets the URI for the given token ID.
        /// </summary>
        /// <param name="tokenID">Token ID.</param>
        /// <param name="onCompleted">Action to be executed when the URI is loaded.</param>
        private void GetUri(BigInteger tokenID, Action<bool> onCompleted = null)
        {
            GetUri
            (
                tokenID,
                (result) =>
                {
                    if (!ads.ContainsKey(tokenID))
                    {
                        ads.Add(tokenID, new AdInfo());
                    }

                    StartCoroutine(ads[tokenID].SetIPFSUri(result.Uri, () => onAdInfoLoaded?.Invoke(tokenID, ads[tokenID])));
                    onCompleted?.Invoke(true);
                    Debugger.Log($"[{tokenID}]: {result.Uri}");
                },
                (error) =>
                {
                    onCompleted?.Invoke(false);
                    Debugger.LogError($"[{tokenID}]: {error}");
                }
            );
        }

        /// <summary>
        /// Gets the current supply of ads.
        /// </summary>
        /// <param name="onResult">Action to be executed on successful result.</param>
        /// <param name="onFailure">Action to be executed on failure.</param>
        private void GetSupply(Action<CurrentSupplyOutput> onResult = null, Action<string> onFailure = null)
        {
            var function = new CurrentSupplyFunction();
            StartCoroutine(QueryContract(contractAddress, function, onResult, onFailure));
        }

        /// <summary>
        /// Gets the URI for the given token ID.
        /// </summary>
        /// <param name="tokenId">Token ID.</param>
        /// <param name="onResult">Action to be executed on successful result.</param>
        /// <param name="onFailure">Action to be executed on failure.</param>
        private void GetUri(BigInteger tokenId, Action<TokenURIOutputDTO> onResult = null, Action<string> onFailure = null)
        {
            var function = new TokenURIFunction() { TokenId = tokenId };
            StartCoroutine(QueryContract(contractAddress, function, onResult, onFailure));
        }

        /// <summary>
        /// Gets the UnityRpcRequestClientFactory.
        /// </summary>
        /// <param name="isGetter">Specifies whether it is a getter function.</param>
        /// <returns>UnityRpcRequestClientFactory instance.</returns>
        private IUnityRpcRequestClientFactory GetUnityRpcRequestClientFactory(bool isGetter = true)
        {
#if UNITY_WEBGL
            if (IsWebGL() && useMetamaskInWebGL)
            {
                if (MetamaskInterop.IsMetamaskAvailable()) return new MetamaskRequestRpcClientFactory();
                return null;
            }
            else
#endif
            {
                return new UnityWebRequestRpcClientFactory(nodeUrl);
            }
        }

        /// <summary>
        /// Checks if the platform is WebGL.
        /// </summary>
        /// <returns>True if the platform is WebGL, otherwise false.</returns>
        private static bool IsWebGL()
        {
#if UNITY_WEBGL && !UNITY_EDITOR
            return true;
#else
            return false;
#endif
        }

        /// <summary>
        /// Queries the contract using UnityRpcRequest.
        /// </summary>
        /// <typeparam name="TFunction">FunctionMessage type.</typeparam>
        /// <typeparam name="TOutput">Output type.</typeparam>
        /// <param name="contractAddress">Contract address.</param>
        /// <param name="function">FunctionMessage instance.</param>
        /// <param name="onCompleted">Action to be executed on successful result.</param>
        /// <param name="onFailure">Action to be executed on failure.</param>
        /// <returns>Coroutine.</returns>
        private IEnumerator QueryContract<TFunction, TOutput>
        (
            string contractAddress,
            TFunction function,
            Action<TOutput> onCompleted = null,
            Action<string> onFailure = null
        )
            where TFunction : FunctionMessage, new()
            where TOutput : IFunctionOutputDTO, new()
        {
            var client = GetUnityRpcRequestClientFactory();
            var callUnityRequest = new EthCallUnityRequest(client);
            var input = function.CreateCallInput(contractAddress);

            yield return callUnityRequest.SendRequest(input, BlockParameter.CreateLatest());

            if (callUnityRequest.Exception != null)
            {
                onFailure?.Invoke(callUnityRequest.Exception.Message);
            }
            else
            {
                try
                {
                    var result = new TOutput().DecodeOutput(callUnityRequest.Result);
                    onCompleted?.Invoke(result);
                }
                catch (Exception e)
                {
                    onFailure?.Invoke(e.Message);
                }
            }
        }
    }
}
