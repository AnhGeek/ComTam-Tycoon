using System.Collections.Generic;
using ComTam.Core.Content;
using ComTam.Core.Domain;
using ComTam.Core.Economy;
using ComTam.Core.Events;
using ComTam.Core.Simulation;
using ComTam.Core.Util;
using NUnit.Framework;

namespace ComTam.Core.Tests
{
    /// <summary>
    /// End-to-end coverage of the Phase 1 loop:
    /// arrive -> order -> cook -> serve -> pay -> leave -> day ends.
    /// </summary>
    [TestFixture]
    public class GameplayLoopTests
    {
        private const double Dt = 0.05;

        private ContentDatabase _db;
        private BalanceConfig _b;
        private EventBus _bus;
        private DaySimulation _sim;

        [SetUp]
        public void SetUp()
        {
            _b = BalanceConfig.Default();
            _db = ContentDatabase.CreatePhase1(_b);
            _bus = new EventBus();
            _sim = new DaySimulation(_db, _bus, new XorShiftRandom(12345),
                                     Money.FromDong(_b.StartingMoneyDong));
            _sim.StartDay(1);
        }

        private void Advance(double seconds)
        {
            int steps = (int)(seconds / Dt);
            for (int i = 0; i < steps; i++) _sim.Tick(Dt);
        }

        /// <summary>Ticks until a customer is ready to be served, or the day ends.</summary>
        private Customer AdvanceToServableCustomer()
        {
            for (int i = 0; i < 20000; i++)
            {
                Customer c = _sim.NextServableCustomer();
                if (c != null) return c;
                if (_sim.State != GameState.RestaurantOpen) return null;
                _sim.Tick(Dt);
            }
            return null;
        }

        // ---------------------------------------------------------------
        // Arrival and queueing
        // ---------------------------------------------------------------

        [Test]
        public void Day_starts_open_with_no_customers()
        {
            Assert.That(_sim.State, Is.EqualTo(GameState.RestaurantOpen));
            Assert.That(_sim.Customers.Count, Is.EqualTo(0));
            Assert.That(_sim.Money.Dong, Is.EqualTo(100000));
        }

        [Test]
        public void First_customer_arrives_and_orders_com_suon()
        {
            Customer c = AdvanceToServableCustomer();
            Assert.That(c, Is.Not.Null);
            Assert.That(c.Order.RecipeId, Is.EqualTo(ContentDatabase.ComSuonId));
            Assert.That(c.State, Is.EqualTo(CustomerState.WaitingForFood));
        }

        [Test]
        public void Queue_never_exceeds_capacity()
        {
            for (int i = 0; i < 4000; i++)
            {
                _sim.Tick(Dt);
                int occupied = 0;
                foreach (Customer c in _sim.Customers)
                    if (c.QueueSlot >= 0) occupied++;
                Assert.That(occupied, Is.LessThanOrEqualTo(_b.QueueCapacity));
            }
        }

        [Test]
        public void Customers_receive_a_name_and_an_archetype()
        {
            Customer c = AdvanceToServableCustomer();
            Assert.That(c.Name, Is.Not.Null.And.Not.Empty);
            Assert.That(c.Archetype, Is.Not.Null);
        }

        // ---------------------------------------------------------------
        // Cooking commands
        // ---------------------------------------------------------------

        [Test]
        public void Rice_can_only_be_scooped_once_per_plate()
        {
            Assert.That(_sim.ScoopRice(), Is.EqualTo(CommandResult.Ok));
            Assert.That(_sim.ScoopRice(), Is.EqualTo(CommandResult.PlateAlreadyHasComponent));
            Assert.That(_sim.Plate.Count, Is.EqualTo(1));
        }

        [Test]
        public void Cannot_place_a_second_chop_on_a_busy_grill()
        {
            Assert.That(_sim.PlacePork(), Is.EqualTo(CommandResult.Ok));
            Assert.That(_sim.PlacePork(), Is.EqualTo(CommandResult.GrillOccupied));
        }

        [Test]
        public void Taking_raw_pork_off_is_refused_and_keeps_it_on_the_grill()
        {
            _sim.PlacePork();
            Advance(1.0);
            Assert.That(_sim.TakePork(), Is.EqualTo(CommandResult.PorkStillRaw));
            Assert.That(_sim.Grill.Occupied, Is.True);
            Assert.That(_sim.Plate.Contains(ComponentId.Pork), Is.False);
        }

