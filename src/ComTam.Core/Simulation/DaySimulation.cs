using System;
using System.Collections.Generic;
using ComTam.Core.Content;
using ComTam.Core.Domain;
using ComTam.Core.Economy;
using ComTam.Core.Events;
using ComTam.Core.Util;

namespace ComTam.Core.Simulation
{
    /// <summary>Why a player command was refused. The UI turns these into feedback.</summary>
    public enum CommandResult
    {
        Ok = 0,
        WrongState = 1,
        GrillOccupied = 2,
        GrillEmpty = 3,
        PorkStillRaw = 4,
        PlateAlreadyHasComponent = 5,
        NoCustomerToServe = 6,
        PlateIncomplete = 7
    }

    /// <summary>
    /// The whole Phase 1 game: one day at the cart, from open to close.
    ///
    /// Stepped at a fixed timestep by the presentation layer. Contains no
    /// rendering, no engine types, and no wall-clock reads - every random draw
    /// goes through the injected IRandom, so a day replays exactly from its seed.
    /// </summary>
    public sealed class DaySimulation
    {
        private readonly ContentDatabase _content;
        private readonly BalanceConfig _balance;
        private readonly EventBus _bus;
        private readonly IRandom _rng;
        private readonly GameStateMachine _fsm;

        private readonly List<Customer> _customers = new List<Customer>();
        private readonly Customer[] _queueSlots;
        private readonly Plate _plate = new Plate();
        private readonly CookStation _grill;

        private int _nextCustomerId = 1;
        private int _spawnedCount;
        private int _customersToSpawn;
        private double _nextSpawnAt;

        public int Day { get; private set; }
        public Money Money { get; private set; }
        public double Elapsed { get; private set; }
        public DayResult Result { get; private set; }

        public GameState State { get { return _fsm.Current; } }
        public Plate Plate { get { return _plate; } }
        public CookStation Grill { get { return _grill; } }
        public IReadOnlyList<Customer> Customers { get { return _customers; } }
        public double DayLength { get { return _balance.DayLengthSeconds; } }

        public double TimeRemaining
        {
            get
            {
                double r = _balance.DayLengthSeconds - Elapsed;
                return r < 0.0 ? 0.0 : r;
            }
        }

        /// <summary>True once the service window has closed; stragglers still play out.</summary>
        public bool ServiceWindowClosed { get { return Elapsed >= _balance.DayLengthSeconds; } }

        public DaySimulation(ContentDatabase content, EventBus bus, IRandom rng, Money startingMoney)
        {
            if (content == null) throw new ArgumentNullException("content");
            _content = content;
            _balance = content.Balance;
            _bus = bus ?? new EventBus();
            _rng = rng ?? new XorShiftRandom(0);
            _fsm = new GameStateMachine(GameState.Preparation);
            _queueSlots = new Customer[_balance.QueueCapacity];
            Money = startingMoney;

            _grill = new CookStation(
                content.GrillProfile(),
                _balance.GrillGraceSeconds,
                _balance.PorkCookingQuality,
                _balance.PorkOvercookedHighQuality,
                _balance.PorkOvercookedLowQuality);
        }

        // ------------------------------------------------------------------
        // Day lifecycle
        // ------------------------------------------------------------------

        public bool StartDay(int day)
        {
            if (!_fsm.TransitionTo(GameState.RestaurantOpen)) return false;

            Day = day;
            Elapsed = 0.0;
            _customers.Clear();
            Array.Clear(_queueSlots, 0, _queueSlots.Length);
            _plate.Clear();
            _grill.Reset();
            _nextCustomerId = 1;
            _spawnedCount = 0;
            _customersToSpawn = _balance.CustomersOnDay1;
            _nextSpawnAt = _balance.FirstSpawnDelaySeconds;

            Result = new DayResult { Day = day };

            _bus.Publish(new DayStartedEvent { Day = day });
            return true;
        }

        /// <summary>Fixed-step tick. dt is seconds; the host uses 0.05 (20 Hz).</summary>
        public void Tick(double dt)
        {
            if (_fsm.Current != GameState.RestaurantOpen) return;
            if (dt <= 0.0) return;

            Elapsed += dt;

            TickSpawning();
            TickGrill(dt);
            TickCustomers(dt);

            if (ShouldCloseDay()) CloseDay();
        }

        private void TickSpawning()
        {
            if (ServiceWindowClosed) return;              // window shut: no new arrivals
            if (_spawnedCount >= _customersToSpawn) return;
            if (Elapsed < _nextSpawnAt) return;
            if (FreeQueueSlot() < 0) return;              // queue full: they walk on by

            SpawnCustomer();

            double jitter = (_rng.NextDouble() * 2.0 - 1.0) * _balance.SpawnJitterSeconds;
            _nextSpawnAt = Elapsed + _balance.SpawnIntervalSeconds + jitter;
        }

