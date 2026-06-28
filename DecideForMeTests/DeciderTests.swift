//
//  DeciderTests.swift
//  DecideForMeTests
//
//  Exercises the pure decision core with a deterministic, seedable RNG so
//  every assertion is reproducible.
//

@testable import DecideForMe
import XCTest

/// A small, fully deterministic generator (SplitMix64) for reproducible tests.
/// Seeding it identically yields an identical sequence across runs/platforms.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class DeciderTests: XCTestCase {
    // MARK: - Empty options

    func testEmptyOptionsThrows() {
        var decider = Decider(options: [])
        var rng = SeededGenerator(seed: 1)
        XCTAssertThrowsError(try decider.decide(using: &rng)) { error in
            XCTAssertEqual(error as? DecideError, .noOptions)
        }
        XCTAssertTrue(decider.history.isEmpty, "A failed decision must not record history")
        XCTAssertNil(decider.lastChoice)
    }

    func testWhitespaceOnlyOptionsAreRejectedAsEmpty() {
        var decider = Decider(options: ["", "   ", "\n\t"])
        XCTAssertTrue(decider.options.isEmpty, "Blank options must be sanitized away")
        var rng = SeededGenerator(seed: 1)
        XCTAssertThrowsError(try decider.decide(using: &rng)) { error in
            XCTAssertEqual(error as? DecideError, .noOptions)
        }
    }

    // MARK: - Sanitization

    func testSanitizeTrimsAndDeduplicates() {
        let decider = Decider(options: ["  Pizza ", "Pizza", "Tacos", "  ", "Tacos", "Sushi"])
        XCTAssertEqual(decider.options, ["Pizza", "Tacos", "Sushi"],
                       "Options should be trimmed, de-duplicated, order-preserved")
    }

    // MARK: - Seeded determinism

    func testSeededPickIsDeterministic() throws {
        let options = ["A", "B", "C", "D", "E"]

        var d1 = Decider(options: options)
        var g1 = SeededGenerator(seed: 42)
        let r1 = try d1.decide(using: &g1)

        var d2 = Decider(options: options)
        var g2 = SeededGenerator(seed: 42)
        let r2 = try d2.decide(using: &g2)

        XCTAssertEqual(r1.choice, r2.choice,
                       "Same seed + same options must yield the same choice")
    }

    func testChoiceIsAlwaysAMemberOfOptions() throws {
        let options = ["Red", "Green", "Blue"]
        var decider = Decider(options: options)
        var rng = SeededGenerator(seed: 7)
        for _ in 0 ..< 200 {
            let decision = try decider.decide(using: &rng)
            XCTAssertTrue(options.contains(decision.choice),
                          "Every pick must be one of the supplied options")
        }
    }

    // MARK: - Uniformity (sanity, not a strict statistical test)

    func testPickIsApproximatelyUniform() throws {
        let options = ["A", "B", "C", "D"]
        // Use a fresh decider per draw so the no-immediate-repeat rule does not
        // skew the single-draw distribution.
        var counts: [String: Int] = [:]
        let trials = 8000
        var rng = SeededGenerator(seed: 12345)
        for _ in 0 ..< trials {
            var decider = Decider(options: options)
            let choice = try decider.decide(using: &rng).choice
            counts[choice, default: 0] += 1
        }
        let expected = Double(trials) / Double(options.count)
        for option in options {
            let actual = Double(counts[option, default: 0])
            let deviation = abs(actual - expected) / expected
            XCTAssertLessThan(deviation, 0.15,
                              "\(option): \(counts[option, default: 0]) draws deviates >15% from uniform")
        }
    }

    // MARK: - No immediate repeat

    func testNoImmediateRepeatWithMultipleOptions() throws {
        let options = ["A", "B", "C"]
        var decider = Decider(options: options)
        var rng = SeededGenerator(seed: 99)
        var previous: String?
        for _ in 0 ..< 500 {
            let choice = try decider.decide(using: &rng).choice
            if let previous = previous {
                XCTAssertNotEqual(choice, previous,
                                  "Consecutive decisions must not repeat when alternatives exist")
            }
            previous = choice
        }
    }

    func testSingleOptionRepeatsAreAllowed() throws {
        var decider = Decider(options: ["Only"])
        var rng = SeededGenerator(seed: 3)
        let first = try decider.decide(using: &rng).choice
        let second = try decider.decide(using: &rng).choice
        XCTAssertEqual(first, "Only")
        XCTAssertEqual(second, "Only",
                       "With one option, repeating it is the only possibility")
    }

    func testTwoOptionsAlternateStrictly() throws {
        // With exactly two options the no-repeat rule forces strict alternation.
        var decider = Decider(options: ["Heads", "Tails"])
        var rng = SeededGenerator(seed: 555)
        let sequence = try (0 ..< 10).map { _ in try decider.decide(using: &rng).choice }
        for i in 1 ..< sequence.count {
            XCTAssertNotEqual(sequence[i], sequence[i - 1],
                              "Two-option decisions must strictly alternate")
        }
    }

    // MARK: - History cap

    func testHistoryRecordsDecisions() throws {
        var decider = Decider(options: ["A", "B"], historyCap: 10)
        var rng = SeededGenerator(seed: 1)
        XCTAssertTrue(decider.history.isEmpty)
        _ = try decider.decide(using: &rng)
        _ = try decider.decide(using: &rng)
        XCTAssertEqual(decider.history.count, 2)
        XCTAssertEqual(decider.history.last?.choice, decider.lastChoice)
    }

    func testHistoryIsCappedAndEvictsOldest() throws {
        let cap = 5
        var decider = Decider(options: ["A", "B", "C"], historyCap: cap)
        var rng = SeededGenerator(seed: 2)
        var producedOrder: [Decision] = []
        for _ in 0 ..< 20 {
            try producedOrder.append(decider.decide(using: &rng))
        }
        XCTAssertEqual(decider.history.count, cap,
                       "History must never exceed the cap")
        // The retained window must be the LAST `cap` produced decisions, in order.
        let expectedTail = Array(producedOrder.suffix(cap))
        XCTAssertEqual(decider.history.map { $0.id }, expectedTail.map { $0.id },
                       "History must retain the most-recent `cap` decisions (oldest evicted)")
    }

    func testHistoryCapZeroRecordsNothing() throws {
        var decider = Decider(options: ["A", "B"], historyCap: 0)
        var rng = SeededGenerator(seed: 1)
        _ = try decider.decide(using: &rng)
        _ = try decider.decide(using: &rng)
        XCTAssertTrue(decider.history.isEmpty,
                      "A zero cap must record no history")
        XCTAssertNotNil(decider.lastChoice,
                        "lastChoice should still update even with no history")
    }

    func testNegativeHistoryCapIsClampedToZero() {
        let decider = Decider(options: ["A"], historyCap: -10)
        XCTAssertEqual(decider.historyCap, 0)
    }

    func testClearHistoryEmptiesHistoryButKeepsLastChoice() throws {
        var decider = Decider(options: ["A", "B"], historyCap: 10)
        var rng = SeededGenerator(seed: 1)
        _ = try decider.decide(using: &rng)
        let last = decider.lastChoice
        decider.clearHistory()
        XCTAssertTrue(decider.history.isEmpty)
        XCTAssertEqual(decider.lastChoice, last,
                       "Clearing history must not reset the no-repeat guard")
    }

    // MARK: - Decision snapshot

    func testDecisionCapturesOptionSnapshotAndDate() throws {
        let options = ["A", "B"]
        var decider = Decider(options: options)
        var rng = SeededGenerator(seed: 1)
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let decision = try decider.decide(using: &rng, date: stamp)
        XCTAssertEqual(decision.options, options,
                       "Decision should snapshot the options in play")
        XCTAssertEqual(decision.date, stamp,
                       "Decision should record the injected date")
    }

    // MARK: - Option mutation

    func testAddOptionRejectsBlankAndDuplicate() {
        var decider = Decider(options: ["A"])
        XCTAssertTrue(decider.addOption("B"))
        XCTAssertFalse(decider.addOption("B"), "Duplicates rejected")
        XCTAssertFalse(decider.addOption("   "), "Blank rejected")
        XCTAssertFalse(decider.addOption("  A  "), "Trim-collides with existing")
        XCTAssertEqual(decider.options, ["A", "B"])
    }

    func testRemoveOptionAtIndex() {
        var decider = Decider(options: ["A", "B", "C"])
        decider.removeOption(at: 1)
        XCTAssertEqual(decider.options, ["A", "C"])
        decider.removeOption(at: 99) // out of range — no-op
        XCTAssertEqual(decider.options, ["A", "C"])
    }

    func testSetOptionsReplacesAndSanitizes() {
        var decider = Decider(options: ["A"])
        decider.setOptions(["  X ", "X", "Y"])
        XCTAssertEqual(decider.options, ["X", "Y"])
    }

    func testClearOptionsLeavesHistoryIntact() throws {
        var decider = Decider(options: ["A", "B"], historyCap: 10)
        var rng = SeededGenerator(seed: 1)
        _ = try decider.decide(using: &rng)
        decider.clearOptions()
        XCTAssertTrue(decider.options.isEmpty)
        XCTAssertEqual(decider.history.count, 1, "Clearing options must not wipe history")
    }

    // MARK: - Presets

    func testPresetsProvideNonEmptyOptions() {
        for preset in DecisionPreset.allCases {
            XCTAssertGreaterThanOrEqual(preset.options.count, 2,
                                        "\(preset.rawValue) should offer at least two options")
            XCTAssertFalse(preset.title.isEmpty)
            XCTAssertFalse(preset.symbol.isEmpty)
        }
    }

    func testYesNoPresetLoadsExpectedOptions() {
        XCTAssertEqual(DecisionPreset.yesNo.options, ["Yes", "No"])
    }
}
