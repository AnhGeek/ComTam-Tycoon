using System;
using System.Collections.Generic;
using ComTam.Core.Domain;
using ComTam.Core.Economy;

namespace ComTam.Core.Events
{
    /// <summary>
    /// Minimal in-process pub/sub. Core publishes facts; the presentation layer
    /// subscribes and turns them into animation, audio and haptics.
    ///
    /// Events describe WHAT HAPPENED, never what to render. PorkCooked, not
    /// PlayPerfectAnimation. That keeps the simulation renderer-agnostic.
    /// </summary>
    public sealed class EventBus
    {
        private readonly Dictionary<Type, List<Delegate>> _handlers = new Dictionary<Type, List<Delegate>>();

        public void Subscribe<T>(Action<T> handler)
        {
            if (handler == null) return;
            Type key = typeof(T);
            List<Delegate> list;
            if (!_handlers.TryGetValue(key, out list))
            {
                list = new List<Delegate>();
                _handlers[key] = list;
            }
            list.Add(handler);
        }

        public void Unsubscribe<T>(Action<T> handler)
        {
            if (handler == null) return;
            List<Delegate> list;
            if (_handlers.TryGetValue(typeof(T), out list)) list.Remove(handler);
        }

        public void Publish<T>(T evt)
        {
            List<Delegate> list;
            if (!_handlers.TryGetValue(typeof(T), out list) || list.Count == 0) return;

            // Iterate a snapshot: a handler may subscribe or unsubscribe while
            // reacting, and mutating the live list mid-dispatch would throw.
            Delegate[] snapshot = list.ToArray();
            for (int i = 0; i < snapshot.Length; i++)
            {
                ((Action<T>)snapshot[i])(evt);
            }
        }

        public void Clear() { _handlers.Clear(); }
    }

    public struct CustomerArrivedEvent { public Customer Customer; }
    public struct CustomerOrderedEvent { public Customer Customer; }
    public struct CustomerLeftAngryEvent { public Customer Customer; }
    public struct CustomerFinishedEvent { public Customer Customer; }

    public struct RiceScoopedEvent { public int Quality; }
    public struct PorkPlacedOnGrillEvent { }
    public struct PorkCookedEvent { public Doneness Doneness; public int Quality; }
    public struct PorkBurnedEvent { }

    public struct PlateComponentAddedEvent { public ComponentId Component; public int Quality; }
    public struct PlateReadyEvent { }
    public struct PlateClearedEvent { }

    public struct CustomerServedEvent
    {
        public Customer Customer;
        public int Stars;
        public int PlateQuality;
        public Money Paid;
        public Money Tip;
    }

    public struct ServeRejectedEvent { public string Reason; }

    public struct DayStartedEvent { public int Day; }
    public struct DayEndedEvent { public DayResult Result; }
}
