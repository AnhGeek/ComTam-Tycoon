using System;
using System.Diagnostics;
using System.Text;
using System.Threading;
using ComTam.Core.Content;
using ComTam.Core.Domain;
using ComTam.Core.Economy;
using ComTam.Core.Events;
using ComTam.Core.Simulation;
using ComTam.Core.Util;

namespace ComTam.ConsoleHarness
{
    /// <summary>
    /// A grey-box prototype front-end for ComTam.Core.
    ///
    /// Its purpose is to make the Phase 1 gameplay loop playable and testable
    /// without the Unity Editor - which matters both for CI and for validating
    /// that the grill mechanic is fun before any art exists (risk R1: "if it is
    /// not fun with nothing else on screen, it will never be fun").
    ///
    ///   --auto     run a scripted bot day and print the ledger (used in CI)
    ///   --seed N   fix the RNG seed
    /// </summary>
    public static class Program
    {
        private const double Dt = 0.05;   // 20 Hz, same as the Unity host

        public static int Main(string[] args)
        {
            Console.OutputEncoding = Encoding.UTF8;

            int seed = Environment.TickCount;
            bool auto = false;

            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "--auto") auto = true;
                else if (args[i] == "--seed" && i + 1 < args.Length) seed = int.Parse(args[++i]);
            }

            // Without a TTY there is no interactive input, so fall back to the bot
            // rather than spinning uselessly.
            if (!auto && Console.IsInputRedirected)
            {
                Console.WriteLine("(no interactive terminal detected — running --auto)\n");
                auto = true;
            }