        private void SpawnCustomer()
        {
            int slot = FreeQueueSlot();
            if (slot < 0) return;

            CustomerArchetypeDef archetype = _content.Archetypes[_rng.Range(0, _content.Archetypes.Count)];
            string name = _content.NamePool[_rng.Range(0, _content.NamePool.Count)];

            Customer c = new Customer
            {
                Id = _nextCustomerId++,
                Archetype = archetype,
                Name = name,
                Order = new Order(_content.ComSuon),
                QueueSlot = slot,
                Patience01 = 1.0
            };
            c.SetState(CustomerState.WalkingToQueue);

            _queueSlots[slot] = c;
            _customers.Add(c);
            _spawnedCount++;

            _bus.Publish(new CustomerArrivedEvent { Customer = c });
        }

        private int FreeQueueSlot()
        {
            for (int i = 0; i < _queueSlots.Length; i++)
                if (_queueSlots[i] == null) return i;
            return -1;
        }

        private void TickGrill(double dt)
        {
            if (!_grill.Tick(dt)) return;

            // Burnt: the chop is gone and everyone waiting notices the smoke.
            Result.RecordBurn(Money.FromDong(_balance.PorkCostDong));
            for (int i = 0; i < _customers.Count; i++)
            {
                Customer c = _customers[i];
                if (c.IsWaiting) c.PenalisePatience(_balance.BurnPatiencePenalty);
            }
            _bus.Publish(new PorkBurnedEvent());
        }

        private void TickCustomers(double dt)
        {
            for (int i = 0; i < _customers.Count; i++)
            {
                Customer c = _customers[i];
                if (c.State == CustomerState.Done) continue;

                c.StateElapsed += dt;

                switch (c.State)
                {
                    case CustomerState.WalkingToQueue:
                        if (c.StateElapsed >= _balance.WalkToQueueSeconds)
                            c.SetState(CustomerState.Ordering);
                        break;

                    case CustomerState.Ordering:
                        if (c.StateElapsed >= _balance.OrderingSeconds)
                        {
                            c.SetState(CustomerState.WaitingForFood);
                            _bus.Publish(new CustomerOrderedEvent { Customer = c });
                        }
                        break;

                    case CustomerState.WaitingForFood:
                        c.TotalWaitSeconds += dt;
                        c.Patience01 = MathX.Clamp01(
                            c.Patience01 - dt / c.Archetype.PatienceSeconds);
                        if (c.Patience01 <= 0.0) LeaveAngry(c);
                        break;

                    case CustomerState.ReceivingFood:
                        if (c.StateElapsed >= _balance.ReceivingFoodSeconds)
                            c.SetState(CustomerState.Eating);
                        break;

                    case CustomerState.Eating:
                        if (c.StateElapsed >= _balance.EatingSeconds)
                        {
                            c.SetState(CustomerState.Leaving);
                            FreeSlot(c);
                        }
                        break;

                    case CustomerState.LeftAngry:
                    case CustomerState.Leaving:
                        if (c.StateElapsed >= _balance.LeavingSeconds)
                        {
                            c.SetState(CustomerState.Done);
                            _bus.Publish(new CustomerFinishedEvent { Customer = c });
                        }
                        break;
                }
            }
        }

        private void LeaveAngry(Customer c)
        {
            c.SetState(CustomerState.LeftAngry);
            FreeSlot(c);
            Result.RecordAngryDeparture();
            _bus.Publish(new CustomerLeftAngryEvent { Customer = c });
        }

        private void FreeSlot(Customer c)
        {
            if (c.QueueSlot >= 0 && c.QueueSlot < _queueSlots.Length
                && _queueSlots[c.QueueSlot] == c)
            {
                _queueSlots[c.QueueSlot] = null;
            }
            c.QueueSlot = -1;
        }

        private bool ShouldCloseDay()
        {
            if (!ServiceWindowClosed) return false;
            if (_spawnedCount < _customersToSpawn) return true; // window shut before all arrived

            for (int i = 0; i < _customers.Count; i++)
                if (_customers[i].State != CustomerState.Done) return false;

            return true;
        }

        private void CloseDay()
        {
            Result.FinaliseGoal(_balance.Day1GoalCustomers, Money.FromDong(_balance.Day1GoalBonusDong));
            Money += Result.GoalBonus;

            _fsm.TransitionTo(GameState.RestaurantClosed);
            _fsm.TransitionTo(GameState.DailyResults);
            _bus.Publish(new DayEndedEvent { Result = Result });
        }

        /// <summary>Ends the day early. Used by the harness and by tests.</summary>
        public void ForceCloseDay()
        {
            if (_fsm.Current != GameState.RestaurantOpen) return;
            Elapsed = _balance.DayLengthSeconds;
            for (int i = 0; i < _customers.Count; i++)
                _customers[i].SetState(CustomerState.Done);
            CloseDay();
        }

        // ------------------------------------------------------------------
        // Player commands
        // ------------------------------------------------------------------

