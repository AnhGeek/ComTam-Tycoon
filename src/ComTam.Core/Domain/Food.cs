using System;
using System.Collections.Generic;

namespace ComTam.Core.Domain
{
    /// <summary>Food components. Phase 1 uses Rice, Pork and Sauce only.</summary>
    public enum ComponentId
    {
        Rice = 0,
        Pork = 1,
        Sauce = 2,
        Egg = 3,   // reserved: Phase 2
        Bi = 4,    // reserved: Phase 3
        Cha = 5    // reserved: Phase 3
    }

    /// <summary>How well a piece of pork was cooked. Order matters: it is a timeline.</summary>
    public enum Doneness
    {
        Raw = 0,
        Cooking = 1,
        Perfect = 2,
        Overcooked = 3,
        Burnt = 4
    }

    /// <summary>A finished component sitting on the assembly counter, with its quality baked in.</summary>
    public readonly struct PreparedComponent : IEquatable<PreparedComponent>
    {
        public readonly ComponentId Id;
        /// <summary>0-100.</summary>
        public readonly int Quality;

        public PreparedComponent(ComponentId id, int quality)
        {
            Id = id;
            Quality = quality < 0 ? 0 : (quality > 100 ? 100 : quality);
        }

        public bool Equals(PreparedComponent other) { return Id == other.Id && Quality == other.Quality; }
        public override bool Equals(object obj) { return obj is PreparedComponent && Equals((PreparedComponent)obj); }
        public override int GetHashCode() { return ((int)Id * 397) ^ Quality; }
        public override string ToString() { return Id + "(" + Quality + ")"; }
    }

    /// <summary>
    /// The timing windows of a single grill, in seconds since the pork went on.
    /// Resolved from upgrade stats; in Phase 1 it comes straight from balance.json.
    /// </summary>
    public readonly struct CookProfile
    {
        public readonly double RawUntil;
        public readonly double PerfectStart;
        public readonly double PerfectEnd;
        public readonly double BurntAt;

        public CookProfile(double rawUntil, double perfectStart, double perfectEnd, double burntAt)
        {
            if (!(rawUntil <= perfectStart && perfectStart < perfectEnd && perfectEnd <= burntAt))
                throw new ArgumentException(
                    "CookProfile windows must be ordered: rawUntil <= perfectStart < perfectEnd <= burntAt. Got " +
                    rawUntil + ", " + perfectStart + ", " + perfectEnd + ", " + burntAt);

            RawUntil = rawUntil;
            PerfectStart = perfectStart;
            PerfectEnd = perfectEnd;
            BurntAt = burntAt;
        }

        public double PerfectWindow { get { return PerfectEnd - PerfectStart; } }

        public Doneness Evaluate(double elapsedSeconds)
        {
            if (elapsedSeconds < RawUntil) return Doneness.Raw;
            if (elapsedSeconds < PerfectStart) return Doneness.Cooking;
            if (elapsedSeconds <= PerfectEnd) return Doneness.Perfect;
            if (elapsedSeconds < BurntAt) return Doneness.Overcooked;
            return Doneness.Burnt;
        }

        /// <summary>
        /// Quality 0-100 for pork removed at <paramref name="elapsedSeconds"/>.
        /// Overcooked degrades linearly so the player feels the cost of being late,
        /// rather than falling off a cliff.
        /// </summary>
        public int QualityAt(double elapsedSeconds, int cookingQuality, int overcookedHigh, int overcookedLow)
        {
            switch (Evaluate(elapsedSeconds))
            {
                case Doneness.Raw:
                    return 0;
                case Doneness.Cooking:
                    return cookingQuality;
                case Doneness.Perfect:
                    return 100;
                case Doneness.Overcooked:
                    double span = BurntAt - PerfectEnd;
                    double t = span <= 0 ? 1.0 : (elapsedSeconds - PerfectEnd) / span;
                    if (t < 0) t = 0; if (t > 1) t = 1;
                    return (int)Math.Round(overcookedHigh + (overcookedLow - overcookedHigh) * t);
                default:
                    return 0;
            }
        }
    }

    /// <summary>A recipe the player can serve.</summary>
    public sealed class RecipeDef
    {
        public string Id;
        public string DisplayNameVi;
        public string DisplayNameEn;
        public ComponentId[] Required;
        public Money Price;
        public Dictionary<ComponentId, double> QualityWeights;
    }

    /// <summary>
    /// The plate being assembled at the counter. Components are added as they finish
    /// cooking; the plate is complete when it holds everything the order requires.
    /// </summary>
    public sealed class Plate
    {
        private readonly List<PreparedComponent> _components = new List<PreparedComponent>(4);

        public IReadOnlyList<PreparedComponent> Components { get { return _components; } }
        public int Count { get { return _components.Count; } }
        public bool IsEmpty { get { return _components.Count == 0; } }

        public void Add(PreparedComponent component) { _components.Add(component); }
        public void Clear() { _components.Clear(); }

        public bool Contains(ComponentId id)
        {
            for (int i = 0; i < _components.Count; i++)
                if (_components[i].Id == id) return true;
            return false;
        }

        /// <summary>True when the plate holds every component the recipe requires.</summary>
        public bool Matches(RecipeDef recipe)
        {
            if (recipe == null || recipe.Required == null) return false;
            for (int i = 0; i < recipe.Required.Length; i++)
                if (!Contains(recipe.Required[i])) return false;
            return true;
        }

        /// <summary>
        /// Weighted plate quality, 0-100 (brief section 13).
        /// Weights are normalised over the components actually present, so a plate
        /// missing an optional component is not silently penalised twice.
        /// </summary>
        public int Quality(RecipeDef recipe)
        {
            if (recipe == null || _components.Count == 0) return 0;

            double weighted = 0.0;
            double totalWeight = 0.0;

            for (int i = 0; i < _components.Count; i++)
            {
                PreparedComponent c = _components[i];
                double w;
                if (recipe.QualityWeights == null || !recipe.QualityWeights.TryGetValue(c.Id, out w))
                    w = 0.0;
                if (w <= 0.0) continue;

                weighted += c.Quality * w;
                totalWeight += w;
            }

            if (totalWeight <= 0.0) return 0;
            int q = (int)Math.Round(weighted / totalWeight);
            return q < 0 ? 0 : (q > 100 ? 100 : q);
        }
    }
}
