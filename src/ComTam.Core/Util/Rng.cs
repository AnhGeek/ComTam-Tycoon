using System;

namespace ComTam.Core.Util
{
    /// <summary>
    /// Injected randomness. Every random draw in the simulation goes through this
    /// so a day can be replayed exactly from its seed - which is what makes the
    /// customer AI debuggable and the balance testable (brief section 32).
    /// </summary>
    public interface IRandom
    {
        /// <summary>Uniform in [0, 1).</summary>
        double NextDouble();
        /// <summary>Uniform integer in [minInclusive, maxExclusive).</summary>
        int Range(int minInclusive, int maxExclusive);
        /// <summary>True with probability <paramref name="probability"/>.</summary>
        bool Chance(double probability);
    }

    /// <summary>
    /// xorshift128+. Small, fast, deterministic across platforms, and - unlike
    /// System.Random - guaranteed to produce identical sequences on every runtime
    /// and every .NET version. That guarantee is the whole point.
    /// </summary>
    public sealed class XorShiftRandom : IRandom
    {
        private ulong _s0;
        private ulong _s1;

        public XorShiftRandom(int seed) : this((ulong)seed, 0x9E3779B97F4A7C15UL) { }

        public XorShiftRandom(ulong s0, ulong s1)
        {
            // splitmix64 both seed words so that low-entropy seeds (0, 1, 2)
            // still produce well-distributed streams.
            ulong mix = s0 ^ (s1 * 0xD1B54A32D192ED03UL);
            _s0 = SplitMix64(ref mix);
            _s1 = SplitMix64(ref mix);
            if (_s0 == 0 && _s1 == 0) _s1 = 1; // all-zero state is a fixed point
        }

        private static ulong SplitMix64(ref ulong x)
        {
            x += 0x9E3779B97F4A7C15UL;
            ulong z = x;
            z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL;
            z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL;
            return z ^ (z >> 31);
        }

        private ulong NextUInt64()
        {
            ulong x = _s0;
            ulong y = _s1;
            _s0 = y;
            x ^= x << 23;
            _s1 = x ^ y ^ (x >> 17) ^ (y >> 26);
            return _s1 + y;
        }

        public double NextDouble()
        {
            // 53 significant bits -> exactly representable in a double.
            return (NextUInt64() >> 11) * (1.0 / 9007199254740992.0);
        }

        public int Range(int minInclusive, int maxExclusive)
        {
            if (maxExclusive <= minInclusive) return minInclusive;
            long span = (long)maxExclusive - minInclusive;
            return (int)(minInclusive + (long)(NextDouble() * span));
        }

        public bool Chance(double probability)
        {
            if (probability <= 0.0) return false;
            if (probability >= 1.0) return true;
            return NextDouble() < probability;
        }
    }

    public static class MathX
    {
        public static double Clamp01(double v) { return v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v); }

        public static double Clamp(double v, double min, double max)
        {
            return v < min ? min : (v > max ? max : v);
        }

        public static int ClampInt(int v, int min, int max)
        {
            return v < min ? min : (v > max ? max : v);
        }

        public static double Lerp(double a, double b, double t) { return a + (b - a) * Clamp01(t); }
    }
}
