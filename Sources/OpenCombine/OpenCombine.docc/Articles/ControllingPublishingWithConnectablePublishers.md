# Controlling Publishing with Connectable Publishers

Coordinate when publishers start sending elements to subscribers.

## Overview

Sometimes, you want to configure a publisher before it starts producing elements, such as
when a publisher has properties that affect its behavior. But commonly used subscribers
like ``Publisher/sink(receiveValue:)`` demand unlimited elements immediately, which might
prevent you from setting up the publisher the way you like. A publisher that produces
values before you’re ready for them can also be a problem when the publisher has two or
more subscribers. This multi-subscriber scenario creates a race condition: the publisher
can send elements to the first subscriber before the second even exists.

Consider the scenario in the following figure. You create a [URLSession.DataTaskPublisher](https://developer.apple.com/documentation/foundation/urlsession/datataskpublisher) and attach a sink subscriber to it (Subscriber 1) which causes the data task to start fetching the URL’s data. At some later point, you attach a second subscriber (Subscriber 2). If the data task completes its download before the second subscriber attaches, the second subscriber misses the data and only sees the completion.

### Hold Publishing by Using a Connectable Publisher

To prevent a publisher from sending elements before you’re ready, OpenCombine provides the
``ConnectablePublisher`` protocol. A connectable publisher produces no elements until you
call its ``ConnectablePublisher/connect()`` method. Even if it’s ready to produce elements
and has unsatisfied demand, a connectable publisher doesn’t deliver any elements to
subscribers until you explicitly call ``ConnectablePublisher/connect()``.

The following figure shows the [URLSession.DataTaskPublisher](https://developer.apple.com/documentation/foundation/urlsession/datataskpublisher) scenario from above, but with a ``ConnectablePublisher`` ahead of the subscribers. By waiting to call ``ConnectablePublisher/connect()`` until both subscribers attach, the data task doesn’t start downloading until then. This eliminates the race condition and guarantees both subscribers can receive the data.

To use a ``ConnectablePublisher`` in your own OpenCombine code, use the
``Publisher/makeConnectable()`` operator to wrap an existing publisher with a
``Publishers/MakeConnectable`` instance. The following code shows how
``Publisher/makeConnectable()`` fixes the data task publisher race condition described
above. Typically, attaching a sink — identified here by the ``AnyCancellable`` it returns,
`cancellable1` — would cause the data task to start immediately. In this scenario, the
second sink, identified as `cancellable2`, doesn’t attach until one second later, and the
data task publisher might complete before the second sink attaches. Instead, explicitly
using a ``ConnectablePublisher`` causes the data task to start only after the app calls
``ConnectablePublisher/connect()``, which it does after a two-second delay.

```swift
let url = URL(string: "https://example.com/")!
let connectable = URLSession.shared
    .dataTaskPublisher(for: url)
    .map() { $0.data }
    .catch() { _ in Just(Data() )}
    .share()
    .makeConnectable()

cancellable1 = connectable
    .sink(receiveCompletion: { print("Received completion 1: \($0).") },
          receiveValue: { print("Received data 1: \($0.count) bytes.") })

DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    self.cancellable2 = connectable
        .sink(receiveCompletion: { print("Received completion 2: \($0).") },
              receiveValue: { print("Received data 2: \($0.count) bytes.") })
}

DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    self.connection = connectable.connect()
}
```

> Important: ``ConnectablePublisher/connect()`` returns a ``Cancellable`` instance that
you need to retain. You can use this instance to cancel publishing, either by explicitly
calling ``Cancellable/cancel()`` or allowing it to deinitialize.

### Use the Autoconnect Operator If You Don’t Need to Explicitly Connect

Some OpenCombine publishers already implement ``ConnectablePublisher``, such as ``Publishers/Multicast`` and [Timer.TimerPublisher](https://developer.apple.com/documentation/foundation/timer/timerpublisher). Using these publishers can cause the opposite problem: having to explicitly ``ConnectablePublisher/connect()`` could be burdensome if you don’t need to configure the publisher or attach multiple subscribers.

For cases like these, ``ConnectablePublisher`` provides the
``ConnectablePublisher/autoconnect()`` operator. This operator immediately calls
``ConnectablePublisher/connect()`` when a ``Subscriber`` attaches to the publisher with
the ``Publisher/subscribe(_:)-199o9`` method.

The following example uses ``ConnectablePublisher/autoconnect()``, so a subscriber immediately receives elements from a once-a-second [Timer.TimerPublisher](https://developer.apple.com/documentation/foundation/timer/timerpublisher). Without ``ConnectablePublisher/autoconnect()``, the example would need to explicitly start the timer publisher by calling ``ConnectablePublisher/connect()`` at some point.

```swift
let cancellable = Timer.publish(every: 1, on: .main, in: .default)
    .autoconnect()
    .sink() { date in
        print ("Date now: \(date)")
     }
```
