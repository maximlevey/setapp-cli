@testable import SetappCLI
import XCTest

final class SetappAppTests: XCTestCase {
    func testEquality() {
        let lhs = SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 1)
        let rhs = SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 1)
        XCTAssertEqual(lhs, rhs)
    }

    func testInequalityName() {
        let lhs = SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 1)
        let rhs = SetappApp(name: "CleanMyMac", bundleIdentifier: "com.proxyman", identifier: 1)
        XCTAssertNotEqual(lhs, rhs)
    }

    func testInequalityBundleID() {
        let lhs = SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 1)
        let rhs = SetappApp(name: "Proxyman", bundleIdentifier: "com.other", identifier: 1)
        XCTAssertNotEqual(lhs, rhs)
    }

    func testInequalityIdentifier() {
        let lhs = SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 1)
        let rhs = SetappApp(name: "Proxyman", bundleIdentifier: "com.proxyman", identifier: 2)
        XCTAssertNotEqual(lhs, rhs)
    }

    func testComparableLessThan() {
        let first = SetappApp(name: "Bartender", bundleIdentifier: "com.a", identifier: 1)
        let second = SetappApp(name: "Proxyman", bundleIdentifier: "com.b", identifier: 2)
        XCTAssertTrue(first < second)
        XCTAssertFalse(second < first)
    }

    func testComparableCaseInsensitive() {
        let lower = SetappApp(name: "bartender", bundleIdentifier: "com.a", identifier: 1)
        let upper = SetappApp(name: "Proxyman", bundleIdentifier: "com.b", identifier: 2)
        XCTAssertTrue(lower < upper)
    }

    func testSortingArray() {
        let apps = [
            SetappApp(name: "Proxyman", bundleIdentifier: "com.c", identifier: 3),
            SetappApp(name: "Bartender", bundleIdentifier: "com.a", identifier: 1),
            SetappApp(name: "CleanMyMac", bundleIdentifier: "com.b", identifier: 2)
        ]
        let sorted = apps.sorted()
        XCTAssertEqual(sorted.map(\.name), ["Bartender", "CleanMyMac", "Proxyman"])
    }

    func testEqualAppsAreNotLessThan() {
        let lhs = SetappApp(name: "Test", bundleIdentifier: "com.test", identifier: 1)
        let rhs = SetappApp(name: "Test", bundleIdentifier: "com.test", identifier: 1)
        XCTAssertFalse(lhs < rhs)
        XCTAssertFalse(rhs < lhs)
    }
}