        [Test]
        public void Perfect_pork_lands_on_the_plate_at_quality_one_hundred()
        {
            _sim.PlacePork();
            Advance(5.3);
            Assert.That(_sim.TakePork(), Is.EqualTo(CommandResult.Ok));
            Assert.That(_sim.Plate.Contains(ComponentId.Pork), Is.True);
            Assert.That(_sim.Plate.Components[0].Quality, Is.EqualTo(100));
        }

        [Test]
        public void Burning_pork_costs_an_ingredient_and_angers_waiting_customers()
        {
            Customer c = AdvanceToServableCustomer();
            Assert.That(c, Is.Not.Null);
            double before = c.Patience01;

            bool burned = false;
            _bus.Subscribe<PorkBurnedEvent>(_ => burned = true);

            _sim.PlacePork();
            Advance(9.0);

            Assert.That(burned, Is.True);
            Assert.That(_sim.Result.PorkBurned, Is.EqualTo(1));
            Assert.That(_sim.Grill.Occupied, Is.False);
            // Patience fell by more than plain waiting would explain.
            Assert.That(c.Patience01, Is.LessThan(before - 9.0 / c.Archetype.PatienceSeconds));
        }

        // ---------------------------------------------------------------
        // Serving and payment
        // ---------------------------------------------------------------

        [Test]
        public void Cannot_serve_when_nobody_is_waiting()
        {
            Assert.That(_sim.Serve(), Is.EqualTo(CommandResult.NoCustomerToServe));
        }

        [Test]
        public void Cannot_serve_an_incomplete_plate()
        {
            AdvanceToServableCustomer();
            _sim.ScoopRice();
            Assert.That(_sim.Serve(), Is.EqualTo(CommandResult.PlateIncomplete));
        }

        [Test]
        public void Serving_a_perfect_plate_pays_and_clears_the_plate()
        {
            Customer c = AdvanceToServableCustomer();
            Money before = _sim.Money;

            _sim.ScoopRice();
            _sim.PlacePork();
            Advance(5.3);
            _sim.TakePork();

            CustomerServedEvent served = default;
            bool fired = false;
            _bus.Subscribe<CustomerServedEvent>(e => { served = e; fired = true; });

            Assert.That(_sim.Serve(), Is.EqualTo(CommandResult.Ok));

            Assert.That(fired, Is.True);
            Assert.That(served.Stars, Is.GreaterThanOrEqualTo(4));
            Assert.That(served.PlateQuality, Is.EqualTo(96));
            Assert.That(_sim.Money, Is.GreaterThan(before));
            Assert.That(_sim.Plate.IsEmpty, Is.True, "plate must reset after serving");
            Assert.That(c.State, Is.EqualTo(CustomerState.ReceivingFood));
        }

        [Test]
        public void Sauce_is_added_automatically_on_serving()
        {
            AdvanceToServableCustomer();
            _sim.ScoopRice();
            _sim.PlacePork();
            Advance(5.3);
            _sim.TakePork();

            Assert.That(_sim.Plate.Contains(ComponentId.Sauce), Is.False, "not before serving");

            CustomerServedEvent served = default;
            _bus.Subscribe<CustomerServedEvent>(e => served = e);
            _sim.Serve();

            Assert.That(served.PlateQuality, Is.EqualTo(96),
                "96 is only reachable if sauce was included");
        }

        [Test]
        public void Payment_scales_with_the_archetype_spend_multiplier()
        {
            Customer c = AdvanceToServableCustomer();
            _sim.ScoopRice();
            _sim.PlacePork();
            Advance(5.3);
            _sim.TakePork();
            _sim.Serve();

            long expected = (Money.FromDong(_b.ComSuonPriceDong) * c.Archetype.SpendMultiplier).Dong;
            Assert.That(c.Paid.Dong, Is.EqualTo(expected));
        }

