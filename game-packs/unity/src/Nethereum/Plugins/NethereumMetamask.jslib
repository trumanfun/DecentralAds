mergeInto(LibraryManager.library, {

    EnableEthereum: async function (gameObjectName, callback, fallback) {
        const parsedObjectName = UTF8ToString(gameObjectName);
        const parsedCallback = UTF8ToString(callback);
        const parsedFallback = UTF8ToString(fallback);
        
        try {
            
            const accounts = await ethereum.request({ method: 'eth_requestAccounts' });
            ethereum.autoRefreshOnNetworkChange = false;

            var bufferSize = lengthBytesUTF8(accounts[0]) + 1;
            var buffer = _malloc(bufferSize);
            stringToUTF8(accounts[0], buffer, bufferSize);
            nethereumUnityInstance.SendMessage(parsedObjectName, parsedCallback, accounts[0]);
            return buffer;
        } catch (error) {
            nethereumUnityInstance.SendMessage(parsedObjectName, parsedFallback, error.message);
            return null;
        }GetTransactionCount
    },

    EthereumInit: function(gameObjectName, callBackAccountChange, callBackChainChange){
        const parsedObjectName = UTF8ToString(gameObjectName);
        const parsedCallbackAccountChange = UTF8ToString(callBackAccountChange);
        const parsedCallbackChainChange = UTF8ToString(callBackChainChange);

        // console.log("EthereumInit");
            
        ethereum.on("accountsChanged",
            function (accounts) {
                let account = "";
                if (accounts.length === 0);
                else account = accounts[0];
                nethereumUnityInstance.SendMessage(parsedObjectName, parsedCallbackAccountChange, account);
                // console.log("accountsChanged: " + account);
        });

        ethereum.on("chainChanged",
            function (chainId) {
                // console.log(chainId);
                nethereumUnityInstance.SendMessage(parsedObjectName, parsedCallbackChainChange, chainId.toString());
        });
    },

    Init: function(gameObjectName, callBackAccountChange, callBackChainChange, callBackConnect, callBackDisconnect){
        const parsedObjectName = UTF8ToString(gameObjectName);
        const parsedCallbackAccountChange = UTF8ToString(callBackAccountChange);
        const parsedCallbackChainChange = UTF8ToString(callBackChainChange);
        const parsedCallBackConnect = UTF8ToString(callBackConnect);
        const parsedCallBackDisconnect = UTF8ToString(callBackDisconnect);

        // console.log("EthereumInit");
            
        ethereum.on("accountsChanged",
            function (accounts) {
                let account = "";
                if (accounts.length === 0);
                else account = accounts[0];
                nethereumUnityInstance.SendMessage(parsedObjectName, parsedCallbackAccountChange, account);
                // console.log("accountsChanged: " + account);
        });

        ethereum.on("chainChanged",
            function (chainId) {
                // console.log(chainId);
                nethereumUnityInstance.SendMessage(parsedObjectName, parsedCallbackChainChange, chainId.toString());
        });

        ethereum.on('connect',
            function (handler) {
                // console.log("connect: " + handler);
                nethereumUnityInstance.SendMessage(parsedObjectName, parsedCallBackConnect, handler.toString());
        });

        ethereum.on('disconnect',
            function (handler) {
                // console.log("disconnect: " + handler);
                nethereumUnityInstance.SendMessage(parsedObjectName, parsedCallBackDisconnect, handler.toString());
        });
    },

    GetChainId: async function(gameObjectName, callback, fallback) {
           const parsedObjectName = UTF8ToString(gameObjectName);
           const parsedCallback = UTF8ToString(callback);
           const parsedFallback = UTF8ToString(fallback);
          try {
           
            const chainId = await ethereum.request({ method: 'eth_chainId' });
            nethereumUnityInstance.SendMessage(parsedObjectName, parsedCallback, chainId.toString());

          } catch (error) {
            nethereumUnityInstance.SendMessage(parsedObjectName, parsedFallback, error.message);
            return null;
         }
    },

    IsMetamaskAvailable: function () {
        if (window.ethereum) return true;
        return false;
    },

    GetSelectedAddress: function () {
        var returnValue = ethereum.selectedAddress;
        if(returnValue !== null) {
            var bufferSize = lengthBytesUTF8(returnValue) + 1;
            var buffer = _malloc(bufferSize);
            stringToUTF8(returnValue, buffer, bufferSize);
            return buffer;
        }
    },
    
    GetTransactionCount: async function(gameObjectName, callback, fallback) {
        const parsedObjectName = UTF8ToString(gameObjectName);
        const parsedCallback = UTF8ToString(callback);
        const parsedFallback = UTF8ToString(fallback);
       try {
        
         const transactionCount = await ethereum.request({ method: 'eth_getTransactionCount' });
         nethereumUnityInstance.SendMessage(parsedObjectName, parsedCallback, transactionCount.toString());

       } catch (error) {
         nethereumUnityInstance.SendMessage(parsedObjectName, parsedFallback, error.message);
      }
    },

    WaitForTxToBeMinedCallback: async function (txHash, gameObjectName, callback) {
        const parsedParams = UTF8ToString(txHash);
        const parsedObjectName = UTF8ToString(gameObjectName);
        const parsedCallback = UTF8ToString(callback);
        let txReceipt;
        try {
            txReceipt = await ethereum.request({
                method: 'eth_getTransactionReceipt',
                params: [parsedParams],
            });
        } catch (err) {
            txReceipt = "transactionHasError";
        }
        if(!txReceipt) txReceipt = "transactionIsntMined";

        // JSON.parse(rpcResponse);
        let txReceiptStr = JSON.stringify(txReceipt);
        // console.log(txReceiptStr);
        nethereumUnityInstance.SendMessage(parsedObjectName, parsedCallback, txReceiptStr);
    },

    Request: async function (message, gameObjectName, callback, fallback ) {
        const parsedMessageStr = UTF8ToString(message);
        const parsedObjectName = UTF8ToString(gameObjectName);
        const parsedCallback = UTF8ToString(callback);
        const parsedFallback = UTF8ToString(fallback);
        let parsedMessage = JSON.parse(parsedMessageStr);
        try {
            // console.log("[-] [" + parsedMessage.id + " - " + parsedMessage.method + "] Request_parsedMessage: " +  JSON.stringify(parsedMessage));
            const response = await ethereum.request(parsedMessage);
            let rpcResponse = {
                jsonrpc: "2.0",
                result: response,
                id: parsedMessage.id,
                error: null
            }
            
            var json = JSON.stringify(rpcResponse);
            // console.log("[-] [" + parsedMessage.id + " - " + parsedMessage.method + "] Request_rpcResponse: " +  json);

            nethereumUnityInstance.SendMessage(parsedObjectName, parsedCallback, json);
            return json;
        } catch (e) {
            let rpcResonseError = {
                jsonrpc: "2.0",
                id: parsedMessage.id,
                error: {
                    message: e.message,
                }
            }
            var json =  JSON.stringify(rpcResonseError);
            nethereumUnityInstance.SendMessage(parsedObjectName, parsedFallback, json);
            return json;
        }
    },

    RequestRpcClientCallback: async function (callback, message) {
        // console.log(callback);
        const parsedMessageStr = UTF8ToString(message);
        const parsedCallback = UTF8ToString(callback);
        let parsedMessage = JSON.parse(parsedMessageStr);
        try {
            
            // console.log("[-] [" + parsedMessage.id + " - " + parsedMessage.method + "] RequestRpcClientCallback_parsedMessage: " +  JSON.stringify(parsedMessage));

            const response = await ethereum.request(parsedMessage);
            let rpcResponse = {
                jsonrpc: "2.0",
                result: response,
                id: parsedMessage.id,
                error: null
            }

            var json = JSON.stringify(rpcResponse);
            // console.log("[-] [" + parsedMessage.id + " - " + parsedMessage.method + "] RequestRpcClientCallback_json: " +  json);
           
            var len = lengthBytesUTF8(json) + 1;
            var strPtr = _malloc(len);
            stringToUTF8(json, strPtr, len);
            // console.log(strPtr);
            Module.dynCall_vi(callback, strPtr);

            return json;
        } catch (e) {
            // console.log("[-] [" + parsedMessage.id + " - " + parsedMessage.method + "] RequestRpcClientCallback_errorMessage: " +  e.toString());

            let rpcResonseError = {
                jsonrpc: "2.0",
                id: parsedMessage.id,
                error: {
                    message: e.message,
                }
            }
            var json = JSON.stringify(rpcResonseError);
            // console.log("[-] [" + parsedMessage.id + " - " + parsedMessage.method + "] RequestRpcClientCallback_errorResponse: " +  json);

            var len = lengthBytesUTF8(json) + 1;
            var strPtr = _malloc(len);
            stringToUTF8(json, strPtr, len);

            Module.dynCall_vi(callback, strPtr);
        }
    },
});