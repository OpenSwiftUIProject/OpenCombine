# Using OpenCombine for Your App’s Asynchronous Code

Apply common patterns to migrate your closure-based, event-handling code.

## Overview

Your app may use common patterns to handle asynchronous events, such as:

- Completion handlers, in which a caller provides a closure to execute once, after a potentially long-running task completes.
- Closure properties, in which a caller provides a closure to invoke every time a given asynchronous event occurs.

OpenCombine provides compelling equivalents to these patterns, which allow you to eliminate boilerplate implementations, and leverage its many operators. As you adopt OpenCombine elsewhere in your app, converting your asynchronous call points to OpenCombine improves your code’s consistency and readability.

> Tip: You don’t need closure-based asychronicity patterns if you’re using the `async`-`await` features in Swift 5.5 and later. Instead, your code can `await` an asynchronous call, and then execute the code that would have been in the closure. This eliminates the need for both conventional completion handlers and OpenCombine futures. For more information, see Concurrency in *The Swift Programming Language*.

### Replace Completion-Handler Closures with Futures

A completion handler is a closure accepted by a function that executes after the function completes its work. You typically implement this by invoking the completion handler directly when the function finishes its work, storing the closure outside the function if necessary. For example, the following function accepts a closure and then executes it after a two-second delay:

```swift
func performAsyncAction(completionHandler: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline:.now() + 2) {
        completionHandler()
    }
}
```

You can replace this pattern with an OpenCombine ``Future``, a publisher that performs some work and then asynchronously signals success or failure. If it succeeds, the future executes a ``Future/Promise``, a closure that receives the element produced by the future. You can replace the previous function as follows:

```swift
func performAsyncActionAsFuture() -> Future <Void, Never> {
    return Future() { promise in
        DispatchQueue.main.asyncAfter(deadline:.now() + 2) {
            promise(Result.success(()))
        }
    }
}
```

Rather than explicitly invoking a closure when the work completes, the future invokes the promise passed to it, passing in a [Result](https://developer.apple.com/documentation/swift/result) that indicates success or failure. The caller receives this result asynchronously from the future. Because ``Future`` is an OpenCombine ``Publisher``, the caller attaches it to an optional chain of operators, ending with a ``Subscriber``, like ``Publisher/sink(receiveValue:)``:

```swift
cancellable = performAsyncActionAsFuture()
    .sink() { _ in print("Future succeeded.") }
```

### Use Output Types to Represent a Future’s Parameters

Sometimes, a long-running task generates a value that it passes to a completion handler as a parameter. To replicate this functionality in OpenCombine, declare the parameter as the output type published by the future. The following example produces a randomly-generated integer, and passes it to the promise by declaring `Int` as the future’s output type:

```swift
func performAsyncActionAsFutureWithParameter() -> Future <Int, Never> {
    return Future() { promise in
        DispatchQueue.main.asyncAfter(deadline:.now() + 2) {
            let rn = Int.random(in: 1...10)
            promise(Result.success(rn))
        }
    }
}
```

By declaring that the future produces `Int` elements, the future can use the [Result](https://developer.apple.com/documentation/swift/result) type to pass an `Int` value to the promise. When the promise executes, the future publishes the value, which a caller can receive with a subscriber like ``Publisher/sink(receiveValue:)``:

```swift
cancellable = performAsyncActionAsFutureWithParameter()
    .sink() { rn in print("Got random number \(rn).") }
```

### Replace Repeatedly Invoked Closures with Subjects

Your app may also have the common pattern of using a closure as a property to invoke when certain events happen. These properties often have names starting with `on`, and their call points look like the following:

```swift
vc.onDoSomething = { print("Did something.") }
```

With OpenCombine, you can replace this pattern by using a ``Subject``. A subject allows you to imperatively publish a new element at any time by calling the ``Subject/send()`` method. Adopt this pattern by using a `private` ``PassthroughSubject`` or ``CurrentValueSubject``, then expose this publicly as an ``AnyPublisher``:

```swift
private lazy var myDoSomethingSubject = PassthroughSubject<Void, Never>()
lazy var doSomethingSubject = myDoSomethingSubject.eraseToAnyPublisher()
```

With this arrangement, instead of setting a closure property, callers perform their work in a subscriber, such as ``Publisher/sink(receiveValue:)``:

```swift
cancellable = vc.doSomethingSubject
    .sink() { print("Did something with OpenCombine.") }
```

One advantage to using OpenCombine is that the subject can call ``Subject/send(completion:)`` to tell the subscriber that no further events are forthcoming, or that an error occurred.

> Tip: If you are using `async`-`await` concurrency in Swift 5.5 or later, you can use a [AsyncStream](https://developer.apple.com/documentation/swift/asyncstream), instead of an OpenCombine ``Subject``, to asynchronously produce new elements. With this arrangement, the call point performs a `for`-`await`-`in` loop to iterate over the stream rather than subscribing to the subject. The code that would go in the subscriber’s `receiveValue` closure instead becomes the contents of the `for`-`await`-`in` loop.
