using System;
using ComTam.Core.Domain;

namespace ComTam.Core.Economy
{
    /// <summary>
    /// The end-of-day ledger shown on the results screen (brief section 22).
    /// Accumulated during the day, then frozen when the day closes.
    /// </summary>
    public sealed class DayResult
    {
        public int Day;

        public Money Revenue = Money.Zero;
        public Money Tips = Money.Zero;
        public Money IngredientCost = Money.Zero;
        public Money OperatingCost = Money.Zero;
        public Money GoalBonus = Money.Zero;

        public int CustomersServed;
        public int CustomersLostAngry;
        public int PorkBurned;

        /// <summary>Sum of stars awarded, for the average.</summary>
        public int TotalStars;

        public string BestCustomerName;
        public int BestCustomerStars = -1;

        public int GoalTarget;
        public bool GoalMet;

        public Money Profit
        {
            get { return Revenue + Tips + GoalBonus - IngredientCost - OperatingCost; }
        }

        public double AverageStars
        {
            get { return CustomersServed == 0 ? 0.0 : (double)TotalStars / CustomersServed; }
        }

        public void RecordSale(string customerName, int stars, Money paid, Money tip, Money ingredientCost)
        {
            CustomersServed++;
            TotalStars += stars;
            Revenue += paid;
            Tips += tip;
            IngredientCost += ingredientCost;

            if (stars > BestCustomerStars)
            {
                BestCustomerStars = stars;
                BestCustomerName = customerName;
            }
        }

        /// <summary>
        /// Burnt pork wastes the chop but not the rice or sauce - those have not
        /// been plated yet when the grill catches.
        /// </summary>
        public void RecordBurn(Money porkCost)
        {
            PorkBurned++;
            IngredientCost += porkCost;
        }

        public void RecordAngryDeparture()
        {
            CustomersLostAngry++;
        }

        public void FinaliseGoal(int target, Money bonus)
        {
            GoalTarget = target;
            GoalMet = CustomersServed >= target;
            GoalBonus = GoalMet ? bonus : Money.Zero;
        }
    }
}
