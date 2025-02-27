//
//  MapKeyPathTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 08.10.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
final class MapKeyPathTests: XCTestCase {

    func testEmpty() {
        MapTests.testEmpty(valueComparator: ==) {
            $0.map(\.doubled)
        }

        MapTests.testEmpty(valueComparator: ==) {
            $0.map(\.doubled, \.tripled)
        }

        MapTests.testEmpty(valueComparator: ==) {
            $0.map(\.doubled, \.tripled, \.quadrupled)
        }
    }

    func testError() {
        MapTests.testError(valueComparator: ==) {
            $0.map(\.doubled)
        }

        MapTests.testError(valueComparator: ==) {
            $0.map(\.doubled, \.tripled)
        }

        MapTests.testError(valueComparator: ==) {
            $0.map(\.doubled, \.tripled, \.quadrupled)
        }
    }

    func testRange() {
        MapTests.testRange(valueComparator: ==,
                           mapping: { $0.doubled },
                           { $0.map(\.doubled) })

        MapTests.testRange(valueComparator: ==,
                           mapping: { ($0.doubled, $0.tripled) },
                           { $0.map(\.doubled, \.tripled) })

        MapTests.testRange(valueComparator: ==,
                           mapping: { ($0.doubled, $0.tripled, $0.quadrupled) },
                           { $0.map(\.doubled, \.tripled, \.quadrupled) })
    }

    func testNoDemand() {
        MapTests.testNoDemand { $0.map(\.doubled) }
        MapTests.testNoDemand { $0.map(\.doubled, \.tripled) }
        MapTests.testNoDemand { $0.map(\.doubled, \.tripled, \.quadrupled) }
    }

    func testRequestDemandOnSubscribe() {
        MapTests.testRequestDemandOnSubscribe {
            $0.map(\.doubled)
        }

        MapTests.testRequestDemandOnSubscribe {
            $0.map(\.doubled, \.tripled)
        }

        MapTests.testRequestDemandOnSubscribe {
            $0.map(\.doubled, \.tripled, \.quadrupled)
        }
    }

    func testDemandOnReceive() {
        MapTests.testDemandOnReceive { $0.map(\.doubled) }
        MapTests.testDemandOnReceive { $0.map(\.doubled, \.tripled) }
        MapTests.testDemandOnReceive { $0.map(\.doubled, \.tripled, \.quadrupled) }
    }

    func testCompletion() {
        MapTests.testCompletion(valueComparator: ==) {
            $0.map(\.doubled)
        }

        MapTests.testCompletion(valueComparator: ==) {
            $0.map(\.doubled, \.tripled)
        }

        MapTests.testCompletion(valueComparator: ==) {
            $0.map(\.doubled, \.tripled, \.quadrupled)
        }
    }

    func testCancel() throws {
        try MapTests.testCancel { $0.map(\.doubled) }
        try MapTests.testCancel { $0.map(\.doubled, \.tripled) }
        try MapTests.testCancel { $0.map(\.doubled, \.tripled, \.quadrupled) }
    }

    func testCancelAlreadyCancelled() throws {
        try MapTests.testCancelAlreadyCancelled {
            $0.map(\.doubled)
        }

        try MapTests.testCancelAlreadyCancelled {
            $0.map(\.doubled, \.tripled)
        }

        try MapTests.testCancelAlreadyCancelled {
            $0.map(\.doubled, \.tripled, \.quadrupled)
        }
    }

