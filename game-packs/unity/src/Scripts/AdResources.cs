using System;
using System.Linq;
using System.Text;
using System.Collections;
using System.Collections.Generic;
using System.Xml.Linq;
using UnityEngine;
using UnityEngine.Networking;
using Newtonsoft.Json;

namespace DecentralAds
{
    /// <summary>
    /// Represents the structure of an ad URI.
    /// </summary>
    [Serializable]
    public struct AdUri
    {
        public string name;
        public string description;
        public string image;
        public string external_url;
        public List<UriAttributes> attributes;
    }

    /// <summary>
    /// Represents the structure of URI attributes.
    /// </summary>
    [Serializable]
    public struct UriAttributes
    {
        public string trait_type;
        public string value;
    }

    /// <summary>
    /// Represents ad information.
    /// </summary>
    public class AdInfo
    {
        private string ipfsUri;
        private AdUri deserializedUri;

        private uint width = 0;
        private uint height = 0;
        private string imageUri = null;
        private Sprite imageSprite = null;
        private Texture2D imageTexture = null;

        /// <summary>
        /// Gets the name of the ad.
        /// </summary>
        public string GetName() => deserializedUri.name;

        /// <summary>
        /// Gets the description of the ad.
        /// </summary>
        public string GetDescription() => deserializedUri.description;

        /// <summary>
        /// Gets the external URL of the ad.
        /// </summary>
        public string GetSite() => deserializedUri.external_url;

        /// <summary>
        /// Gets the width of the ad.
        /// </summary>
        public uint GetWidth()
        {
            if (width == 0 && deserializedUri.attributes != null && deserializedUri.attributes.Count > 0)
            {
                var attribute = deserializedUri.attributes.FirstOrDefault(attribute => attribute.trait_type.Contains("width", StringComparison.OrdinalIgnoreCase));
                if (!string.IsNullOrEmpty(attribute.value))
                {
                    return width = uint.Parse(attribute.value);
                }
            }
            return width;
        }

        /// <summary>
        /// Gets the height of the ad.
        /// </summary>
        public uint GetHeight()
        {
            if (height == 0 && deserializedUri.attributes != null && deserializedUri.attributes.Count > 0)
            {
                var attribute = deserializedUri.attributes.FirstOrDefault(attribute => attribute.trait_type.Contains("height", StringComparison.OrdinalIgnoreCase));
                if (!string.IsNullOrEmpty(attribute.value))
                {
                    return height = uint.Parse(attribute.value);
                }
            }
            return height;
        }

        /// <summary>
        /// Sets the IPFS URI and triggers the completion action.
        /// </summary>
        public IEnumerator SetIPFSUri(string ipfsUri, Action onCompleted = null)
        {
            if (this.ipfsUri != ipfsUri && ipfsUri != null && ipfsUri.Length > 0)
            {
                this.ipfsUri = ipfsUri;

                using (UnityWebRequest webRequest = UnityWebRequest.Get(ipfsUri))
                {
                    yield return webRequest.SendWebRequest();

                    if (webRequest.result == UnityWebRequest.Result.Success)
                    {
                        try
                        {
                            SetAdUri(JsonConvert.DeserializeObject<AdUri>(webRequest.downloadHandler.text));
                            onCompleted?.Invoke();
                        }
                        catch
                        {
                            onCompleted?.Invoke();
                        }
                    }
                    else
                    {
                        if (!AdsManager.Instance.UriContainsIPFSGateway(ipfsUri) && AdsManager.Instance.IsIPFSGatewayActive())
                        {
                            this.ipfsUri = AdsManager.Instance.GetIPFSGateway(this.ipfsUri.Split("/")[4]);

                            using (UnityWebRequest request = UnityWebRequest.Get(this.ipfsUri))
                            {
                                yield return request.SendWebRequest();

                                if (request.result == UnityWebRequest.Result.Success)
                                {
                                    try
                                    {
                                        SetAdUri(JsonConvert.DeserializeObject<AdUri>(request.downloadHandler.text));
                                        onCompleted?.Invoke();
                                    }
                                    catch
                                    {
                                        onCompleted?.Invoke();
                                    }
                                }
                                else
                                {
                                    onCompleted?.Invoke();
                                }
                            }
                        }
                        else
                        {
                            onCompleted?.Invoke();
                        }
                    }
                }
            }
            else
            {
                onCompleted?.Invoke();
            }
        }

