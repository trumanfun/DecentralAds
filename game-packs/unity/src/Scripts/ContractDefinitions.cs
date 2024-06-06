using System.Numerics;
using Nethereum.ABI.FunctionEncoding.Attributes;
using Nethereum.Contracts;

namespace DecentralAds
{
    /// <summary>
    /// Represents the function message for retrieving the token URI.
    /// </summary>
    [Function("tokenURI", "string")]
    public class TokenURIFunction : FunctionMessage
    {
        [Parameter("uint256", "tokenId", 1)]
        public BigInteger TokenId { get; set; }
    }

    /// <summary>
    /// Represents the function output DTO for the token URI.
    /// </summary>
    [FunctionOutput]
    public class TokenURIOutputDTO : IFunctionOutputDTO
    {
        [Parameter("string", "", 1)]
        public string Uri { get; set; }
    }

    /// <summary>
    /// Represents the function message for retrieving the current supply.
    /// </summary>
    [Function("currentSupply", "uint256")]
    public class CurrentSupplyFunction : FunctionMessage
    {
    }

    /// <summary>
    /// Represents the function output DTO for the current supply.
    /// </summary>
    [FunctionOutput]
    public class CurrentSupplyOutput : IFunctionOutputDTO
    {
        [Parameter("uint256", "", 1)]
        public virtual BigInteger Supply { get; set; }
    }
}
