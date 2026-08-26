using ComTam.Core.Domain;

namespace ComTam.Core.Simulation
{
    public enum TakeOffOutcome
    {
        /// <summary>Nothing on the grill.</summary>
        Empty = 0,
        /// <summary>Still raw - the tap is refused so the player cannot waste a chop by accident.</summary>
        StillRaw = 1,
        /// <summary>Removed; check <see cref="CookStation.LastQuality"/>.</summary>
        Removed = 2
    }

    /// <summary>
    /// One grill slot. Phase 1 has exactly one; multi-slot grills are a Phase 4
    /// upgrade, which is why the class is per-station rather than a singleton.
    /// </summary>
    public sealed class CookStation
    {
        private readonly CookProfile _profile;
        private readonly double _graceSeconds;
        private readonly int _cookingQuality;
        private readonly int _overcookedHigh;
        private readonly int _overcookedLow;

        public bool Occupied { get; private set; }
        public double Elapsed { get; private set; }
        public int LastQuality { get; private set; }
        public Doneness LastDoneness { get; private set; }

        public CookProfile Profile { get { return _profile; } }

        public CookStation(CookProfile profile, double graceSeconds,
                           int cookingQuality, int overcookedHigh, int overcookedLow)
        {
            _profile = profile;
            _graceSeconds = graceSeconds;
            _cookingQuality = cookingQuality;
            _overcookedHigh = overcookedHigh;
            _overcookedLow = overcookedLow;
        }

        /// <summary>Doneness right now, ignoring grace (this is what the UI bar draws).</summary>
        public Doneness CurrentDoneness
        {
            get { return Occupied ? _profile.Evaluate(Elapsed) : Doneness.Raw; }
        }

        /// <summary>0-1 progress along the whole bar, for rendering.</summary>
        public double Progress01
        {
            get
            {
                if (!Occupied || _profile.BurntAt <= 0) return 0.0;
                double p = Elapsed / _profile.BurntAt;
                return p > 1.0 ? 1.0 : p;
            }
        }

        public bool Place()
        {
            if (Occupied) return false;
            Occupied = true;
            Elapsed = 0.0;
            return true;
        }

        /// <summary>
        /// Advances the timer. Returns true if the pork just burned this tick, in
        /// which case the station has already been cleared and the chop is lost.
        /// </summary>
        public bool Tick(double dt)
        {
            if (!Occupied) return false;

            bool wasBurnt = _profile.Evaluate(Elapsed) == Doneness.Burnt;
            Elapsed += dt;
            bool isBurnt = _profile.Evaluate(Elapsed) == Doneness.Burnt;

            if (isBurnt && !wasBurnt)
            {
                Occupied = false;
                Elapsed = 0.0;
                LastDoneness = Doneness.Burnt;
                LastQuality = 0;
                return true;
            }
            return false;
        }

        /// <summary>
        /// Player taps the grill to take the pork off.
        ///
        /// Applies late-tap grace: a tap up to <c>graceSeconds</c> past the perfect
        /// window still scores Perfect. Near-misses should feel generous - this is
        /// the single cheapest thing we can do for how the grill feels (risk R1).
        /// </summary>
        public TakeOffOutcome TakeOff()
        {
            if (!Occupied) return TakeOffOutcome.Empty;

            Doneness raw = _profile.Evaluate(Elapsed);
            if (raw == Doneness.Raw) return TakeOffOutcome.StillRaw;

            double effective = Elapsed;
            if (raw == Doneness.Overcooked && (Elapsed - _profile.PerfectEnd) <= _graceSeconds)
                effective = _profile.PerfectEnd;

            LastDoneness = _profile.Evaluate(effective);
            LastQuality = _profile.QualityAt(effective, _cookingQuality, _overcookedHigh, _overcookedLow);

            Occupied = false;
            Elapsed = 0.0;
            return TakeOffOutcome.Removed;
        }

        public void Reset()
        {
            Occupied = false;
            Elapsed = 0.0;
            LastQuality = 0;
            LastDoneness = Doneness.Raw;
        }
    }
}