        [Test]
        public void Ledger_records_the_sale_and_the_ingredient_cost()
        {
            AdvanceToServableCustomer();
            _sim.ScoopRice();
            _sim.PlacePork();
            Advance(5.3);
            _sim.TakePork();
            _sim.Serve();

            DayResult r = _sim.Result;
            Assert.That(r.CustomersServed, Is.EqualTo(1));
            Assert.That(r.Revenue.Dong, Is.GreaterThan(0));
            Assert.That(r.IngredientCost.Dong, Is.EqualTo(16000)); // 3000 + 12000 + 1000
            Assert.That(r.BestCustomerName, Is.Not.Null);
        }

        [Test]
        public void Slow_service_scores_fewer_stars_than_fast_service()
        {
            // Fast
            AdvanceToServableCustomer();
            _sim.ScoopRice();
            _sim.PlacePork();
            Advance(5.3);
            _sim.TakePork();
            int fastStars = 0;
            _bus.Subscribe<CustomerServedEvent>(e => fastStars = e.Stars);
            _sim.Serve();

            // Slow: a fresh sim, but dawdle before serving.
            EventBus bus2 = new EventBus();
            DaySimulation slow = new DaySimulation(_db, bus2, new XorShiftRandom(12345),
                                                   Money.FromDong(_b.StartingMoneyDong));
            slow.StartDay(1);
            Customer c2 = null;
            for (int i = 0; i < 20000 && c2 == null; i++) { slow.Tick(Dt); c2 = slow.NextServableCustomer(); }
            for (int i = 0; i < (int)(20.0 / Dt); i++) slow.Tick(Dt); // let patience drain
            slow.ScoopRice();
            slow.PlacePork();
            for (int i = 0; i < (int)(5.3 / Dt); i++) slow.Tick(Dt);
            slow.TakePork();
            int slowStars = 0;
            bus2.Subscribe<CustomerServedEvent>(e => slowStars = e.Stars);
            slow.Serve();

            Assert.That(slowStars, Is.LessThanOrEqualTo(fastStars));
        }

        // ---------------------------------------------------------------
        // Patience
        // ---------------------------------------------------------------

        [Test]
        public void An_ignored_customer_eventually_leaves_angry()
        {
            Customer c = AdvanceToServableCustomer();
            Assert.That(c, Is.Not.Null);

            bool left = false;
            _bus.Subscribe<CustomerLeftAngryEvent>(_ => left = true);

            Advance(c.Archetype.PatienceSeconds + 2.0);

            Assert.That(left, Is.True);
            Assert.That(_sim.Result.CustomersLostAngry, Is.GreaterThanOrEqualTo(1));
            Assert.That(c.QueueSlot, Is.EqualTo(-1), "their slot must be freed");
        }

        [Test]
        public void Patience_only_drains_while_waiting_for_food()
        {
            Customer c = AdvanceToServableCustomer();
            _sim.ScoopRice();
            _sim.PlacePork();
            Advance(5.3);
            _sim.TakePork();
            _sim.Serve();

            double afterServing = c.Patience01;
            Advance(2.0);
            Assert.That(c.Patience01, Is.EqualTo(afterServing),
                "a served customer's patience must stop draining");
        }

        [Test]
        public void Mood_bands_follow_the_patience_meter()
        {
            Customer c = new Customer { Patience01 = 1.0 };
            Assert.That(c.Mood, Is.EqualTo(CustomerMood.Happy));
            c.Patience01 = 0.65; Assert.That(c.Mood, Is.EqualTo(CustomerMood.Normal));
            c.Patience01 = 0.35; Assert.That(c.Mood, Is.EqualTo(CustomerMood.Impatient));
            c.Patience01 = 0.10; Assert.That(c.Mood, Is.EqualTo(CustomerMood.Angry));
        }

        // ---------------------------------------------------------------
        // Day completion
        // ---------------------------------------------------------------

        [Test]
        public void Day_ends_and_reaches_the_results_state()
        {
            bool ended = false;
            DayResult result = null;
            _bus.Subscribe<DayEndedEvent>(e => { ended = true; result = e.Result; });

            for (int i = 0; i < 20000 && _sim.State == GameState.RestaurantOpen; i++)
                _sim.Tick(Dt);

            Assert.That(ended, Is.True, "the day must end on its own");
            Assert.That(_sim.State, Is.EqualTo(GameState.DailyResults));
            Assert.That(result, Is.Not.Null);
            Assert.That(result.Day, Is.EqualTo(1));
        }

