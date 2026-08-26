using System;
using ComTam.Core.Content;
using ComTam.Core.Domain;
using ComTam.Core.Util;

namespace ComTam.Core.Economy
{
    public struct SatisfactionResult
    {
        /// <summary>0-100.</summary>
        public int Score;
        /// <summary>1-5.</summary>
        public int Stars;
        public int PlateQuality;
        public bool OrderAccurate;
    }

    /// <summary>
    /// Brief section 11:
    ///   satisfaction = 40*wait + 30*quality + 20*accuracy + 10*price
    /// A pure function, and the most heavily tested method in the codebase.
    /// </summary>
    public static class SatisfactionCalculator
    {
        public static SatisfactionResult Evaluate(
            BalanceConfig balance,
            double patienceRemaining01,
            int plateQuality,
            bool orderAccurate)
        {
            double wait = MathX.Clamp01(patienceRemaining01);
            double quality = MathX.Clamp01(plateQuality / 100.0);
            double accuracy = orderAccurate ? 1.0 : 0.0;
            double price = 1.0; // no dynamic pricing in Phase 1

            double score =
                balance.SatWaitWeight * wait +
                balance.SatQualityWeight * quality +
                balance.SatAccuracyWeight * accuracy +
                balance.SatPriceWeight * price;

            score = MathX.Clamp(score, 0.0, 100.0);

            SatisfactionResult r;
            r.Score = (int)Math.Round(score, MidpointRounding.AwayFromZero);
            r.Stars = StarsFromScore(r.Score);
            r.PlateQuality = plateQuality;
            r.OrderAccurate = orderAccurate;
            return r;
        }

        public static int StarsFromScore(int score)
        {
            int stars = (int)Math.Round(score / 20.0, MidpointRounding.AwayFromZero);
            return MathX.ClampInt(stars, 1, 5);
        }

        /// <summary>
        /// Tip for a completed sale. Only 4- and 5-star service tips, and the roll
        /// consumes the injected RNG so the day stays replayable.
        /// </summary>
        public static Money CalculateTip(
            BalanceConfig balance,
            CustomerArchetypeDef archetype,
            int stars,
            Money price,
            IRandom rng)
        {
            if (stars < balance.TipMinStars) return Money.Zero;
            if (!rng.Chance(archetype.TipChance)) return Money.Zero;

            double rate = balance.TipRateAt4Stars
                          + balance.TipRatePerStarAbove4 * (stars - balance.TipMinStars);
            return price * rate;
        }
    }
}
