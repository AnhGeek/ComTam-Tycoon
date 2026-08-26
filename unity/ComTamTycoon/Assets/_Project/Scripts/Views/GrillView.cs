using ComTam.Core.Domain;
using ComTam.Core.Events;
using ComTam.Core.Simulation;
using ComTam.Unity.Bootstrap;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace ComTam.Unity.Views
{
    /// <summary>
    /// Draws the grill doneness bar and reacts to cooking events.
    ///
    /// Every zone boundary is read from the simulation's CookProfile rather than
    /// duplicated in the Inspector, so the bar can never disagree with the rules
    /// the player is actually being judged against.
    /// </summary>
    public sealed class GrillView : MonoBehaviour
    {
        [Header("Bar")]
        [SerializeField] private RectTransform _barRoot;
        [SerializeField] private Image _fill;
        [SerializeField] private RectTransform _perfectZone;
        [SerializeField] private RectTransform _playhead;

        [Header("Readout")]
        [SerializeField] private TMP_Text _stateLabel;
        [SerializeField] private Image _stateIcon;

        [Header("Sprites (four redundant channels - brief section 34)")]
        [SerializeField] private Sprite _iconRaw;
        [SerializeField] private Sprite _iconCooking;
        [SerializeField] private Sprite _iconPerfect;
        [SerializeField] private Sprite _iconOvercooked;
        [SerializeField] private Sprite _iconBurnt;

        [Header("Feedback")]
        [SerializeField] private ParticleSystem _sizzle;
        [SerializeField] private ParticleSystem _smokePuff;

        private static readonly Color ColRaw = new Color(0.98f, 0.80f, 0.82f);
        private static readonly Color ColCooking = new Color(0.96f, 0.65f, 0.25f);
        private static readonly Color ColPerfect = new Color(1.00f, 0.79f, 0.24f);
        private static readonly Color ColOvercooked = new Color(0.90f, 0.44f, 0.32f);
        private static readonly Color ColBurnt = new Color(0.20f, 0.18f, 0.16f);

        private GameHost _host;
        private bool _zoneLaidOut;

        private void Start()
        {
            _host = GameHost.Instance;
            if (_host == null)
            {
                Debug.LogError("[GrillView] no GameHost in the scene");
                enabled = false;
                return;
            }

            _host.Bus.Subscribe<PorkBurnedEvent>(OnBurned);
            _host.Bus.Subscribe<PorkPlacedOnGrillEvent>(OnPlaced);
            LayOutPerfectZone();
        }

        private void OnDestroy()
        {
            if (_host == null) return;
            _host.Bus.Unsubscribe<PorkBurnedEvent>(OnBurned);
            _host.Bus.Unsubscribe<PorkPlacedOnGrillEvent>(OnPlaced);
        }

        /// <summary>
        /// Positions the perfect-zone marker from the CookProfile. Runs once, and
        /// again whenever a grill upgrade changes the windows (Phase 4).
        /// </summary>
        private void LayOutPerfectZone()
        {
            if (_perfectZone == null || _barRoot == null) return;

            CookProfile p = _host.Sim.Grill.Profile;
            if (p.BurntAt <= 0.0) return;

            float width = _barRoot.rect.width;
            float start = (float)(p.PerfectStart / p.BurntAt);
            float end = (float)(p.PerfectEnd / p.BurntAt);

            _perfectZone.anchorMin = new Vector2(start, 0f);
            _perfectZone.anchorMax = new Vector2(end, 1f);
            _perfectZone.offsetMin = Vector2.zero;
            _perfectZone.offsetMax = Vector2.zero;
            _zoneLaidOut = width > 0f;
        }

        private void Update()
        {
            if (_host == null) return;
            if (!_zoneLaidOut) LayOutPerfectZone();

            CookStation grill = _host.Sim.Grill;

            if (!grill.Occupied)
            {
                SetBar(0f);
                Apply(ColRaw, _iconRaw, "");
                if (_sizzle != null && _sizzle.isPlaying) _sizzle.Stop();
                return;
            }

            SetBar((float)grill.Progress01);

            switch (grill.CurrentDoneness)
            {
                case Doneness.Raw: Apply(ColRaw, _iconRaw, "SỐNG"); break;
                case Doneness.Cooking: Apply(ColCooking, _iconCooking, "ĐANG NƯỚNG"); break;
                case Doneness.Perfect: Apply(ColPerfect, _iconPerfect, "VỪA CHÍN!"); break;
                case Doneness.Overcooked: Apply(ColOvercooked, _iconOvercooked, "HƠI QUÁ"); break;
                default: Apply(ColBurnt, _iconBurnt, "CHÁY!"); break;
            }

            if (_sizzle != null && !_sizzle.isPlaying) _sizzle.Play();
        }

        private void SetBar(float t)
        {
            if (_fill != null) _fill.fillAmount = t;
            if (_playhead != null)
            {
                _playhead.anchorMin = new Vector2(t, 0f);
                _playhead.anchorMax = new Vector2(t, 1f);
                _playhead.offsetMin = Vector2.zero;
                _playhead.offsetMax = Vector2.zero;
            }
        }

        private void Apply(Color c, Sprite icon, string label)
        {
            if (_fill != null) _fill.color = c;
            if (_stateIcon != null)
            {
                _stateIcon.sprite = icon;
                _stateIcon.enabled = icon != null;
            }
            if (_stateLabel != null)
            {
                _stateLabel.text = label;
                _stateLabel.color = c;
            }
        }

        private void OnPlaced(PorkPlacedOnGrillEvent _)
        {
            if (_sizzle != null) _sizzle.Play();
        }

        private void OnBurned(PorkBurnedEvent _)
        {
            if (_smokePuff != null) _smokePuff.Play();
            if (_sizzle != null) _sizzle.Stop();
        }

        /// <summary>Hook this to the grill button's OnClick.</summary>
        public void OnGrillTapped()
        {
            if (_host != null) _host.CmdGrillTap();
        }
    }
}