            return auto ? RunAuto(seed) : RunInteractive(seed);
        }

        private static DaySimulation NewSim(EventBus bus, int seed)
        {
            BalanceConfig balance = BalanceConfig.Default();
            ContentDatabase content = ContentDatabase.CreatePhase1(balance);
            return new DaySimulation(content, bus, new XorShiftRandom(seed),
                                     Money.FromDong(balance.StartingMoneyDong));
        }

        // ------------------------------------------------------------------
        // Interactive
        // ------------------------------------------------------------------

        private static int RunInteractive(int seed)
        {
            EventBus bus = new EventBus();
            DaySimulation sim = NewSim(bus, seed);

            string toast = "";
            double toastUntil = 0;
            double now = 0;

            void Toast(string msg) { toast = "  " + msg; toastUntil = now + 1.6; }

            bus.Subscribe<CustomerArrivedEvent>(e => Toast(e.Customer.Name + " vừa tới!"));
            bus.Subscribe<PorkBurnedEvent>(_ => Toast("*** SƯỜN CHÁY! Mất 12,000đ ***"));
            bus.Subscribe<CustomerLeftAngryEvent>(e => Toast(e.Customer.Name + " bỏ đi vì đợi lâu!"));
            bus.Subscribe<PorkCookedEvent>(e =>
                Toast("Sườn " + Vi(e.Doneness) + " — chất lượng " + e.Quality));
            bus.Subscribe<CustomerServedEvent>(e => Toast(string.Format(
                "Phục vụ {0}: {1} sao, +{2}{3}",
                e.Customer.Name, e.Stars, e.Paid.Format(),
                e.Tip.Dong > 0 ? " (+tip " + e.Tip.Format() + ")" : "")));

            Console.Write("\x1b[?25l\x1b[2J"); // hide cursor, clear once
            try
            {
                sim.StartDay(1);
                Stopwatch clock = Stopwatch.StartNew();
                double accumulator = 0;
                double last = 0;

                while (sim.State == GameState.RestaurantOpen)
                {
                    double t = clock.Elapsed.TotalSeconds;
                    double frame = t - last;
                    last = t;
                    now = t;
                    accumulator += frame;

                    while (Console.KeyAvailable)
                    {
                        ConsoleKeyInfo k = Console.ReadKey(true);
                        if (k.Key == ConsoleKey.Q) { Console.Write("\x1b[?25h\x1b[2J\x1b[H"); return 0; }
                        HandleKey(sim, k, Toast);
                    }

                    // Fixed-step: the simulation never sees a variable dt.
                    while (accumulator >= Dt)
                    {
                        sim.Tick(Dt);
                        accumulator -= Dt;
                        if (sim.State != GameState.RestaurantOpen) break;
                    }

                    if (now > toastUntil) toast = "";
                    Console.Write(Renderer.Draw(sim, toast));
                    Thread.Sleep(16);
                }
            }
            finally
            {
                Console.Write("\x1b[?25h"); // always restore the cursor
            }

            Console.Write("\x1b[2J\x1b[H");
            Console.WriteLine(Renderer.DrawResults(sim));
            return 0;
        }

        private static void HandleKey(DaySimulation sim, ConsoleKeyInfo k, Action<string> toast)
        {
            CommandResult r;

            if (k.Key == ConsoleKey.D1 || k.Key == ConsoleKey.NumPad1)
            {
                r = sim.ScoopRice();
                if (r == CommandResult.PlateAlreadyHasComponent) toast("Đĩa đã có cơm rồi.");
            }
            else if (k.Key == ConsoleKey.Spacebar)
            {
                if (sim.Grill.Occupied)
                {
                    r = sim.TakePork();
                    if (r == CommandResult.PorkStillRaw) toast("Sườn còn SỐNG — đợi thêm!");
                }
                else
                {
                    r = sim.PlacePork();
                    if (r == CommandResult.PlateAlreadyHasComponent) toast("Đĩa đã có sườn rồi.");
                }
            }
            else if (k.Key == ConsoleKey.Enter)
            {
                r = sim.Serve();
                if (r == CommandResult.NoCustomerToServe) toast("Chưa có khách nào đợi món.");
                else if (r == CommandResult.PlateIncomplete) toast("Đĩa chưa đủ — cần cơm + sườn.");
            }
            else if (k.Key == ConsoleKey.D)
            {
                sim.DiscardPlate();
                toast("Đã bỏ đĩa.");
            }
        }

        private static string Vi(Doneness d)
        {
            switch (d)
            {
                case Doneness.Cooking: return "tái";
                case Doneness.Perfect: return "VỪA CHÍN";
                case Doneness.Overcooked: return "hơi quá";
                default: return "cháy";
            }
        }

        // ------------------------------------------------------------------
        // Auto (bot) - the CI smoke test of the whole loop
        // ------------------------------------------------------------------

        private static int RunAuto(int seed)
        {
            EventBus bus = new EventBus();
            DaySimulation sim = NewSim(bus, seed);

            bus.Subscribe<CustomerArrivedEvent>(e => Log("ĐẾN    " + e.Customer.Name
                + " (" + e.Customer.Archetype.DisplayNameVi + ")"));
            bus.Subscribe<PorkCookedEvent>(e => Log("NƯỚNG  " + e.Doneness + " q=" + e.Quality));
            bus.Subscribe<PorkBurnedEvent>(_ => Log("CHÁY   mất một miếng sườn"));
            bus.Subscribe<CustomerServedEvent>(e => Log("PHỤC VỤ " + e.Customer.Name
                + "  " + e.Stars + "★  q=" + e.PlateQuality
                + "  " + e.Paid.Format() + (e.Tip.Dong > 0 ? " +tip " + e.Tip.Format() : "")));
            bus.Subscribe<CustomerLeftAngryEvent>(e => Log("MẤT    " + e.Customer.Name + " bỏ đi"));

            Console.WriteLine("=== CƠM TẤM TYCOON — bot day (seed " + seed + ") ===\n");
            sim.StartDay(1);

            int guard = 0;
            while (sim.State == GameState.RestaurantOpen && guard++ < 200000)
            {
                // Simple competent-player policy:
                //   keep a chop on the grill, pull it in the perfect window,
                //   scoop rice while it cooks, serve as soon as the plate is ready.
                if (!sim.Grill.Occupied && !sim.Plate.Contains(ComponentId.Pork)
                    && sim.NextServableCustomer() != null)
                    sim.PlacePork();

                if (!sim.Plate.Contains(ComponentId.Rice) && sim.NextServableCustomer() != null)
                    sim.ScoopRice();

                if (sim.Grill.Occupied && sim.Grill.CurrentDoneness == Doneness.Perfect)
                    sim.TakePork();

                if (sim.Plate.Contains(ComponentId.Rice) && sim.Plate.Contains(ComponentId.Pork))
                    sim.Serve();

                sim.Tick(Dt);
            }

            Console.WriteLine(Renderer.DrawResults(sim));

            // The loop is only "working" if a competent bot can actually trade.
            DayResult r = sim.Result;
            bool ok = sim.State == GameState.DailyResults
                      && r.CustomersServed > 0
                      && r.Profit.Dong > 0;

            Console.WriteLine(ok
                ? "SMOKE TEST: PASS — the loop closes and turns a profit."
                : "SMOKE TEST: FAIL — served=" + r.CustomersServed
                  + " profit=" + r.Profit.Format() + " state=" + sim.State);

            return ok ? 0 : 1;
        }

        private static void Log(string s) { Console.WriteLine("  " + s); }
    }
}
