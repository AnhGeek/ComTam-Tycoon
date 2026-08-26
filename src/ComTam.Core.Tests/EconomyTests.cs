using ComTam.Core.Content;
using ComTam.Core.Domain;
using ComTam.Core.Economy;
using ComTam.Core.Util;
using NUnit.Framework;

namespace ComTam.Core.Tests
{
    [TestFixture]
    public class MoneyTests
    {
        [Test]
        public void Formats_with_thousands_separators_and_dong_sign()
        {
            Assert.That(Money.FromDong(45000).Format(), Is.EqualTo("45,000đ"));
            Assert.That(Money.FromDong(0).Format(), Is.EqualTo("0đ"));
            Assert.That(Money.FromDong(1234567).Format(), Is.EqualTo("1,234,567đ"));
        }

        [Test]
        public void Arithmetic_is_exact()
        {
            Money a = Money.FromDong(45000);
            Money b = Money.FromDong(12000);
            Assert.That((a + b).Dong, Is.EqualTo(57000));
            Assert.That((a - b).Dong, Is.EqualTo(33000));
            Assert.That((a * 3).Dong, Is.EqualTo(135000));
        }

        [Test]
        public void Multiplication_rounds_half_away_from_zero()
        {
            Assert.That((Money.FromDong(45000) * 0.05).Dong, Is.EqualTo(2250));
            Assert.That((Money.FromDong(45000) * 1.2).Dong, Is.EqualTo(54000));
            Assert.That((Money.FromDong(45000) * 0.9).Dong, Is.EqualTo(40500));
            Assert.That((Money.FromDong(5) * 0.5).Dong, Is.EqualTo(3));
        }

        [Test]
        public void Thousands_of_transactions_do_not_drift()
        {
            // The reason Money is a long and not a double.
            Money total = Money.Zero;
            for (int i = 0; i < 100000; i++) total += Money.FromDong(45000) * 0.05;
            Assert.That(total.Dong, Is.EqualTo(2250L * 100000));
        }

        [Test]
        public void Comparisons_work()
        {
            Assert.That(Money.FromDong(100) > Money.FromDong(99), Is.True);
            Assert.That(Money.FromDong(100) == Money.FromDong(100), Is.True);
            Assert.That(Money.FromDong(100).Equals(Money.FromDong(100)), Is.True);
        }
    }

    [TestFixture]
    public class PlateQualityTests
    {
        private ContentDatabase _db;

        [SetUp]
        public void SetUp() { _db = ContentDatabase.CreatePhase1(BalanceConfig.Default()); }

        [Test]
        public void Empty_plate_scores_zero()
        {
            Assert.That(new Plate().Quality(_db.ComSuon), Is.EqualTo(0));
        }

        [Test]
        public void Perfect_com_suon_scores_ninety_six()
        {
            // Rice 85 (w .20), Pork 100 (w .40), Sauce 100 (w .20).
            // Egg is absent, so weights normalise over 0.80:
            // (85*.2 + 100*.4 + 100*.2) / .8 = 77 / .8 = 96.25 -> 96
            Plate p = new Plate();
            p.Add(new PreparedComponent(ComponentId.Rice, 85));
            p.Add(new PreparedComponent(ComponentId.Pork, 100));
            p.Add(new PreparedComponent(ComponentId.Sauce, 100));
            Assert.That(p.Quality(_db.ComSuon), Is.EqualTo(96));
        }

        [Test]
        public void Undercooked_pork_drags_the_plate_down_hard()
        {
            Plate p = new Plate();
            p.Add(new PreparedComponent(ComponentId.Rice, 85));
            p.Add(new PreparedComponent(ComponentId.Pork, 50));
            p.Add(new PreparedComponent(ComponentId.Sauce, 100));
            // (17 + 20 + 20) / .8 = 71.25 -> 71
            Assert.That(p.Quality(_db.ComSuon), Is.EqualTo(71));
        }

        [Test]
        public void Pork_carries_the_most_weight()
        {
            Plate goodPork = new Plate();
            goodPork.Add(new PreparedComponent(ComponentId.Rice, 0));
            goodPork.Add(new PreparedComponent(ComponentId.Pork, 100));
            goodPork.Add(new PreparedComponent(ComponentId.Sauce, 0));

            Plate goodRest = new Plate();
            goodRest.Add(new PreparedComponent(ComponentId.Rice, 100));
            goodRest.Add(new PreparedComponent(ComponentId.Pork, 0));
            goodRest.Add(new PreparedComponent(ComponentId.Sauce, 100));

            Assert.That(goodPork.Quality(_db.ComSuon), Is.EqualTo(goodRest.Quality(_db.ComSuon)),
                "pork at .40 should exactly balance rice+sauce at .20+.20");
        }

