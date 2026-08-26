namespace ComTam.Core.Content
{
    /// <summary>
    /// Every tunable number in the game (brief section 39). Nothing in the
    /// simulation may hardcode a balance value - it reads it from here.
    ///
    /// These defaults mirror <c>/content/balance.json</c>, and
    /// <c>BalanceJsonMatchesDefaultsTests</c> fails the build if the two drift
    /// apart. In Phase 2 the JSON becomes authoritative and these become the
    /// fallback; the test keeps them honest until then.
    /// </summary>
    public sealed class BalanceConfig
    {
        // ---- Economy ----
        public long StartingMoneyDong = 100000;
        public long ComSuonPriceDong = 45000;

        public long RiceCostDong = 3000;
        public long PorkCostDong = 12000;
        public long SauceCostDong = 1000;

        // ---- Day pacing ----
        public double DayLengthSeconds = 150.0;
        public int CustomersOnDay1 = 6;
        public double FirstSpawnDelaySeconds = 2.0;
        public double SpawnIntervalSeconds = 22.0;
        public double SpawnJitterSeconds = 4.0;
        public int QueueCapacity = 3;

        // ---- Grilling (Grill Level 1) ----
        public double GrillRawUntilSeconds = 3.0;
        public double GrillPerfectStartSeconds = 4.6;
        public double GrillPerfectEndSeconds = 6.0;
        public double GrillBurntAtSeconds = 8.0;

        /// <summary>
        /// Late-tap forgiveness. A tap this many seconds past PerfectEnd still
        /// counts as Perfect. Near-misses should feel generous, not punishing
        /// (see risk R1).
        /// </summary>
        public double GrillGraceSeconds = 0.08;

        public int PorkCookingQuality = 50;
        public int PorkOvercookedHighQuality = 70;
        public int PorkOvercookedLowQuality = 35;

        // ---- Fixed component quality (upgrades raise these later) ----
        public int RiceQuality = 85;
        public int SauceQuality = 100;

        // ---- Penalties ----
        /// <summary>Patience lost by every waiting customer when pork burns.</summary>
        public double BurnPatiencePenalty = 0.08;

        // ---- Satisfaction weights (brief section 11), must sum to 100 ----
        public double SatWaitWeight = 40.0;
        public double SatQualityWeight = 30.0;
        public double SatAccuracyWeight = 20.0;
        public double SatPriceWeight = 10.0;

        // ---- Tips ----
        public int TipMinStars = 4;
        public double TipRateAt4Stars = 0.05;
        public double TipRatePerStarAbove4 = 0.05;

        // ---- Customer timings ----
        public double EatingSeconds = 3.0;
        public double WalkToQueueSeconds = 1.0;
        public double OrderingSeconds = 0.6;
        public double ReceivingFoodSeconds = 0.5;
        public double LeavingSeconds = 0.8;

        // ---- Daily goal ----
        public int Day1GoalCustomers = 5;
        public long Day1GoalBonusDong = 50000;

        public static BalanceConfig Default()
        {
            return new BalanceConfig();
        }
    }
}