        public CommandResult ScoopRice()
        {
            if (_fsm.Current != GameState.RestaurantOpen) return CommandResult.WrongState;
            if (_plate.Contains(ComponentId.Rice)) return CommandResult.PlateAlreadyHasComponent;

            _plate.Add(new PreparedComponent(ComponentId.Rice, _balance.RiceQuality));
            _bus.Publish(new RiceScoopedEvent { Quality = _balance.RiceQuality });
            _bus.Publish(new PlateComponentAddedEvent
            {
                Component = ComponentId.Rice,
                Quality = _balance.RiceQuality
            });
            PublishPlateReadyIfComplete();
            return CommandResult.Ok;
        }

        public CommandResult PlacePork()
        {
            if (_fsm.Current != GameState.RestaurantOpen) return CommandResult.WrongState;
            if (_plate.Contains(ComponentId.Pork)) return CommandResult.PlateAlreadyHasComponent;
            if (!_grill.Place()) return CommandResult.GrillOccupied;

            _bus.Publish(new PorkPlacedOnGrillEvent());
            return CommandResult.Ok;
        }

        public CommandResult TakePork()
        {
            if (_fsm.Current != GameState.RestaurantOpen) return CommandResult.WrongState;

            TakeOffOutcome outcome = _grill.TakeOff();
            if (outcome == TakeOffOutcome.Empty) return CommandResult.GrillEmpty;
            if (outcome == TakeOffOutcome.StillRaw) return CommandResult.PorkStillRaw;

            _plate.Add(new PreparedComponent(ComponentId.Pork, _grill.LastQuality));
            _bus.Publish(new PorkCookedEvent
            {
                Doneness = _grill.LastDoneness,
                Quality = _grill.LastQuality
            });
            _bus.Publish(new PlateComponentAddedEvent
            {
                Component = ComponentId.Pork,
                Quality = _grill.LastQuality
            });
            PublishPlateReadyIfComplete();
            return CommandResult.Ok;
        }

        /// <summary>
        /// Sauce is added automatically on serving in Phase 1 - a tap that can
        /// never be wrong is not a mechanic (see MVP scope, objection 1).
        /// </summary>
        private void AddSauce()
        {
            if (!_plate.Contains(ComponentId.Sauce))
                _plate.Add(new PreparedComponent(ComponentId.Sauce, _balance.SauceQuality));
        }

        private void PublishPlateReadyIfComplete()
        {
            // Sauce is implicit, so the plate is "ready" once rice and pork are on.
            if (_plate.Contains(ComponentId.Rice) && _plate.Contains(ComponentId.Pork))
                _bus.Publish(new PlateReadyEvent());
        }

        /// <summary>The customer who has been waiting longest and can still be served.</summary>
        public Customer NextServableCustomer()
        {
            Customer best = null;
            for (int i = 0; i < _customers.Count; i++)
            {
                Customer c = _customers[i];
                if (c.State != CustomerState.WaitingForFood) continue;
                if (best == null || c.Id < best.Id) best = c;
            }
            return best;
        }

        public CommandResult Serve()
        {
            if (_fsm.Current != GameState.RestaurantOpen) return CommandResult.WrongState;

            Customer c = NextServableCustomer();
            if (c == null)
            {
                _bus.Publish(new ServeRejectedEvent { Reason = "NoCustomer" });
                return CommandResult.NoCustomerToServe;
            }

            if (!_plate.Contains(ComponentId.Rice) || !_plate.Contains(ComponentId.Pork))
            {
                _bus.Publish(new ServeRejectedEvent { Reason = "PlateIncomplete" });
                return CommandResult.PlateIncomplete;
            }

            AddSauce();

            RecipeDef recipe = c.Order.Recipe;
            int quality = _plate.Quality(recipe);
            bool accurate = _plate.Matches(recipe);

            SatisfactionResult sat = SatisfactionCalculator.Evaluate(
                _balance, c.Patience01, quality, accurate);

            Money paid = recipe.Price * c.Archetype.SpendMultiplier;
            Money tip = SatisfactionCalculator.CalculateTip(
                _balance, c.Archetype, sat.Stars, paid, _rng);

            Money += paid + tip;
            Result.RecordSale(c.Name, sat.Stars, paid, tip, _content.ComSuonIngredientCost());

            c.ReceivedStars = sat.Stars;
            c.Paid = paid;
            c.Tipped = tip;
            c.SetState(CustomerState.ReceivingFood);

            _plate.Clear();
            _bus.Publish(new PlateClearedEvent());
            _bus.Publish(new CustomerServedEvent
            {
                Customer = c,
                Stars = sat.Stars,
                PlateQuality = quality,
                Paid = paid,
                Tip = tip
            });

            return CommandResult.Ok;
        }

        /// <summary>Bins the current plate - the escape hatch when the wrong thing is on it.</summary>
        public CommandResult DiscardPlate()
        {
            if (_fsm.Current != GameState.RestaurantOpen) return CommandResult.WrongState;
            _plate.Clear();
            _bus.Publish(new PlateClearedEvent());
            return CommandResult.Ok;
        }
    }
}
