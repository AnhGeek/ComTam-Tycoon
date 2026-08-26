using System;
using ComTam.Core.Domain;
using ComTam.Core.Economy;
using ComTam.Core.Events;
using ComTam.Unity.Bootstrap;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace ComTam.Unity.UI
{
    /// <summary>
    /// Top bar, plate readout, action buttons and the daily results panel.
    ///
    /// Text is only rewritten when the underlying value actually changes -
    /// assigning to TMP_Text.text every frame dirties the canvas and is one of the
    /// standard mobile UI CPU sinks.
    /// </summary>
    public sealed class HudView : MonoBehaviour
    {
        [Header("Top bar")]
        [SerializeField] private TMP_Text _moneyLabel;
        [SerializeField] private TMP_Text _dayLabel;
        [SerializeField] private TMP_Text _timerLabel;

        [Header("Plate")]
        [SerializeField] private Image _riceTick;
        [SerializeField] private Image _porkTick;
        [SerializeField] private GameObject _readyBanner;

        [Header("Actions")]
        [SerializeField] private Button _riceButton;
        [SerializeField] private Button _grillButton;
        [SerializeField] private Button _serveButton;

        [Header("Toast")]
        [SerializeField] private TMP_Text _toastLabel;
        [SerializeField] private float _toastSeconds = 1.6f;

        [Header("Daily results")]
        [SerializeField] private GameObject _resultsPanel;
        [SerializeField] private TMP_Text _resultsBody;

        private GameHost _host;
        private long _lastMoney = long.MinValue;
        private int _lastDay = -1;
        private int _lastTimerSecond = -1;
        private float _toastUntil;

        private static readonly Color TickOn = new Color(0.42f, 0.60f, 0.31f);
        private static readonly Color TickOff = new Color(0.75f, 0.72f, 0.68f);

        private void Start()
        {
            _host = GameHost.Instance;
            if (_host == null)
            {
                Debug.LogError("[HudView] no GameHost in the scene");
                enabled = false;
                return;
            }

            if (_riceButton != null) _riceButton.onClick.AddListener(_host.CmdScoopRice);
            if (_grillButton != null) _grillButton.onClick.AddListener(_host.CmdGrillTap);
            if (_serveButton != null) _serveButton.onClick.AddListener(_host.CmdServe);

            _host.Bus.Subscribe<CustomerServedEvent>(OnServed);
            _host.Bus.Subscribe<PorkBurnedEvent>(OnBurned);
            _host.Bus.Subscribe<CustomerLeftAngryEvent>(OnLeftAngry);
            _host.Bus.Subscribe<ServeRejectedEvent>(OnServeRejected);
            _host.Bus.Subscribe<DayEndedEvent>(OnDayEnded);

            if (_resultsPanel != null) _resultsPanel.SetActive(false);
            if (_toastLabel != null) _toastLabel.text = "";
        }

        private void OnDestroy()
        {
            if (_host == null) return;
            _host.Bus.Unsubscribe<CustomerServedEvent>(OnServed);
            _host.Bus.Unsubscribe<PorkBurnedEvent>(OnBurned);
            _host.Bus.Unsubscribe<CustomerLeftAngryEvent>(OnLeftAngry);
            _host.Bus.Unsubscribe<ServeRejectedEvent>(OnServeRejected);
            _host.Bus.Unsubscribe<DayEndedEvent>(OnDayEnded);
        }

        private void Update()
        {
            if (_host == null) return;

            long money = _host.Sim.Money.Dong;
            if (money != _lastMoney)
            {
                _lastMoney = money;
                if (_moneyLabel != null) _moneyLabel.text = _host.Sim.Money.Format();
            }

            if (_host.Sim.Day != _lastDay)
            {
                _lastDay = _host.Sim.Day;
                if (_dayLabel != null) _dayLabel.text = "NGÀY " + _lastDay;
            }

            int second = Mathf.CeilToInt((float)_host.Sim.TimeRemaining);
            if (second != _lastTimerSecond)
            {
                _lastTimerSecond = second;
                if (_timerLabel != null)
                    _timerLabel.text = (second / 60) + ":" + (second % 60).ToString("00");
            }

            bool hasRice = _host.Sim.Plate.Contains(ComponentId.Rice);
            bool hasPork = _host.Sim.Plate.Contains(ComponentId.Pork);
            if (_riceTick != null) _riceTick.color = hasRice ? TickOn : TickOff;
            if (_porkTick != null) _porkTick.color = hasPork ? TickOn : TickOff;
            if (_readyBanner != null) _readyBanner.SetActive(hasRice && hasPork);

            if (_toastLabel != null && _toastUntil > 0f && Time.time > _toastUntil)
            {
                _toastLabel.text = "";
                _toastUntil = 0f;
            }
        }

        private void Toast(string message)
        {
            if (_toastLabel == null) return;
            _toastLabel.text = message;
            _toastUntil = Time.time + _toastSeconds;
        }

        private void OnServed(CustomerServedEvent e)
        {
            string tip = e.Tip.Dong > 0 ? "  +tip " + e.Tip.Format() : "";
            Toast(new string('*', e.Stars) + "  +" + e.Paid.Format() + tip);
        }

        private void OnBurned(PorkBurnedEvent e) { Toast("SƯỜN CHÁY!"); }

        private void OnLeftAngry(CustomerLeftAngryEvent e)
        {
            Toast(e.Customer.Name + " bỏ đi vì đợi lâu!");
        }

        private void OnServeRejected(ServeRejectedEvent e)
        {
            Toast(e.Reason == "PlateIncomplete" ? "Đĩa chưa đủ — cần cơm + sườn"
                                                : "Chưa có khách đợi món");
        }

        private void OnDayEnded(DayEndedEvent e)
        {
            if (_resultsPanel != null) _resultsPanel.SetActive(true);
            if (_resultsBody == null) return;

            DayResult r = e.Result;
            _resultsBody.text = string.Join("\n", new[]
            {
                "NGÀY " + r.Day + " HOÀN THÀNH",
                "",
                "Doanh thu       +" + r.Revenue.Format(),
                "Tiền tip        +" + r.Tips.Format(),
                "Nguyên liệu     -" + r.IngredientCost.Format(),
                "Thưởng mục tiêu +" + r.GoalBonus.Format(),
                "----------------------------",
                "LỢI NHUẬN       +" + r.Profit.Format(),
                "",
                "Khách phục vụ    " + r.CustomersServed,
                "Khách bỏ đi      " + r.CustomersLostAngry,
                "Sườn cháy        " + r.PorkBurned,
                "Đánh giá TB      " + r.AverageStars.ToString("0.0") + " sao",
                "Khách tốt nhất   " + (r.BestCustomerName ?? "-"),
                "",
                "Mục tiêu: " + (r.GoalMet ? "HOÀN THÀNH" : "CHƯA ĐẠT")
            });
        }
    }
}
