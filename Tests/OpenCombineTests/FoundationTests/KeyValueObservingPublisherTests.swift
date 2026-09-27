//
//  KeyValueObservingPublisherTests.swift
//

#if canImport(ObjectiveC)

import Foundation
import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
import OpenCombineFoundation
#endif

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class KeyValueObservingPublisherTests: XCTestCase {

    func testPublisherInitializer() {
        let object = TestObject()
        let publisher = NSObject.KeyValueObservingPublisher(
            object: object,
            keyPath: \TestObject.value,
            options: [.new]
        )

        XCTAssertTrue(publisher.object === object)
        XCTAssertEqual(publisher.keyPath, \TestObject.value)
        XCTAssertEqual(publisher.options, [.new])
    }

    func testPublisherPropertiesAndEquality() {
        let object = TestObject()
        let otherObject = TestObject()
        let publisher = makePublisher(object, for: \.value)

        XCTAssertTrue(publisher.object === object)
        XCTAssertEqual(publisher.keyPath, \.value)
        XCTAssertEqual(publisher.options, [.initial, .new])
        XCTAssertEqual(publisher, makePublisher(object, for: \.value))
        XCTAssertNotEqual(publisher, makePublisher(otherObject, for: \.value))
        XCTAssertNotEqual(
            publisher,
            makePublisher(object, for: \.value, options: [.new])
        )
    }

    func testInitialValueWaitsForDemandAndLaterValuesAreDroppedWithoutDemand() {
        let object = TestObject()
        let publisher = makePublisher(object, for: \.value)
        var subscription: Subscription?
        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { subscription = $0 }
        )

        publisher.receive(subscriber: tracking)

        XCTAssertEqual(tracking.subscriptions.count, 1)
        XCTAssertEqual(Array(tracking.inputs), [])

        subscription?.request(.max(1))
        XCTAssertEqual(Array(tracking.inputs), [0])

        object.value = 1
        XCTAssertEqual(Array(tracking.inputs), [0])

        subscription?.request(.max(2))
        object.value = 2
        XCTAssertEqual(Array(tracking.inputs), [0, 2])

        subscription?.cancel()
        object.value = 3
        XCTAssertEqual(Array(tracking.inputs), [0, 2])
    }

    func testAdditionalDemandReturnedByDownstream() {
        let object = TestObject()
        let publisher = makePublisher(object, for: \.value)
        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.max(1)) },
            receiveValue: { _ in .max(1) }
        )

        publisher.receive(subscriber: tracking)
        object.value = 1
        object.value = 2

        XCTAssertEqual(Array(tracking.inputs), [0, 1, 2])
    }

    func testPublisherWithoutInitialOptionUsesDemandForFirstChange() {
        let object = TestObject()
        let publisher = makePublisher(object, for: \.value, options: [.new])
        let tracking = TrackingSubscriberBase<Int, Never>(
            receiveSubscription: { $0.request(.max(2)) }
        )

        publisher.receive(subscriber: tracking)
        XCTAssertEqual(Array(tracking.inputs), [])

        object.value = 1
        XCTAssertEqual(Array(tracking.inputs), [1])
    }

    func testOptionalNilInitialValueIsCached() {
        let object = TestObject()
        let publisher = makePublisher(object, for: \.optionalValue)
        var subscription: Subscription?
        let tracking = TrackingSubscriberBase<String?, Never>(
            receiveSubscription: { subscription = $0 }
        )

        publisher.receive(subscriber: tracking)
        XCTAssertEqual(tracking.history.count, 1)

        subscription?.request(.max(1))
        XCTAssertEqual(tracking.history.count, 2)
        guard case .value(nil) = tracking.history[1] else {
            return XCTFail("Expected the cached nil initial value")
        }
    }

    func testDidChange() {
        let object = TestObject()
        let publisher = makePublisher(object, for: \.value, options: [.new])

        #if OPENCOMBINE_COMPATIBILITY_TEST
        let didChange: Combine.Publishers.Map<
            NSObject.KeyValueObservingPublisher<TestObject, Int>,
            Void
        > = publisher.didChange()
        #else
        let didChange: OpenCombine.Publishers.Map<
            NSObject.KeyValueObservingPublisher<TestObject, Int>,
            Void
        > = publisher.didChange()
        #endif

        let tracking = TrackingSubscriberBase<Void, Never>(
            receiveSubscription: { $0.request(.unlimited) }
        )
        didChange.receive(subscriber: tracking)

        XCTAssertEqual(tracking.inputs.count, 0)

        object.value = 1
        object.value = 2

        XCTAssertEqual(tracking.inputs.count, 2)
    }

    #if !OPENCOMBINE_COMPATIBILITY_TEST
    func testFoundationTypealiases() {
        let object = AliasObject()
        let observableObject: any OpenCombine.ObservableObject = object

        XCTAssertTrue(observableObject is AliasObject)
        XCTAssertEqual(object.value, 0)
    }
    #endif

    private func makePublisher<Value>(
        _ object: TestObject,
        for keyPath: KeyPath<TestObject, Value>,
        options: NSKeyValueObservingOptions = [.initial, .new]
    ) -> NSObject.KeyValueObservingPublisher<TestObject, Value> {
        return object.publisher(for: keyPath, options: options)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private final class TestObject: NSObject {
    @objc dynamic var value = 0
    @objc dynamic var optionalValue: String?
}

#if !OPENCOMBINE_COMPATIBILITY_TEST
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private final class AliasObject: OpenCombineFoundation.ObservableObject {
    @OpenCombineFoundation.Published var value = 0
}
#endif

#endif