    #if Xcode
    func testMapKeyPathReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Never.self,
                           description: "ValueForKey",
                           customMirror: expectedChildren(
                               ("keyPath", .matches(#"\Int.doubled"#))
                           ),
                           playgroundDescription: "ValueForKey",
                           subscriberIsAlsoSubscription: false,
                           { $0.map(\.doubled) })

        try testReflection(parentInput: Int.self,
                           parentFailure: Never.self,
                           description: "ValueForKeys",
                           customMirror: expectedChildren(
                               ("keyPath0", .matches(#"\Int.doubled"#)),
                               ("keyPath1", .matches(#"\Int.tripled"#))
                           ),
                           playgroundDescription: "ValueForKeys",
                           subscriberIsAlsoSubscription: false,
                           { $0.map(\.doubled, \.tripled) })

        try testReflection(parentInput: Int.self,
                           parentFailure: Never.self,
                           description: "ValueForKeys",
                           customMirror: expectedChildren(
                               ("keyPath0", .matches(#"\Int.doubled"#)),
                               ("keyPath1", .matches(#"\Int.tripled"#)),
                               ("keyPath2", .matches(#"\Int.quadrupled"#))
                           ),
                           playgroundDescription: "ValueForKeys",
                           subscriberIsAlsoSubscription: false,
                           { $0.map(\.doubled, \.tripled, \.quadrupled) })
    }
    #else
    // on Swift 5.8 + non-Xcode env, the result will sometimes be "\Int.<computed 0x00007ff62fe3b2c0 (Int)>" and sometimes be "\Int.doubled"
    func testMapKeyPathReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: Never.self,
                           description: "ValueForKey",
                           customMirror: expectedChildren(
                               ("keyPath", .contains(#"\Int."#))
                           ),
                           playgroundDescription: "ValueForKey",
                           subscriberIsAlsoSubscription: false,
                           { $0.map(\.doubled) })

        try testReflection(parentInput: Int.self,
                           parentFailure: Never.self,
                           description: "ValueForKeys",
                           customMirror: expectedChildren(
                               ("keyPath0", .contains(#"\Int."#)),
                               ("keyPath1", .contains(#"\Int."#))
                           ),
                           playgroundDescription: "ValueForKeys",
                           subscriberIsAlsoSubscription: false,
                           { $0.map(\.doubled, \.tripled) })

        try testReflection(parentInput: Int.self,
                           parentFailure: Never.self,
                           description: "ValueForKeys",
                           customMirror: expectedChildren(
                               ("keyPath0", .contains(#"\Int."#)),
                               ("keyPath1", .contains(#"\Int."#)),
                               ("keyPath2", .contains(#"\Int."#))
                           ),
                           playgroundDescription: "ValueForKeys",
                           subscriberIsAlsoSubscription: false,
                           { $0.map(\.doubled, \.tripled, \.quadrupled) })
    }
    #endif

    func testMapKeyPathReceiveValueBeforeSubscription() {
        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([.value(0)],
                                                              demand: .max(42)),
                                           { $0.map(\.doubled) })

        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([.value((0, 0))],
                                                              demand: .max(42),
                                                              comparator: ==),
                                           { $0.map(\.doubled, \.tripled) })

        testReceiveValueBeforeSubscription(value: 0,
                                           expected: .history([.value((0, 0, 0))],
                                                              demand: .max(42),
                                                              comparator: ==),
                                           { $0.map(\.doubled, \.tripled, \.quadrupled) })
    }

    func testMapKeyPathReceiveCompletionBeforeSubscription() {
        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.completion(.finished)]),
            { $0.map(\.doubled) }
        )

        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.completion(.finished)], comparator: ==),
            { $0.map(\.doubled, \.tripled) }
        )

        testReceiveCompletionBeforeSubscription(
            inputType: Int.self,
            expected: .history([.completion(.finished)], comparator: ==),
            { $0.map(\.doubled, \.tripled, \.quadrupled) }
        )
    }

    func testMapKeyPathLifecycle() throws {
        try testLifecycle(sendValue: 31, cancellingSubscriptionReleasesSubscriber: true) {
            $0.map(\.doubled)
        }

        try testLifecycle(sendValue: 31, cancellingSubscriptionReleasesSubscriber: true) {
            $0.map(\.doubled, \.tripled)
        }

        try testLifecycle(sendValue: 31, cancellingSubscriptionReleasesSubscriber: true) {
            $0.map(\.doubled, \.tripled, \.quadrupled)
        }
    }
}

extension Int {
    fileprivate var doubled: Int { return self * 2 }

    fileprivate var tripled: Int { return self * 3 }

    fileprivate var quadrupled: Int { return self * 4 }
}
