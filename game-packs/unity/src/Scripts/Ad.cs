using System.Numerics;
using UnityEngine;
using UnityEngine.UI;

namespace DecentralAds
{
    /// <summary>
    /// Abstract class representing an ad.
    /// </summary>
    public abstract class Ad : MonoBehaviour
    {
        [Header("Ad")]
        [SerializeField] private int id;

        /// <summary>
        /// Called on the start of the script.
        /// Subscribes to the AdInfoLoaded event of AdsManager.
        /// </summary>
        private void Start()
        {
            AdsManager.Instance.SubscribeOnAdInfoLoaded(SetAdInfo);
        }

        /// <summary>
        /// Sets the ad information based on the provided token ID and AdInfo.
        /// </summary>
        /// <param name="tokenID">Token ID of the ad.</param>
        /// <param name="adInfo">AdInfo containing information about the ad.</param>
        public void SetAdInfo(BigInteger tokenID, AdInfo adInfo)
        {
            if (id == tokenID)
            {
                StartCoroutine(adInfo.ImageSpriteRequest((sprite) =>
                {
                    float width = adInfo.GetWidth();
                    float height = adInfo.GetHeight();
                    SetData(width > 0 && height > 0 ? sprite ?? AdsManager.Instance.ErrorSprite : AdsManager.Instance.MintableSprite, width, height);
                }));
            }
        }

        /// <summary>
        /// Abstract method to be implemented by derived classes.
        /// Sets the data of the ad, such as the sprite, width, and height.
        /// </summary>
        /// <param name="sprite">Sprite of the ad.</param>
        /// <param name="width">Width of the ad.</param>
        /// <param name="height">Height of the ad.</param>
        protected abstract void SetData(Sprite sprite, float width, float height);
    }
}