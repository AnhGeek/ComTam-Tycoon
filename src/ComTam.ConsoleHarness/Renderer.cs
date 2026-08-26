using System;
using System.Text;
using ComTam.Core.Domain;
using ComTam.Core.Simulation;

namespace ComTam.ConsoleHarness
{
    /// <summary>
    /// Draws the simulation as text. This is the harness equivalent of the Unity
    /// view layer: it reads simulation state and renders it, and contains no game
    /// rules whatsoever. Swapping this for Unity changes nothing in Core.
    /// </summary>
    public static class Renderer
    {
        private const int Width = 62;
        private const int GrillBarWidth = 40;

        public static string Draw(DaySimulation sim, string toast)
        {
            StringBuilder sb = new StringBuilder(2048);

            sb.Append("[H"); // cursor home; avoids the flicker of a full clear

            Line(sb, "╔" + new string('═', Width) + "╗");
            Row(sb, string.Format("  {0,-16}  NGÀY {1}          ⏱  {2}",
                sim.Money.Format(), sim.Day, FormatTime(sim.TimeRemaining)));
            Line(sb, "╠" + new string('═', Width) + "╣");

            // ---- Queue ----
            Row(sb, "  KHÁCH HÀNG");
            int shown = 0;
            foreach (Customer c in sim.Customers)
            {
                if (c.QueueSlot < 0 || !c.IsActive) continue;
                Row(sb, "   " + DescribeCustomer(c));
                shown++;
            }
            for (int i = shown; i < 3; i++) Row(sb, "   [ trống ]");

            Line(sb, "╠" + new string('═', Width) + "╣");

            // ---- Grill ----
            Row(sb, "  BẾP NƯỚNG (sườn)");
            if (sim.Grill.Occupied)
            {
                Row(sb, "   " + GrillBar(sim));
                Row(sb, "   " + DonenessLabel(sim.Grill.CurrentDoneness));
            }
            else
            {
                Row(sb, "   " + new string('·', GrillBarWidth));
                Row(sb, "   Bếp trống — nhấn [SPACE] để đặt sườn lên");
            }

            Line(sb, "╠" + new string('═', Width) + "╣");

            // ---- Plate ----
            string rice = sim.Plate.Contains(ComponentId.Rice) ? "Cơm ✓" : "Cơm ·";
            string pork = sim.Plate.Contains(ComponentId.Pork) ? "Sườn ✓" : "Sườn ·";
            bool ready = sim.Plate.Contains(ComponentId.Rice) && sim.Plate.Contains(ComponentId.Pork);
            Row(sb, "  ĐĨA:   " + rice + "    " + pork + (ready ? "     ➜ SẴN SÀNG PHỤC VỤ" : ""));

            Line(sb, "╠" + new string('═', Width) + "╣");
            Row(sb, "  [1] Xới cơm   [SPACE] Nướng/Lấy   [ENTER] Phục vụ");
            Row(sb, "  [D] Bỏ đĩa    [Q] Thoát");
            Line(sb, "╚" + new string('═', Width) + "╝");

            Row2(sb, toast ?? "");
            Row2(sb, string.Format("  Đã phục vụ: {0}   Mất khách: {1}   Cháy: {2}",
                sim.Result.CustomersServed, sim.Result.CustomersLostAngry, sim.Result.PorkBurned));

            return sb.ToString();
        }

        private static string DescribeCustomer(Customer c)
        {
            string status;
            switch (c.State)
            {
                case CustomerState.WalkingToQueue: status = "đang tới..."; break;
                case CustomerState.Ordering: status = "đang gọi món..."; break;
                case CustomerState.WaitingForFood: status = PatienceBar(c.Patience01); break;
                case CustomerState.ReceivingFood: status = "nhận món ★" + c.ReceivedStars; break;
                case CustomerState.Eating: status = "đang ăn... ★" + c.ReceivedStars; break;
                case CustomerState.LeftAngry: status = "BỎ ĐI GIẬN DỮ"; break;
                case CustomerState.Leaving: status = "ra về ★" + c.ReceivedStars; break;
                default: status = ""; break;
            }

            string name = Truncate(c.Name, 14);
            return string.Format("{0} {1,-14} {2,-9} {3}",
                MoodFace(c), name, ShortArchetype(c.Archetype.Id), status);
        }

        private static string MoodFace(Customer c)
        {
            if (c.State == CustomerState.LeftAngry) return "(╬)";
            if (c.State == CustomerState.Eating || c.State == CustomerState.ReceivingFood) return "(^)";
            switch (c.Mood)
            {
                case CustomerMood.Happy: return "(:)";
                case CustomerMood.Normal: return "(-)";
                case CustomerMood.Impatient: return "(>)";
                default: return "(!)";
            }
        }

        private static string ShortArchetype(string id)
        {
            switch (id)
            {
                case "student": return "SV";
                case "office_worker": return "VP";
                case "busy_customer": return "VỘI";
                default: return id;
            }
        }

        private static string PatienceBar(double p01)
        {
            int filled = (int)Math.Round(p01 * 10);
            if (filled < 0) filled = 0; if (filled > 10) filled = 10;
            return "[" + new string('#', filled) + new string('.', 10 - filled) + "] "
                   + (int)Math.Round(p01 * 100) + "%";
        }

