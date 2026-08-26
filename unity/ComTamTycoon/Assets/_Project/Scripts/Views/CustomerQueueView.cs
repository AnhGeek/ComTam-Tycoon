using System.Collections.Generic;
using ComTam.Core.Domain;
using ComTam.Core.Events;
using ComTam.Unity.Bootstrap;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

namespace ComTam.Unity.Views
{
    /// <summary>One queue slot: portrait, mood face, patience ring, order ticket.</summary>
    public sealed class CustomerSlotView : MonoBehaviour
    {
        [SerializeField] private GameObject _root;
        [SerializeField] private Image _portrait;
        [SerializeField] private Image _moodFace;
        [SerializeField] private Image _patienceRing;
        [SerializeField] private TMP_Text _nameLabel;
        [SerializeField] private GameObject _orderTicket;

        [Header("Mood sprites")]
        [SerializeField] private Sprite _faceHappy;
        [SerializeField] private Sprite _faceNormal;
        [SerializeField] private Sprite _faceImpatient;
        [SerializeField] private Sprite _faceAngry;
        [SerializeField] private Sprite _faceEating;

        private static readonly Color RingHappy = new Color(0.42f, 0.60f, 0.31f);
        private static readonly Color RingNormal = new Color(1.00f, 0.79f, 0.24f);
        private static readonly Color RingImpatient = new Color(0.96f, 0.65f, 0.25f);
        private static readonly Color RingAngry = new Color(0.90f, 0.44f, 0.32f);

        public void Clear()
        {
            if (_root != null) _root.SetActive(false);
        }

        public void Bind(Customer c)
        {
            if (_root != null) _root.SetActive(true);
            if (_nameLabel != null) _nameLabel.text = c.Name;

            bool waiting = c.State == CustomerState.WaitingForFood;
            bool eating = c.State == CustomerState.Eating
                          || c.State == CustomerState.ReceivingFood;

            if (_orderTicket != null) _orderTicket.SetActive(waiting);

            if (_patienceRing != null)
            {
                _patienceRing.enabled = waiting;
                _patienceRing.fillAmount = (float)c.Patience01;
                _patienceRing.color = RingColour(c.Mood);
            }

            if (_moodFace != null)
                _moodFace.sprite = eating ? _faceEating : FaceFor(c.Mood);
        }

        private Sprite FaceFor(CustomerMood mood)
        {
            switch (mood)
            {
                case CustomerMood.Happy: return _faceHappy;
                case CustomerMood.Normal: return _faceNormal;
                case CustomerMood.Impatient: return _faceImpatient;
                default: return _faceAngry;
            }
        }

        private static Color RingColour(CustomerMood mood)
        {
            switch (mood)
            {
                case CustomerMood.Happy: return RingHappy;
                case CustomerMood.Normal: return RingNormal;
                case CustomerMood.Impatient: return RingImpatient;
                default: return RingAngry;
            }
        }
    }

    /// <summary>
    /// Binds the simulation's queue slots to fixed on-screen positions.
    ///
    /// Slots are pre-placed in the scene and reused rather than instantiated -
    /// portrait screens only ever show three (ADR-0002), so pooling here is
    /// trivial and there is no reason to ever allocate at runtime.
    /// </summary>
    public sealed class CustomerQueueView : MonoBehaviour
    {
        [SerializeField] private CustomerSlotView[] _slots = new CustomerSlotView[3];
        [SerializeField] private GameObject _overflowBadge;
        [SerializeField] private TMP_Text _overflowLabel;

        private GameHost _host;
        private readonly List<Customer> _visible = new List<Customer>(4);

        private void Start()
        {
            _host = GameHost.Instance;
            if (_host == null)
            {
                Debug.LogError("[CustomerQueueView] no GameHost in the scene");
                enabled = false;
            }
        }

        private void Update()
        {
            if (_host == null) return;

            _visible.Clear();
            IReadOnlyList<Customer> all = _host.Sim.Customers;
            for (int i = 0; i < all.Count; i++)
            {
                Customer c = all[i];
                if (c.QueueSlot >= 0 && c.IsActive) _visible.Add(c);
            }

            for (int i = 0; i < _slots.Length; i++)
            {
                if (_slots[i] == null) continue;
                if (i < _visible.Count) _slots[i].Bind(_visible[i]);
                else _slots[i].Clear();
            }

            int overflow = _visible.Count - _slots.Length;
            if (_overflowBadge != null) _overflowBadge.SetActive(overflow > 0);
            if (_overflowLabel != null && overflow > 0) _overflowLabel.text = "+" + overflow;
        }
    }
}
