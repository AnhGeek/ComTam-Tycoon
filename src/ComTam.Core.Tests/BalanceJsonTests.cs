using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Text.Json;
using ComTam.Core.Content;
using NUnit.Framework;

namespace ComTam.Core.Tests
{
    /// <summary>
    /// ADR-0003 makes /content/balance.json the source of truth for tuning, but
    /// Phase 1 still reads defaults from BalanceConfig (no JSON loader in Core
    /// yet - that arrives in Phase 2 with the balance editor).
    ///
    /// This test is what stops the two from drifting in the meantime: change one
    /// without the other and the build fails. Without it, balance.json would
    /// quietly become a lie.
    /// </summary>
    [TestFixture]
    public class BalanceJsonMatchesDefaultsTests
    {
        private static string RepoRoot()
        {
            DirectoryInfo dir = new DirectoryInfo(TestContext.CurrentContext.TestDirectory);
            while (dir != null && !Directory.Exists(Path.Combine(dir.FullName, "content")))
                dir = dir.Parent;
            Assert.That(dir, Is.Not.Null, "could not locate the repo root (no /content directory found)");
            return dir.FullName;
        }

        private static JsonElement LoadJson()
        {
            string path = Path.Combine(RepoRoot(), "content", "balance.json");
            Assert.That(File.Exists(path), Is.True, "missing " + path);
            using (JsonDocument doc = JsonDocument.Parse(File.ReadAllText(path)))
                return doc.RootElement.Clone();
        }

        [Test]
        public void Every_balance_field_matches_the_json()
        {
            JsonElement json = LoadJson();
            BalanceConfig defaults = BalanceConfig.Default();
            List<string> mismatches = new List<string>();
            int checkedCount = 0;

            foreach (FieldInfo f in typeof(BalanceConfig).GetFields(BindingFlags.Public | BindingFlags.Instance))
            {
                JsonElement node;
                if (!json.TryGetProperty(f.Name, out node))
                {
                    mismatches.Add(f.Name + ": missing from balance.json");
                    continue;
                }

                checkedCount++;
                object actual = f.GetValue(defaults);

                if (f.FieldType == typeof(long))
                {
                    if (node.GetInt64() != (long)actual)
                        mismatches.Add(f.Name + ": json=" + node.GetInt64() + " code=" + actual);
                }
                else if (f.FieldType == typeof(int))
                {
                    if (node.GetInt32() != (int)actual)
                        mismatches.Add(f.Name + ": json=" + node.GetInt32() + " code=" + actual);
                }
                else if (f.FieldType == typeof(double))
                {
                    if (Math.Abs(node.GetDouble() - (double)actual) > 1e-9)
                        mismatches.Add(f.Name + ": json=" + node.GetDouble() + " code=" + actual);
                }
                else
                {
                    mismatches.Add(f.Name + ": unhandled type " + f.FieldType.Name);
                }
            }

            Assert.That(checkedCount, Is.GreaterThan(20), "sanity: most fields should have been compared");
            Assert.That(mismatches, Is.Empty,
                "balance.json and BalanceConfig have drifted:\n  " + string.Join("\n  ", mismatches));
        }

        [Test]
        public void Json_has_no_stray_keys()
        {
            JsonElement json = LoadJson();
            HashSet<string> known = new HashSet<string>();
            foreach (FieldInfo f in typeof(BalanceConfig).GetFields(BindingFlags.Public | BindingFlags.Instance))
                known.Add(f.Name);

            List<string> strays = new List<string>();
            foreach (JsonProperty p in json.EnumerateObject())
                if (!p.Name.StartsWith("_", StringComparison.Ordinal) && !known.Contains(p.Name))
                    strays.Add(p.Name);

            Assert.That(strays, Is.Empty, "balance.json has keys the game does not read: "
                                          + string.Join(", ", strays));
        }
    }

    [TestFixture]
    public class ContentValidationTests
    {
        [Test]
        public void Com_suon_is_rice_pork_and_sauce_at_forty_five_thousand()
        {
            ContentDatabase db = ContentDatabase.CreatePhase1(BalanceConfig.Default());
            Assert.That(db.ComSuon.DisplayNameVi, Is.EqualTo("Cơm sườn"));
            Assert.That(db.ComSuon.Price.Dong, Is.EqualTo(45000));
            Assert.That(db.ComSuon.Required, Is.EquivalentTo(new[]
            {
                ComTam.Core.Domain.ComponentId.Rice,
                ComTam.Core.Domain.ComponentId.Pork,
                ComTam.Core.Domain.ComponentId.Sauce
            }));
        }

        [Test]
        public void Recipe_quality_weights_sum_to_one()
        {
            ContentDatabase db = ContentDatabase.CreatePhase1(BalanceConfig.Default());
            double sum = 0.0;
            foreach (KeyValuePair<ComTam.Core.Domain.ComponentId, double> kv in db.ComSuon.QualityWeights)
                sum += kv.Value;
            Assert.That(sum, Is.EqualTo(1.0).Within(1e-9));
        }

        [Test]
        public void Ingredient_cost_leaves_a_healthy_margin()
        {
            ContentDatabase db = ContentDatabase.CreatePhase1(BalanceConfig.Default());
            long cost = db.ComSuonIngredientCost().Dong;
            long price = db.ComSuon.Price.Dong;
            double margin = (price - cost) / (double)price;
            Assert.That(cost, Is.EqualTo(16000));
            Assert.That(margin, Is.InRange(0.55, 0.75),
                "margin outside the designed ~64% band - the economy doc needs updating too");
        }

        [Test]
        public void Every_archetype_is_well_formed()
        {
            ContentDatabase db = ContentDatabase.CreatePhase1(BalanceConfig.Default());
            Assert.That(db.Archetypes.Count, Is.EqualTo(3));
            foreach (CustomerArchetypeDefShim a in Wrap(db))
            {
                Assert.That(a.PatienceSeconds, Is.GreaterThan(0), a.Id);
                Assert.That(a.SpendMultiplier, Is.GreaterThan(0), a.Id);
                Assert.That(a.TipChance, Is.InRange(0.0, 1.0), a.Id);
                Assert.That(a.DisplayNameVi, Is.Not.Null.And.Not.Empty, a.Id);
            }
        }

        private struct CustomerArchetypeDefShim
        {
            public string Id; public double PatienceSeconds; public double SpendMultiplier;
            public double TipChance; public string DisplayNameVi;
        }

        private static IEnumerable<CustomerArchetypeDefShim> Wrap(ContentDatabase db)
        {
            foreach (ComTam.Core.Domain.CustomerArchetypeDef a in db.Archetypes)
                yield return new CustomerArchetypeDefShim
                {
                    Id = a.Id,
                    PatienceSeconds = a.PatienceSeconds,
                    SpendMultiplier = a.SpendMultiplier,
                    TipChance = a.TipChance,
                    DisplayNameVi = a.DisplayNameVi
                };
        }

        [Test]
        public void Name_pool_is_vietnamese_and_non_empty()
        {
            ContentDatabase db = ContentDatabase.CreatePhase1(BalanceConfig.Default());
            Assert.That(db.NamePool.Count, Is.GreaterThanOrEqualTo(10));
            // Guards against the diacritics being stripped somewhere in the pipeline (ADR-0005).
            bool anyDiacritic = false;
            foreach (string n in db.NamePool)
                foreach (char ch in n)
                    if (ch > 127) { anyDiacritic = true; break; }
            Assert.That(anyDiacritic, Is.True, "Vietnamese names lost their diacritics");
        }
    }
}