        /// <summary>
        /// Requests the image sprite and triggers the callback action.
        /// </summary>
        public IEnumerator ImageSpriteRequest(Action<Sprite> callback)
        {
            if (imageSprite == null)
            {
                Action action = () =>
                {
                    if (imageTexture != null)
                    {
                        var rect = new Rect(0, 0, imageTexture.width, imageTexture.height);
                        imageSprite = Sprite.Create(imageTexture, rect, UnityEngine.Vector2.one * 0.5f);
                        callback(imageSprite);
                    }
                    else
                    {
                        if (deserializedUri.image == null && deserializedUri.attributes != null && deserializedUri.attributes.Count > 0)
                        {
                            int width = (int)GetWidth();
                            int height = (int)GetHeight();
                            if (width > 0 && height > 0)
                            {
                                Texture2D texture = CreateTexture(width, height, Color.white);
                                var rect = new Rect(0, 0, texture.width, texture.height);
                                callback(Sprite.Create(texture, rect, UnityEngine.Vector2.one * 0.5f));
                            }
                            else
                            {
                                callback(null);
                            }
                        }
                        else
                        {
                            callback(null);
                        }
                    }
                };

                if (imageTexture == null)
                {
                    yield return ImageTextureRequest((tetxure) => action());
                }
                else
                {
                    action();
                }
            }
            else
            {
                callback(imageSprite);
            }
        }

        /// <summary>
        /// Sets the ad URI and resets image-related fields.
        /// </summary>
        private void SetAdUri(AdUri newUri)
        {
            if (deserializedUri.image != newUri.image)
            {
                imageUri = null;
                imageTexture = null;
                imageSprite = null;
            }

            deserializedUri = newUri;
        }

        /// <summary>
        /// Gets the image URI, handling SVG images.
        /// </summary>
        private string GetImageUri()
        {
            if (imageUri == null && !string.IsNullOrEmpty(deserializedUri.image))
            {
                if (deserializedUri.image.Contains("data:image/svg+xml;base64,"))
                {
                    var svg = Base64ToString(deserializedUri.image.Replace("data:image/svg+xml;base64,", ""));
                    XDocument svgDocument = XDocument.Parse(svg);
                    XElement firstHrefElement = svgDocument.Descendants().FirstOrDefault(e => e.Attribute("href") != null);
                    if (firstHrefElement != null)
                    {
                        XAttribute hrefAttribute = firstHrefElement.Attribute("href");
                        if (hrefAttribute != null)
                        {
                            imageUri = hrefAttribute.Value;
                        }
                    }
                }
                else
                {
                    imageUri = deserializedUri.image;
                }
            }
            return imageUri;
        }

        /// <summary>
        /// Requests the image texture and triggers the callback action.
        /// </summary>
        private IEnumerator ImageTextureRequest(Action<Texture2D> callback)
        {
            if (imageTexture == null)
            {
                using (var www = UnityWebRequestTexture.GetTexture(GetImageUri()))
                {
                    yield return www.SendWebRequest();

                    if (www.result == UnityWebRequest.Result.ConnectionError || www.result == UnityWebRequest.Result.ProtocolError)
                    {
                        callback(null);
                    }
                    else
                    {
                        if (www.isDone)
                        {
                            imageTexture = DownloadHandlerTexture.GetContent(www);
                            callback(imageTexture);
                        }
                    }
                }
            }
            else
            {
                callback(imageTexture);
            }
        }

        /// <summary>
        /// Creates a texture with the given width, height, and color.
        /// </summary>
        private Texture2D CreateTexture(int width, int height, Color color)
        {
            Texture2D texture = new Texture2D(width, height);
            Color[] pixels = new Color[width * height];

            for (int i = 0; i < pixels.Length; i++) pixels[i] = color;
            texture.SetPixels(pixels);
            texture.Apply();

            return texture;
        }

        /// <summary>
        /// Converts a base64 string to a plain string.
        /// </summary>
        private string Base64ToString(string base64)
        {
            var blob = Convert.FromBase64String(base64);
            var json = Encoding.UTF8.GetString(blob);
            return json;
        }
    }

    /// <summary>
    /// Provides debugging functionality with conditional compilation for the Unity Editor.
    /// </summary>
    public class Debugger
    {
#if UNITY_EDITOR
        private static bool debug = true;
#else
        private static bool debug = false;
#endif

        /// <summary>
        /// Logs a message if debugging is enabled.
        /// </summary>
        public static void Log(string log) { if (debug) Debug.Log(log); }

        /// <summary>
        /// Logs a warning message if debugging is enabled.
        /// </summary>
        public static void LogWarning(string log) { if (debug) Debug.LogWarning(log); }

        /// <summary>
        /// Logs an error message if debugging is enabled.
        /// </summary>
        public static void LogError(string log) { if (debug) Debug.LogError(log); }
    }
}
