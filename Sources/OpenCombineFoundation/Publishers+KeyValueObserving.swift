// ===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
// ===----------------------------------------------------------------------===//

// This implementation is adapted for OpenCombine from the last publicly
// available Swift.org Darwin Foundation overlay:
// https://github.com/swiftlang/swift/blob/e7cd5ab17f5ce92315f0e23b269628ac2b9369ea/stdlib/public/Darwin/Foundation/Publishers%2BKeyValueObserving.swift
//
// Swift removed the Darwin overlays while adding Xcode 13 support:
// https://github.com/swiftlang/swift/commit/23c3b15f5f2676dd2cfeaabdaf62ae9b49d6faf1
// The API is now supplied by the system Foundation module. Its current Darwin
// implementation is not present in swift-corelibs-foundation or
// swift-foundation; objc4 only exposes runtime facilities used by Foundation's
// KVO implementation.

import Foundation
import OpenCombine

public typealias Published = OpenCombine.Published

public typealias ObservableObject = OpenCombine.ObservableObject

#if canImport(ObjectiveC)

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension NSObject.KeyValueObservingPublisher: OpenCombine.Publisher {

    public typealias Output = Value

    public typealias Failure = Never

    public func receive<Downstream: OpenCombine.Subscriber>(subscriber: Downstream)
        where Downstream.Input == Value, Downstream.Failure == Never
    {
        let subscription = NSObject.KVOSubscription(
            object,
            keyPath,
            options,
            subscriber
        )
        subscriber.receive(subscription: subscription)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension NSObject.KeyValueObservingPublisher {

    /// Returns a publisher that emits a signal when a KVO-compliant property changes.
    public func didChange()
        -> OpenCombine.Publishers.Map<
            NSObject.KeyValueObservingPublisher<Subject, Value>,
            Void
        >
    {
        return map { _ in () }
    }
}

extension NSObject {

    private final class KVOSubscription<Subject: NSObject, Value>: Subscription,
        CustomStringConvertible,
        CustomReflectable,
        CustomPlaygroundDisplayConvertible
    {
        private struct PendingInitial {
            var value: Value
        }

        private var observation: NSKeyValueObservation?
        private var demand = OpenCombine.Subscribers.Demand.none
        private var receivedInitial = false
        private var pendingInitial: PendingInitial?
        private var downstream: OpenCombine.AnySubscriber<Value, Never>?

        private let lock = UnfairLock.allocate()
        private let downstreamLock = UnfairRecursiveLock.allocate()

        fileprivate init<Downstream: OpenCombine.Subscriber>(
            _ object: Subject,
            _ keyPath: KeyPath<Subject, Value>,
            _ options: NSKeyValueObservingOptions,
            _ downstream: Downstream
        ) where Downstream.Input == Value, Downstream.Failure == Never {
            self.downstream = OpenCombine.AnySubscriber(downstream)
            observation = object.observe(
                keyPath,
                options: options
            ) { [weak self] object, _ in
                self?.didChange(
                    to: object[keyPath: keyPath],
                    cachingInitial: options.contains(.initial)
                )
            }
        }

        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }

        fileprivate var description: String {
            return "KVOSubscription"
        }

        fileprivate var customMirror: Mirror {
            lock.lock()
            defer { lock.unlock() }
            return Mirror(self, children: [
                "observation": observation as Any,
                "demand": demand,
            ])
        }

        fileprivate var playgroundDescription: Any {
            return description
        }

        fileprivate func request(_ demand: OpenCombine.Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            guard let downstream = self.downstream else {
                lock.unlock()
                return
            }
            self.demand += demand
            guard self.demand > .none, let initial = pendingInitial.take() else {
                self.demand -= 1
                pendingInitial = nil
                lock.unlock()
                return
            }
            self.demand -= 1
            lock.unlock()

            downstreamLock.lock()
            let additionalDemand = downstream.receive(initial.value)
            downstreamLock.unlock()

            guard additionalDemand > .none else {
                return
            }
            lock.lock()
            if self.downstream != nil {
                self.demand += additionalDemand
            }
            lock.unlock()
        }

        fileprivate func cancel() {
            lock.lock()
            let observation = self.observation.take()
            downstream = nil
            pendingInitial = nil
            lock.unlock()
            observation?.invalidate()
        }

        private func didChange(to value: Value, cachingInitial: Bool) {
            lock.lock()
            let isInitial = cachingInitial && !receivedInitial
            if isInitial {
                receivedInitial = true
            }
            guard demand > .none, let downstream = self.downstream else {
                if isInitial {
                    pendingInitial = PendingInitial(value: value)
                }
                lock.unlock()
                return
            }
            demand -= 1
            lock.unlock()

            downstreamLock.lock()
            let additionalDemand = downstream.receive(value)
            downstreamLock.unlock()

            guard additionalDemand > .none else {
                return
            }
            lock.lock()
            if self.downstream != nil {
                demand += additionalDemand
            }
            lock.unlock()
        }
    }
}

#endif