        [Test]
        public void No_new_customers_arrive_after_the_service_window_closes()
        {
            for (int i = 0; i < 20000 && !_sim.ServiceWindowClosed; i++) _sim.Tick(Dt);
            int atClose = _sim.Customers.Count;
            for (int i = 0; i < 400 && _sim.State == GameState.RestaurantOpen; i++) _sim.Tick(Dt);
            Assert.That(_sim.Customers.Count, Is.EqualTo(atClose));
        }

        [Test]
        public void Commands_are_refused_once_the_day_is_over()
        {
            _sim.ForceCloseDay();
            Assert.That(_sim.State, Is.EqualTo(GameState.DailyResults));
            Assert.That(_sim.ScoopRice(), Is.EqualTo(CommandResult.WrongState));
            Assert.That(_sim.PlacePork(), Is.EqualTo(CommandResult.WrongState));
            Assert.That(_sim.Serve(), Is.EqualTo(CommandResult.WrongState));
        }

        [Test]
        public void Meeting_the_goal_pays_the_bonus()
        {
            int served = 0;
            for (int i = 0; i < 40000 && _sim.State == GameState.RestaurantOpen; i++)
            {
                Customer c = _sim.NextServableCustomer();
                if (c != null && !_sim.Grill.Occupied && _sim.Plate.IsEmpty)
                {
                    _sim.ScoopRice();
                    _sim.PlacePork();
                }
                if (_sim.Grill.Occupied && _sim.Grill.CurrentDoneness == Doneness.Perfect)
                {
                    _sim.TakePork();
                    if (_sim.Serve() == CommandResult.Ok) served++;
                }
                _sim.Tick(Dt);
            }

            DayResult r = _sim.Result;
            Assert.That(served, Is.GreaterThanOrEqualTo(_b.Day1GoalCustomers),
                "a competent player should clear the day 1 goal");
            Assert.That(r.GoalMet, Is.True);
            Assert.That(r.GoalBonus.Dong, Is.EqualTo(_b.Day1GoalBonusDong));
            Assert.That(r.Profit.Dong, Is.GreaterThan(0));
        }

        // ---------------------------------------------------------------
        // Determinism
        // ---------------------------------------------------------------

        [Test]
        public void Same_seed_produces_an_identical_day()
        {
            List<string> RunOnce(int seed)
            {
                List<string> log = new List<string>();
                EventBus bus = new EventBus();
                DaySimulation sim = new DaySimulation(_db, bus, new XorShiftRandom(seed),
                                                      Money.FromDong(_b.StartingMoneyDong));
                bus.Subscribe<CustomerArrivedEvent>(e =>
                    log.Add("arrive:" + e.Customer.Id + ":" + e.Customer.Archetype.Id + ":" + e.Customer.Name));
                sim.StartDay(1);
                for (int i = 0; i < 20000 && sim.State == GameState.RestaurantOpen; i++) sim.Tick(Dt);
                log.Add("money:" + sim.Money.Dong);
                return log;
            }

            Assert.That(RunOnce(999), Is.EqualTo(RunOnce(999)),
                "the same seed must replay exactly - this is what makes bugs reproducible");
            Assert.That(RunOnce(999), Is.Not.EqualTo(RunOnce(1000)));
        }
    }

    [TestFixture]
    public class GameStateMachineTests
    {
        [Test]
        public void Legal_transitions_are_allowed()
        {
            GameStateMachine fsm = new GameStateMachine(GameState.Preparation);
            Assert.That(fsm.TransitionTo(GameState.RestaurantOpen), Is.True);
            Assert.That(fsm.TransitionTo(GameState.RestaurantClosed), Is.True);
            Assert.That(fsm.TransitionTo(GameState.DailyResults), Is.True);
            Assert.That(fsm.TransitionTo(GameState.Preparation), Is.True);
        }

        [Test]
        public void Illegal_transitions_are_refused_and_reported()
        {
            GameStateMachine fsm = new GameStateMachine(GameState.MainMenu);
            Assert.That(fsm.TransitionTo(GameState.RestaurantOpen), Is.False);
            Assert.That(fsm.Current, Is.EqualTo(GameState.MainMenu));
            Assert.That(fsm.LastRejection, Is.Not.Null,
                "a refused transition must say so, not fail silently");
        }
    }
}