        [Test]
        public void Matches_requires_every_component()
        {
            Plate p = new Plate();
            p.Add(new PreparedComponent(ComponentId.Rice, 85));
            p.Add(new PreparedComponent(ComponentId.Pork, 100));
            Assert.That(p.Matches(_db.ComSuon), Is.False, "sauce missing");
            p.Add(new PreparedComponent(ComponentId.Sauce, 100));
            Assert.That(p.Matches(_db.ComSuon), Is.True);
        }

        [Test]
        public void Quality_is_clamped_to_zero_hundred()
        {
            Assert.That(new PreparedComponent(ComponentId.Rice, 500).Quality, Is.EqualTo(100));
            Assert.That(new PreparedComponent(ComponentId.Rice, -20).Quality, Is.EqualTo(0));
        }
    }

    [TestFixture]
    public class SatisfactionTests
    {
        private BalanceConfig _b;

        [SetUp]
        public void SetUp() { _b = BalanceConfig.Default(); }

        [Test]
        public void Instant_service_with_a_perfect_plate_is_five_stars()
        {
            SatisfactionResult r = SatisfactionCalculator.Evaluate(_b, 1.0, 100, true);
            Assert.That(r.Score, Is.EqualTo(100));
            Assert.That(r.Stars, Is.EqualTo(5));
        }

        [Test]
        public void Out_of_patience_with_a_bad_plate_is_one_star()
        {
            SatisfactionResult r = SatisfactionCalculator.Evaluate(_b, 0.0, 0, false);
            Assert.That(r.Score, Is.EqualTo(10)); // price weight only
            Assert.That(r.Stars, Is.EqualTo(1));
        }

        [Test]
        public void Wrong_order_costs_the_full_accuracy_weight()
        {
            SatisfactionResult accurate = SatisfactionCalculator.Evaluate(_b, 1.0, 100, true);
            SatisfactionResult wrong = SatisfactionCalculator.Evaluate(_b, 1.0, 100, false);
            Assert.That(accurate.Score - wrong.Score, Is.EqualTo(20));
        }

        [Test]
        public void Stars_never_leave_the_one_to_five_range()
        {
            for (int score = 0; score <= 100; score++)
            {
                int stars = SatisfactionCalculator.StarsFromScore(score);
                Assert.That(stars, Is.InRange(1, 5), "score " + score);
            }
        }

        [Test]
        public void Weights_sum_to_one_hundred()
        {
            Assert.That(_b.SatWaitWeight + _b.SatQualityWeight
                        + _b.SatAccuracyWeight + _b.SatPriceWeight,
                        Is.EqualTo(100.0).Within(1e-9));
        }

        [Test]
        public void Three_star_service_never_tips()
        {
            CustomerArchetypeDef always = new CustomerArchetypeDef { TipChance = 1.0 };
            Money tip = SatisfactionCalculator.CalculateTip(
                _b, always, 3, Money.FromDong(45000), new XorShiftRandom(1));
            Assert.That(tip, Is.EqualTo(Money.Zero));
        }

        [Test]
        public void Five_star_tips_ten_percent_four_star_tips_five()
        {
            CustomerArchetypeDef always = new CustomerArchetypeDef { TipChance = 1.0 };
            Assert.That(SatisfactionCalculator.CalculateTip(
                _b, always, 4, Money.FromDong(45000), new XorShiftRandom(1)).Dong, Is.EqualTo(2250));
            Assert.That(SatisfactionCalculator.CalculateTip(
                _b, always, 5, Money.FromDong(45000), new XorShiftRandom(1)).Dong, Is.EqualTo(4500));
        }

        [Test]
        public void Zero_tip_chance_never_tips()
        {
            CustomerArchetypeDef never = new CustomerArchetypeDef { TipChance = 0.0 };
            for (int seed = 0; seed < 50; seed++)
            {
                Assert.That(SatisfactionCalculator.CalculateTip(
                    _b, never, 5, Money.FromDong(45000), new XorShiftRandom(seed)),
                    Is.EqualTo(Money.Zero));
            }
        }
    }
}
