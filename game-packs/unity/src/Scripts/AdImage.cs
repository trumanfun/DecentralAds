using System.Numerics;
using UnityEngine;
using UnityEngine.UI;

namespace DecentralAds
{
    /// <summary>
    /// Represents an ad image.
    /// </summary>
    public class AdImage : Ad
    {
        [Header("AdImage")]
        [SerializeField] private Image frame;
        [SerializeField] private Image content;

        /// <summary>
        /// Overrides the SetData method from the base class.
        /// Sets the sprite, and adjusts the size if width and height are positive.
        /// </summary>
        /// <param name="sprite">Sprite of the ad.</param>
        /// <param name="width">Width of the ad.</param>
        /// <param name="height">Height of the ad.</param>
        protected override void SetData(Sprite sprite, float width, float height)
        {
            content.sprite = sprite;
            if (width > 0 && height > 0) frame.rectTransform.sizeDelta = new UnityEngine.Vector2(width, height);
        }
    }
}