        /// <summary>
        /// The doneness bar. Zone boundaries are drawn from the CookProfile, so the
        /// bar can never disagree with the simulation.
        /// </summary>
        private static string GrillBar(DaySimulation sim)
        {
            CookProfile p = sim.Grill.Profile;
            double total = p.BurntAt;
            int head = (int)(sim.Grill.Elapsed / total * GrillBarWidth);
            int perfectStart = (int)(p.PerfectStart / total * GrillBarWidth);
            int perfectEnd = (int)(p.PerfectEnd / total * GrillBarWidth);

            StringBuilder bar = new StringBuilder(GrillBarWidth + 8);
            for (int i = 0; i < GrillBarWidth; i++)
            {
                if (i == head) bar.Append('█');
                else if (i >= perfectStart && i <= perfectEnd) bar.Append('=');   // perfect zone
                else if (i < head) bar.Append('#');
                else bar.Append('.');
            }
            return bar.ToString();
        }

        private static string DonenessLabel(Doneness d)
        {
            switch (d)
            {
                case Doneness.Raw: return "SỐNG      — chưa lấy được";
                case Doneness.Cooking: return "ĐANG NƯỚNG — còn tái";
                case Doneness.Perfect: return "*** VỪA CHÍN! *** — LẤY NGAY [SPACE]";
                case Doneness.Overcooked: return "HƠI QUÁ   — lấy nhanh!";
                default: return "CHÁY!";
            }
        }

        public static string DrawResults(DaySimulation sim)
        {
            var r = sim.Result;
            StringBuilder sb = new StringBuilder();
            sb.AppendLine();
            sb.AppendLine("╔" + new string('═', Width) + "╗");
            sb.AppendLine(Pad("        NGÀY " + r.Day + " HOÀN THÀNH"));
            sb.AppendLine("╠" + new string('═', Width) + "╣");
            sb.AppendLine(Pad(string.Format("  Doanh thu           + {0,14}", r.Revenue.Format())));
            sb.AppendLine(Pad(string.Format("  Tiền tip            + {0,14}", r.Tips.Format())));
            sb.AppendLine(Pad(string.Format("  Nguyên liệu         - {0,14}", r.IngredientCost.Format())));
            sb.AppendLine(Pad(string.Format("  Thưởng mục tiêu     + {0,14}", r.GoalBonus.Format())));
            sb.AppendLine(Pad("  " + new string('-', 40)));
            sb.AppendLine(Pad(string.Format("  LỢI NHUẬN           + {0,14}", r.Profit.Format())));
            sb.AppendLine("╠" + new string('═', Width) + "╣");
            sb.AppendLine(Pad(string.Format("  Khách phục vụ        {0,14}", r.CustomersServed)));
            sb.AppendLine(Pad(string.Format("  Khách bỏ đi          {0,14}", r.CustomersLostAngry)));
            sb.AppendLine(Pad(string.Format("  Sườn cháy            {0,14}", r.PorkBurned)));
            sb.AppendLine(Pad(string.Format("  Đánh giá TB          {0,14}",
                r.AverageStars.ToString("0.0") + " sao")));
            sb.AppendLine(Pad(string.Format("  Khách tốt nhất       {0,14}",
                r.BestCustomerName ?? "-")));
            sb.AppendLine("╠" + new string('═', Width) + "╣");
            sb.AppendLine(Pad(string.Format("  Mục tiêu ({0} khách)   {1}",
                r.GoalTarget, r.GoalMet ? "HOÀN THÀNH  +" + r.GoalBonus.Format() : "CHƯA ĐẠT")));
            sb.AppendLine(Pad(string.Format("  Tiền mặt             {0,14}", sim.Money.Format())));
            sb.AppendLine("╚" + new string('═', Width) + "╝");
            return sb.ToString();
        }

        // Box drawing is width-sensitive and Vietnamese text is full of combining
        // marks, so pad on the visible-character count, not the UTF-16 length.
        private static void Row(StringBuilder sb, string content) { sb.Append(Pad(content)).Append('\n'); }
        private static void Row2(StringBuilder sb, string content) { sb.Append(ClearLine(content)).Append('\n'); }
        private static void Line(StringBuilder sb, string s) { sb.Append(s).Append('\n'); }

        private static string Pad(string content)
        {
            int len = VisibleLength(content);
            if (len > Width) content = Truncate(content, Width);
            return "║" + content + new string(' ', Math.Max(0, Width - VisibleLength(content))) + "║";
        }

        private static string ClearLine(string content)
        {
            return content + "[K";
        }

        private static int VisibleLength(string s)
        {
            int n = 0;
            foreach (char ch in s)
                if (!System.Globalization.CharUnicodeInfo.GetUnicodeCategory(ch)
                        .Equals(System.Globalization.UnicodeCategory.NonSpacingMark)) n++;
            return n;
        }

        private static string Truncate(string s, int max)
        {
            if (VisibleLength(s) <= max) return s;
            StringBuilder sb = new StringBuilder();
            int n = 0;
            foreach (char ch in s)
            {
                if (n >= max) break;
                sb.Append(ch);
                if (!System.Globalization.CharUnicodeInfo.GetUnicodeCategory(ch)
                        .Equals(System.Globalization.UnicodeCategory.NonSpacingMark)) n++;
            }
            return sb.ToString();
        }

        private static string FormatTime(double seconds)
        {
            int s = (int)Math.Ceiling(seconds);
            return (s / 60) + ":" + (s % 60).ToString("00");
        }
    }
}
