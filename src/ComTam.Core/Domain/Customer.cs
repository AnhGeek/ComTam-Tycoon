using ComTam.Core.Util;

namespace ComTam.Core.Domain
{
    /// <summary>Customer lifecycle (brief section 32).</summary>
    public enum CustomerState
    {
        Spawning = 0,
        WalkingToQueue = 1,
        Waiting = 2,          // in queue, patience draining
        Ordering = 3,
        WaitingForFood = 4,   // order placed, patience still draining
        ReceivingFood = 5,
        Eating = 6,
        Leaving = 7,
        LeftAngry = 8,
        Done = 9              // fully despawned; slot is free
    }

    public sealed class CustomerArchetypeDef
    {
        public string Id;
        public string DisplayNameVi;
        public double PatienceSeconds;
        public double SpendMultiplier;
        public int QualityTolerance;
        public double TipChance;
        public string SpriteKey;
    }

    /// <summary>What a customer asked for.</summary>
    public sealed class Order
    {
        public string RecipeId;
        public RecipeDef Recipe;

        public Order(RecipeDef recipe)
        {
            Recipe = recipe;
            RecipeId = recipe != null ? recipe.Id : null;
        }
    }

    public sealed class Customer
    {
        public int Id;
        public CustomerArchetypeDef Archetype;
        public string Name;
        public CustomerState State;
        public Order Order;

        /// <summary>Queue slot index, or -1 if not queued.</summary>
        public int QueueSlot = -1;

        /// <summary>1.0 = fresh, 0.0 = out of patience.</summary>
        public double Patience01 = 1.0;

        /// <summary>Seconds spent in the current state.</summary>
        public double StateElapsed;

        /// <summary>Total seconds spent waiting - feeds the satisfaction score.</summary>
        public double TotalWaitSeconds;

        /// <summary>Set once served.</summary>
        public int ReceivedStars;
        public Money Paid;
        public Money Tipped;

        public bool IsWaiting
        {
            get { return State == CustomerState.Waiting || State == CustomerState.WaitingForFood; }
        }

        /// <summary>Occupies a queue slot and should be drawn.</summary>
        public bool IsActive
        {
            get { return State != CustomerState.Done && State != CustomerState.Spawning; }
        }

        public CustomerMood Mood
        {
            get
            {
                if (Patience01 >= 0.80) return CustomerMood.Happy;
                if (Patience01 >= 0.50) return CustomerMood.Normal;
                if (Patience01 >= 0.20) return CustomerMood.Impatient;
                return CustomerMood.Angry;
            }
        }

        public void SetState(CustomerState next)
        {
            State = next;
            StateElapsed = 0.0;
        }

        /// <summary>Applies a one-off patience hit, e.g. when the player burns food.</summary>
        public void PenalisePatience(double amount01)
        {
            Patience01 = MathX.Clamp01(Patience01 - amount01);
        }
    }

    /// <summary>Patience bands from brief section 10.</summary>
    public enum CustomerMood
    {
        Happy = 0,
        Normal = 1,
        Impatient = 2,
        Angry = 3
    }
}
