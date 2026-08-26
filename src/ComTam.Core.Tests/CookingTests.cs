using ComTam.Core.Content;
using ComTam.Core.Domain;
using ComTam.Core.Simulation;
using NUnit.Framework;

namespace ComTam.Core.Tests
{
    [TestFixture]
    public class CookProfileTests
    {
        // Grill level 1: raw <3.0, cooking <4.6, perfect 4.6-6.0, overcooked <8.0, burnt >=8.0
        private static CookProfile Profile() { return new CookProfile(3.0, 4.6, 6.0, 8.0); }

        [TestCase(0.0, Doneness.Raw)]
        [TestCase(2.999, Doneness.Raw)]
        [TestCase(3.0, Doneness.Cooking)]
        [TestCase(4.599, Doneness.Cooking)]
        [TestCase(4.6, Doneness.Perfect)]
        [TestCase(5.3, Doneness.Perfect)]
        [TestCase(6.0, Doneness.Perfect)]
        [TestCase(6.001, Doneness.Overcooked)]
        [TestCase(7.999, Doneness.Overcooked)]
        [TestCase(8.0, Doneness.Burnt)]
        [TestCase(20.0, Doneness.Burnt)]
        public void Evaluate_returns_expected_state_at_boundaries(double t, Doneness expected)
        {
            Assert.That(Profile().Evaluate(t), Is.EqualTo(expected));
        }

        [Test]
        public void Perfect_window_is_one_point_four_seconds()
        {
            Assert.That(Profile().PerfectWindow, Is.EqualTo(1.4).Within(1e-9));
        }

        [Test]
        public void Perfect_tap_scores_one_hundred()
        {
            Assert.That(Profile().QualityAt(5.3, 50, 70, 35), Is.EqualTo(100));
        }

        [Test]
        public void Undercooked_tap_scores_the_cooking_quality()
        {
            Assert.That(Profile().QualityAt(4.0, 50, 70, 35), Is.EqualTo(50));
        }

        [Test]
        public void Overcooked_degrades_linearly_from_high_to_low()
        {
            CookProfile p = Profile();
            // Overcooked spans 6.0 -> 8.0, so 7.0 is the midpoint of 70 -> 35.
            Assert.That(p.QualityAt(6.0001, 50, 70, 35), Is.EqualTo(70).Within(1));
            Assert.That(p.QualityAt(7.0, 50, 70, 35), Is.EqualTo(53).Within(1));
            Assert.That(p.QualityAt(7.999, 50, 70, 35), Is.EqualTo(35).Within(1));
        }

        [Test]
        public void Burnt_scores_zero()
        {
            Assert.That(Profile().QualityAt(9.0, 50, 70, 35), Is.EqualTo(0));
        }

        [Test]
        public void Constructor_rejects_out_of_order_windows()
        {
            Assert.Throws<System.ArgumentException>(() => new CookProfile(5.0, 4.0, 6.0, 8.0));
            Assert.Throws<System.ArgumentException>(() => new CookProfile(1.0, 4.0, 4.0, 8.0));
        }
    }

    [TestFixture]
    public class CookStationTests
    {
        private static CookStation Station()
        {
            return new CookStation(new CookProfile(3.0, 4.6, 6.0, 8.0), 0.08, 50, 70, 35);
        }

        private static void Advance(CookStation s, double seconds)
        {
            // 20 Hz, matching the host tick rate.
            for (int i = 0; i < (int)(seconds / 0.05); i++) s.Tick(0.05);
        }

        [Test]
        public void Cannot_take_off_an_empty_grill()
        {
            Assert.That(Station().TakeOff(), Is.EqualTo(TakeOffOutcome.Empty));
        }

        [Test]
        public void Cannot_place_twice()
        {
            CookStation s = Station();
            Assert.That(s.Place(), Is.True);
            Assert.That(s.Place(), Is.False);
        }

        [Test]
        public void Raw_pork_cannot_be_taken_off()
        {
            CookStation s = Station();
            s.Place();
            Advance(s, 1.0);
            Assert.That(s.TakeOff(), Is.EqualTo(TakeOffOutcome.StillRaw));
            Assert.That(s.Occupied, Is.True, "a refused tap must not clear the grill");
        }

        [Test]
        public void Perfect_tap_yields_quality_one_hundred()
        {
            CookStation s = Station();
            s.Place();
            Advance(s, 5.3);
            Assert.That(s.TakeOff(), Is.EqualTo(TakeOffOutcome.Removed));
            Assert.That(s.LastDoneness, Is.EqualTo(Doneness.Perfect));
            Assert.That(s.LastQuality, Is.EqualTo(100));
            Assert.That(s.Occupied, Is.False);
        }

        [Test]
        public void Late_tap_within_grace_still_counts_as_perfect()
        {
            CookStation s = Station();
            s.Place();
            Advance(s, 6.05); // 0.05s past the window, inside the 0.08s grace
            Assert.That(s.TakeOff(), Is.EqualTo(TakeOffOutcome.Removed));
            Assert.That(s.LastDoneness, Is.EqualTo(Doneness.Perfect),
                "near-misses inside the grace window must feel generous");
        }

        [Test]
        public void Late_tap_beyond_grace_is_overcooked()
        {
            CookStation s = Station();
            s.Place();
            Advance(s, 6.5);
            s.TakeOff();
            Assert.That(s.LastDoneness, Is.EqualTo(Doneness.Overcooked));
            Assert.That(s.LastQuality, Is.LessThan(100));
        }

        [Test]
        public void Pork_burns_exactly_once_and_clears_the_grill()
        {
            CookStation s = Station();
            s.Place();

            int burnEvents = 0;
            for (int i = 0; i < 400; i++)
                if (s.Tick(0.05)) burnEvents++;

            Assert.That(burnEvents, Is.EqualTo(1), "burn must fire once, not every tick");
            Assert.That(s.Occupied, Is.False, "burnt pork is discarded");
        }

        [Test]
        public void Grill_can_be_reused_after_burning()
        {
            CookStation s = Station();
            s.Place();
            Advance(s, 9.0);
            Assert.That(s.Occupied, Is.False);
            Assert.That(s.Place(), Is.True);
        }
    }
}
