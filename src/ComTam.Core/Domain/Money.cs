using System;
using System.Globalization;

namespace ComTam.Core.Domain
{
    /// <summary>
    /// Vietnamese đồng, stored as an exact integer count.
    ///
    /// Deliberately NOT a float. Currency in floating point accumulates rounding
    /// error across thousands of transactions and produces "profit is off by 1đ"
    /// bugs that are miserable to trace. There is no sub-đồng amount in this
    /// game, so a long is both exact and total.
    /// </summary>
    public readonly struct Money : IEquatable<Money>, IComparable<Money>
    {
        public readonly long Dong;

        public Money(long dong)
        {
            Dong = dong;
        }

        public static Money Zero
        {
            get { return new Money(0); }
        }

        public static Money FromDong(long dong)
        {
            return new Money(dong);
        }

        public static Money operator +(Money a, Money b)
        {
            return new Money(a.Dong + b.Dong);
        }

        public static Money operator -(Money a, Money b)
        {
            return new Money(a.Dong - b.Dong);
        }

        public static Money operator -(Money a)
        {
            return new Money(-a.Dong);
        }

        /// <summary>Scales by a multiplier, rounding half away from zero.</summary>
        public static Money operator *(Money a, double multiplier)
        {
            return new Money((long)Math.Round(a.Dong * multiplier, MidpointRounding.AwayFromZero));
        }

        public static Money operator *(Money a, int count)
        {
            return new Money(a.Dong * count);
        }

        public static bool operator ==(Money a, Money b) { return a.Dong == b.Dong; }
        public static bool operator !=(Money a, Money b) { return a.Dong != b.Dong; }
        public static bool operator >(Money a, Money b) { return a.Dong > b.Dong; }
        public static bool operator <(Money a, Money b) { return a.Dong < b.Dong; }
        public static bool operator >=(Money a, Money b) { return a.Dong >= b.Dong; }
        public static bool operator <=(Money a, Money b) { return a.Dong <= b.Dong; }

        public bool Equals(Money other) { return Dong == other.Dong; }
        public override bool Equals(object obj) { return obj is Money && Equals((Money)obj); }
        public override int GetHashCode() { return Dong.GetHashCode(); }
        public int CompareTo(Money other) { return Dong.CompareTo(other.Dong); }

        /// <summary>Player-facing format, e.g. "45,000đ".</summary>
        public string Format()
        {
            return Dong.ToString("N0", CultureInfo.InvariantCulture) + "đ";
        }

        public override string ToString() { return Format(); }
    }
}
