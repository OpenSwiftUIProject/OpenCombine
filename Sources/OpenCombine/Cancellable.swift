//
//  Cancellable.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.06.2019.
//

/// A protocol indicating that an activity or action supports cancellation.
///
/// Calling ``Cancellable/cancel()`` frees up any allocated resources. It also stops side
/// effects such as timers, network access, or disk I/O.
public protocol Cancellable {

    /// Cancel the activity.
    ///
    /// When implementing ``Cancellable`` in support of a custom publisher, implement
    /// `cancel()` to request that your publisher stop calling its downstream subscribers.
    /// OpenCombine doesn't require that the publisher stop immediately, but the
    /// `cancel()` call should take effect quickly. Canceling should also eliminate any
    /// strong references it currently holds.
    ///
    /// After you receive one call to `cancel()`, subsequent calls shouldn't do anything.
    /// Additionally, your implementation must be thread-safe, and it shouldn't block the
    /// caller.
    ///
    /// > Tip: Keep in mind that your `cancel()` may execute concurrently with another
    /// call to `cancel()` --- including the scenario where an ``AnyCancellable`` is
    /// deallocating --- or to ``Subscription/request(_:)``.
    func cancel()
}

extension Cancellable {

    /// Stores this cancellable instance in the specified collection.
    ///
    /// - Parameter collection: The collection in which to store this `Cancellable`.
    public func store<Cancellables: RangeReplaceableCollection>(
            in collection: inout Cancellables
    ) where Cancellables.Element == AnyCancellable {
        AnyCancellable(self).store(in: &collection)
    }

    /// Stores this cancellable instance in the specified set.
    ///
    /// - Parameter set: The set in which to store this ``Cancellable``.
    public func store(in set: inout Set<AnyCancellable>) {
        AnyCancellable(self).store(in: &set)
    }
}
