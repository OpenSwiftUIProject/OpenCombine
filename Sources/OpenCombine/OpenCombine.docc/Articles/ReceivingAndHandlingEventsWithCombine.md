# Receiving and Handling Events with OpenCombine

Customize and receive events from asynchronous sources.

## Overview

The OpenCombine framework provides a declarative approach for how your app processes events. Rather than potentially implementing multiple delegate callbacks or completion handler closures, you can create a single processing chain for a given event source. Each part of the chain is an OpenCombine operator that performs a distinct action on the elements received from the previous step.

Consider an app that needs to filter a table or collection view based on the contents of a text field. In AppKit, each keystroke in the text field produces a [Notification](https://developer.apple.com/documentation/foundation/notification) that you can subscribe to with OpenCombine. After receiving the notification, you can use operators to change the content and timing of event delivery, and use the final result to update your app’s user interface.

### Connect a Publisher to a Subscriber

To receive the text field’s notifications with OpenCombine, access the default instance of [NotificationCenter](https://developer.apple.com/documentation/foundation/notificationcenter) and call its [publisher(for:object:)](https://developer.apple.com/documentation/foundation/notificationcenter/publisher(for:object:)) method. This call takes the notification name and source object that you want notifications from, and returns a publisher that produces notification elements.

```swift
let pub = NotificationCenter.default
    .publisher(for: NSControl.textDidChangeNotification, object: filterField)
```

You use a ``Subscriber`` to receive elements from the publisher. The subscriber defines an associated type, ``Subscriber/Input``, to declare the type that it receives. The publisher also defines a type, ``Publisher/Output``, to declare what it produces. The publisher and subscriber both define a type, ``Publisher/Failure``, to indicate the kind of error they produce or receive. To connect a subscriber to a producer, the ``Publisher/Output`` must match the ``Subscriber/Input``, and the ``Publisher/Failure`` types must also match.

OpenCombine provides two built-in subscribers, which automatically match the output and failure types of their attached publisher:

- ``Publisher/sink(receiveCompletion:receiveValue:)`` takes two closures. The first closure executes when it receives ``Subscribers/Completion``, which is an enumeration that indicates whether the publisher finished normally or failed with an error. The second closure executes when it receives an element from the publisher.
- ``Publisher/assign(to:on:)`` immediately assigns every element it receives to a property of a given object, using a key path to indicate the property.

For example, you can use the sink subscriber to log when the publisher completes, and each time it receives an element:

```swift
let sub = NotificationCenter.default
    .publisher(for: NSControl.textDidChangeNotification, object: filterField)
    .sink(receiveCompletion: { print ($0) },
          receiveValue: { print ($0) })
```

Both the `sink(receiveCompletion:receiveValue:)` and ``Publisher/assign(to:on:)`` subscribers request an unlimited number of elements from their publishers. To control the rate at which you receive elements, create your own subscriber by implementing the ``Subscriber`` protocol.

### Change the Output Type with Operators

The sink subscriber in the previous section performs all its work in the `receiveValue` closure. This could be burdensome if it needs to perform a lot of custom work with received elements or maintain state between invocations. The advantage of OpenCombine comes from combining operators to customize event delivery.

For example, the [NotificationCenter.Publisher](https://developer.apple.com/documentation/foundation/notificationcenter/publisher) provided by Foundation’s [NotificationCenter](https://developer.apple.com/documentation/foundation/notificationcenter) uses [Notification](https://developer.apple.com/documentation/foundation/notification) as its ``Publisher/Output`` type. This isn’t a convenient type to receive in the callback if what you need is the text field’s string value.

Since a publisher’s output is essentially a sequence of elements over time, OpenCombine offers sequence-modifying operators like ``Publisher/map(_:)-3bo47``, `flatMap(maxPublishers:_:)`, and ``Publisher/reduce(_:_:)``. The behavior of these operators is similar to their equivalents in the Swift standard library. To change the output type of the publisher, you add a ``Publisher/map(_:)-3bo47`` operator whose closure returns a different type. In this case, you can get the notification’s object as an [NSTextField](https://developer.apple.com/documentation/appkit/nstextfield), and then get the field’s [stringValue](https://developer.apple.com/documentation/appkit/nscontrol/stringvalue).

```swift
let sub = NotificationCenter.default
    .publisher(for: NSControl.textDidChangeNotification, object: filterField)
    .map( { ($0.object as! NSTextField).stringValue } )
    .sink(receiveCompletion: { print ($0) },
          receiveValue: { print ($0) })
```

After the publisher chain produces the type you want, replace `sink(receiveCompletion:receiveValue:)` with ``Publisher/assign(to:on:)``. The following example takes the strings it receives from the publisher chain and assigns them to the `filterString` of a custom view model object:

```swift
let sub = NotificationCenter.default
    .publisher(for: NSControl.textDidChangeNotification, object: filterField)
    .map( { ($0.object as! NSTextField).stringValue } )
    .assign(to: \MyViewModel.filterString, on: myViewModel)
```

### Customize Publishers with Operators

You can extend the ``Publisher`` instance with an operator that performs actions that you’d otherwise need to code manually. Here are three ways you could use operators to improve this event-processing chain:

- Rather than updating the view model with any string typed into the text field, you could use the ``Publisher/filter(_:)`` operator to ignore input under a certain length or to reject non-alphanumeric characters.
- If the filtering operation is expensive — for example, if it’s querying a large database — you might want to wait for the user to stop typing. For this, the ``Publisher/debounce(for:scheduler:options:)`` operator lets you set a minimum period of time that must elapse before a publisher emits an event. The [RunLoop](https://developer.apple.com/documentation/foundation/runloop) class provides conveniences for specifying the time delay in seconds or milliseconds.
- If the results update the UI, you can deliver callbacks to the main thread by calling the ``Publisher/receive(on:options:)`` method. By specifying the ``Scheduler`` instance provided by the [RunLoop](https://developer.apple.com/documentation/foundation/runloop) class as the first parameter, you tell OpenCombine to call your subscriber on the main run loop.

The resulting publisher declaration follows:

```swift
let sub = NotificationCenter.default
    .publisher(for: NSControl.textDidChangeNotification, object: filterField)
    .map( { ($0.object as! NSTextField).stringValue } )
    .filter( { $0.unicodeScalars.allSatisfy({CharacterSet.alphanumerics.contains($0)}) } )
    .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
    .receive(on: RunLoop.main)
    .assign(to:\MyViewModel.filterString, on: myViewModel)
```

### Cancel Publishing when Desired

A publisher continues to emit elements until it completes normally or fails. If you no longer want to subscribe to the publisher, you can cancel the subscription. The subscriber types created by `sink(receiveCompletion:receiveValue:)` and ``Publisher/assign(to:on:)`` both implement the ``Cancellable`` protocol, which provides a ``Cancellable/cancel()`` method:

```swift
sub?.cancel()
```

If you create a custom ``Subscriber``, the publisher sends a ``Subscription`` object when you first subscribe to it. Store this subscription, and then call its ``Cancellable/cancel()`` method when you want to cancel publishing. When you create a custom subscriber, you should implement the ``Cancellable`` protocol, and have your ``Cancellable/cancel()`` implementation forward the call to the stored subscription.
