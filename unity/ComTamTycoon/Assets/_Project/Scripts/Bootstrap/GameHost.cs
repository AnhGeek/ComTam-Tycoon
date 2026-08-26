using System;
using ComTam.Core.Content;
using ComTam.Core.Domain;
using ComTam.Core.Events;
using ComTam.Core.Simulation;
using ComTam.Core.Util;
using UnityEngine;

namespace ComTam.Unity.Bootstrap
{
    /// <summary>
    /// The single bridge between Unity and ComTam.Core (ADR-0001).
    ///
    /// This is the ONLY MonoBehaviour permitted to drive the simulation. It owns
    /// the fixed-step accumulator, forwards player input as commands, and exposes
    /// the EventBus for views to subscribe to. It contains no game rules - if you
    /// find yourself writing one here, it belongs in Core.
    /// </summary>
    public sealed class GameHost : MonoBehaviour
    {
        /// <summary>
        /// 20 Hz. Deliberately decoupled from frame rate: the perfect-tap window
        /// must behave identically on a 120 Hz iPhone and a stuttering budget
        /// Android, or the difficulty becomes a property of the device.
        /// </summary>
        public const double FixedStep = 0.05;

        [Header("Determinism")]
        [Tooltip("0 = random each run. Set a value to replay an exact day when reproducing a bug.")]
        [SerializeField] private int _seed;

        [Header("Day")]
        [SerializeField] private int _startDay = 1;
        [SerializeField] private bool _autoStart = true;

        public EventBus Bus { get; private set; }
        public DaySimulation Sim { get; private set; }
        public ContentDatabase Content { get; private set; }

        private double _accumulator;
        private bool _running;

        public static GameHost Instance { get; private set; }

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
            DontDestroyOnLoad(gameObject);

            BalanceConfig balance = BalanceConfig.Default();
            Content = ContentDatabase.CreatePhase1(balance);
            Bus = new EventBus();

            int seed = _seed != 0 ? _seed : Environment.TickCount;
            Sim = new DaySimulation(Content, Bus, new XorShiftRandom(seed),
                                    Money.FromDong(balance.StartingMoneyDong));

            Debug.Log("[GameHost] simulation seed = " + seed);
        }

        private void Start()
        {
            if (_autoStart) BeginDay(_startDay);
        }

        public void BeginDay(int day)
        {
            if (!Sim.StartDay(day))
            {
                Debug.LogWarning("[GameHost] refused to start day " + day
                                 + " from state " + Sim.State);
                return;
            }
            _accumulator = 0.0;
            _running = true;
        }

        private void Update()
        {
            if (!_running) return;

            _accumulator += Time.deltaTime;

            // Clamp the catch-up so a long hitch (or resuming from background)
            // cannot spiral into hundreds of ticks in one frame.
            const double maxCatchUp = 0.25;
            if (_accumulator > maxCatchUp) _accumulator = maxCatchUp;

            while (_accumulator >= FixedStep)
            {
                Sim.Tick(FixedStep);
                _accumulator -= FixedStep;

                if (Sim.State != GameState.RestaurantOpen)
                {
                    _running = false;
                    break;
                }
            }
        }

        // -- Commands. Views call these; they never touch DaySimulation directly. --

        public void CmdScoopRice() { Report(Sim.ScoopRice()); }
        public void CmdDiscardPlate() { Report(Sim.DiscardPlate()); }

        /// <summary>One button for the grill: place if empty, take off if occupied.</summary>
        public void CmdGrillTap()
        {
            Report(Sim.Grill.Occupied ? Sim.TakePork() : Sim.PlacePork());
        }

        public void CmdServe() { Report(Sim.Serve()); }

        private static void Report(CommandResult r)
        {
            // Refusals are logged, never swallowed (brief section 43). Views turn
            // ServeRejectedEvent and friends into player-facing feedback.
            if (r != CommandResult.Ok) Debug.Log("[GameHost] command refused: " + r);
        }

        private void OnApplicationPause(bool paused)
        {
            // Phase 1 has no save system yet; this is where SaveSystem.Flush()
            // will go in milestone 15.
            if (paused) Debug.Log("[GameHost] paused");
        }
    }
}
