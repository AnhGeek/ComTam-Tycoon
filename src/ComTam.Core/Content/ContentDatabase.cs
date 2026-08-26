using System.Collections.Generic;
using ComTam.Core.Domain;

namespace ComTam.Core.Content
{
    /// <summary>
    /// Phase 1 content: one recipe, three customer archetypes, a Vietnamese name
    /// pool. In Phase 2 this is populated from /content/*.json instead of code.
    /// </summary>
    public sealed class ContentDatabase
    {
        public const string ComSuonId = "com_suon";

        public BalanceConfig Balance { get; private set; }
        public RecipeDef ComSuon { get; private set; }
        public IReadOnlyList<CustomerArchetypeDef> Archetypes { get { return _archetypes; } }
        public IReadOnlyList<string> NamePool { get { return _names; } }

        private readonly List<CustomerArchetypeDef> _archetypes = new List<CustomerArchetypeDef>();
        private readonly List<string> _names = new List<string>();
        private readonly Dictionary<string, RecipeDef> _recipes = new Dictionary<string, RecipeDef>();

        public static ContentDatabase CreatePhase1(BalanceConfig balance)
        {
            if (balance == null) balance = BalanceConfig.Default();
            ContentDatabase db = new ContentDatabase();
            db.Balance = balance;

            // --- Recipe: Cơm sườn (broken rice + grilled pork chop + sauce) ---
            // Weights are the canonical full-menu weights from the design doc
            // (Rice .20 / Pork .40 / Egg .20 / Sauce .20). Plate.Quality
            // normalises over the components actually present, so omitting egg
            // in Phase 1 yields .25 / .50 / .25 with no separate table.
            db.ComSuon = new RecipeDef
            {
                Id = ComSuonId,
                DisplayNameVi = "Cơm sườn",
                DisplayNameEn = "Broken rice with grilled pork chop",
                Required = new[] { ComponentId.Rice, ComponentId.Pork, ComponentId.Sauce },
                Price = Money.FromDong(balance.ComSuonPriceDong),
                QualityWeights = new Dictionary<ComponentId, double>
                {
                    { ComponentId.Rice, 0.20 },
                    { ComponentId.Pork, 0.40 },
                    { ComponentId.Egg, 0.20 },
                    { ComponentId.Sauce, 0.20 }
                }
            };
            db._recipes[db.ComSuon.Id] = db.ComSuon;

            db._archetypes.Add(new CustomerArchetypeDef
            {
                Id = "student",
                DisplayNameVi = "Sinh viên",
                PatienceSeconds = 70.0,
                SpendMultiplier = 0.9,
                QualityTolerance = 40,
                TipChance = 0.10,
                SpriteKey = "char_student_a"
            });

            db._archetypes.Add(new CustomerArchetypeDef
            {
                Id = "office_worker",
                DisplayNameVi = "Nhân viên văn phòng",
                PatienceSeconds = 50.0,
                SpendMultiplier = 1.0,
                QualityTolerance = 60,
                TipChance = 0.35,
                SpriteKey = "char_office_worker_a"
            });

            db._archetypes.Add(new CustomerArchetypeDef
            {
                Id = "busy_customer",
                DisplayNameVi = "Khách vội",
                PatienceSeconds = 30.0,
                SpendMultiplier = 1.2,
                QualityTolerance = 55,
                TipChance = 0.50,
                SpriteKey = "char_busy_a"
            });

            db._names.AddRange(new[]
            {
                "Nguyễn Minh", "Trần Thu Hà", "Lê Văn Dũng", "Phạm Thị Mai",
                "Hoàng Anh Tuấn", "Vũ Ngọc Lan", "Đặng Quốc Bảo", "Bùi Thanh Trúc",
                "Đỗ Hải Nam", "Ngô Kim Chi", "Dương Tấn Phát", "Lý Bích Ngọc"
            });

            return db;
        }

        public RecipeDef GetRecipe(string id)
        {
            RecipeDef r;
            return _recipes.TryGetValue(id, out r) ? r : null;
        }

        /// <summary>Grill timing windows resolved from balance (Phase 1: level 1 only).</summary>
        public CookProfile GrillProfile()
        {
            return new CookProfile(
                Balance.GrillRawUntilSeconds,
                Balance.GrillPerfectStartSeconds,
                Balance.GrillPerfectEndSeconds,
                Balance.GrillBurntAtSeconds);
        }

        /// <summary>Ingredient cost of one plate - reported in the day ledger.</summary>
        public Money ComSuonIngredientCost()
        {
            return Money.FromDong(Balance.RiceCostDong + Balance.PorkCostDong + Balance.SauceCostDong);
        }
    }
}
