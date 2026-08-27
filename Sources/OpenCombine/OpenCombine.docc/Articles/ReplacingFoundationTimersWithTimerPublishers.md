# Replacing Foundation Timers with Timer Publishers

Publish elements periodically by using a timer.

## Overview

If your app uses Foundation’s [Timer](https://developer.apple.com/documentation/foundation/timer) class to repeatedly receive a callback or invoke a closure on a specified interval, you can convert these instances to OpenCombine to simplify your code.

### Performing Periodic Work with a Timer

Consider the following snippet, which uses [scheduledTimer(withTimeInterval:repeats:block:)](https://developer.apple.com/documentation/foundation/timer/scheduledtimer(withtimeinterval:repeats:block:)) to update the `lastUpdated` property of a data model once a second, on a specific dispatch queue:

```swift
var timer: Timer?
override func viewDidLoad() {
    super.viewDidLoad()
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
        self.myDispatchQueue.async() {
            self.myDataModel.lastUpdated = Date()
        }
    }
}
```

### Converting to a Timer Publisher

To migrate this code to OpenCombine, replace the [Timer](https://developer.apple.com/documentation/foundation/timer) that is returned by [scheduledTimer(withTimeInterval:repeats:block:)](https://developer.apple.com/documentation/foundation/timer/scheduledtimer(withtimeinterval:repeats:block:)) with a [Timer.TimerPublisher](https://developer.apple.com/documentation/foundation/timer/timerpublisher). You create this publisher with the [Timer](https://developer.apple.com/documentation/foundation/timer) method [publish(every:tolerance:on:in:options:)](https://developer.apple.com/documentation/foundation/timer/publish(every:tolerance:on:in:options:)). Every time the underyling [Timer](https://developer.apple.com/documentation/foundation/timer) fires, the publisher emits a new [Date](https://developer.apple.com/documentation/foundation/date) that represents the instant the timer fired. You then apply OpenCombine operators to the [Date](https://developer.apple.com/documentation/foundation/date), eventually connecting the publisher to a subscriber like ``Publisher/sink(receiveValue:)`` or ``Publisher/assign(to:on:)``.

> Tip: Because [Timer.TimerPublisher](https://developer.apple.com/documentation/foundation/timer/timerpublisher) conforms to the ``ConnectablePublisher`` protocol, it won’t produce elements until you explicitly connect to it. Do this by either calling ``ConnectablePublisher/connect()``, or using an ``ConnectablePublisher/autoconnect()`` operator to connect automatically when a subscriber attaches.

The next example shows how to use a [Timer.TimerPublisher](https://developer.apple.com/documentation/foundation/timer/timerpublisher) to replace the previous example. It uses OpenCombine’s operators to perform the tasks that were in the previous example’s closure:

```swift
var cancellable: Cancellable?
override func viewDidLoad() {
    super.viewDidLoad()
    cancellable = Timer.publish(every: 1, on: .main, in: .default)
        .autoconnect()
        .receive(on: myDispatchQueue)
        .assign(to: \.lastUpdated, on: myDataModel)
}
```

In this example, OpenCombine operators replace all the behavior inside the closure of the earlier example:

- The ``Publisher/receive(on:options:)`` operator ensures that its subsequent operators run on the specified dispatch queue. This replaces the `async()` call from before.
- The ``Publisher/assign(to:on:)`` operator updates the data model, by using a key path to set the `lastUpdate` property.

Another advantage you’ll find when using OpenCombine to simplify your code is that the [Timer.TimerPublisher](https://developer.apple.com/documentation/foundation/timer/timerpublisher) produces new [Date](https://developer.apple.com/documentation/foundation/date) instances as its output type. The first example’s closure receives the [Timer](https://developer.apple.com/documentation/foundation/timer) itself as its parameter, so it has to create new [Date](https://developer.apple.com/documentation/foundation/date) instances manually.
