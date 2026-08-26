using System.Collections.Generic;

namespace ComTam.Core.Simulation
{
    /// <summary>Brief section 31. Phase 1 uses a subset; the rest arrive with their features.</summary>
    public enum GameState
    {
        MainMenu = 0,
        Preparation = 1,
        RestaurantOpen = 2,
        RestaurantClosed = 3,
        DailyResults = 4,
        Paused = 5
    }

    /// <summary>
    /// Guards state transitions so invalid ones fail loudly instead of leaving the
    /// game in a state nobody designed. Illegal transitions are refused and
    /// reported, never silently ignored (brief section 43).
    /// </summary>
    public sealed class GameStateMachine
    {
        private static readonly Dictionary<GameState, GameState[]> Allowed =
            new Dictionary<GameState, GameState[]>
            {
                { GameState.MainMenu,         new[] { GameState.Preparation } },
                { GameState.Preparation,      new[] { GameState.RestaurantOpen, GameState.MainMenu } },
                { GameState.RestaurantOpen,   new[] { GameState.RestaurantClosed, GameState.Paused } },
                { GameState.RestaurantClosed, new[] { GameState.DailyResults } },
                { GameState.DailyResults,     new[] { GameState.Preparation, GameState.MainMenu } },
                { GameState.Paused,           new[] { GameState.RestaurantOpen, GameState.MainMenu } }
            };

        public GameState Current { get; private set; }
        public string LastRejection { get; private set; }

        public GameStateMachine(GameState initial)
        {
            Current = initial;
        }

        public bool CanTransitionTo(GameState next)
        {
            GameState[] targets;
            if (!Allowed.TryGetValue(Current, out targets)) return false;
            for (int i = 0; i < targets.Length; i++)
                if (targets[i] == next) return true;
            return false;
        }

        public bool TransitionTo(GameState next)
        {
            if (!CanTransitionTo(next))
            {
                LastRejection = "Illegal transition " + Current + " -> " + next;
                return false;
            }
            LastRejection = null;
            Current = next;
            return true;
        }
    }
}
