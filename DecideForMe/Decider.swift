//
//  Decider.swift
//  DecideForMe
//
//  Framework-free, unit-testable decision core. No SwiftUI, no UIKit, no
//  Foundation-UI dependencies — pure logic with an injectable RNG so every
//  branch is deterministically testable.
//

import Foundation

/// Errors the decision core can surface to a caller.
public enum DecideError: Error, Equatable {
    /// Raised when a decision is requested but there are no usable options.
    case noOptions
}

/// A single recorded outcome of a decision.
public struct Decision: Equatable, Identifiable, Codable {
    public let id: UUID
    /// The option that was chosen.
    public let choice: String
    /// The full set of options that were in play at decision time.
    public let options: [String]
    /// When the decision was made.
    public let date: Date

    public init(id: UUID = UUID(), choice: String, options: [String], date: Date = Date()) {
        self.id = id
        self.choice = choice
        self.options = options
        self.date = date
    }
}

/// The decision engine.
///
/// `Decider` owns the list of options and a capped history of past decisions.
/// It is intentionally free of any UI framework so it can be exercised in
/// isolation by `XCTest`. Randomness is injected via any `RandomNumberGenerator`,
/// which makes the "pick" deterministic and therefore testable.
public struct Decider: Equatable {
    // MARK: - Configuration

    /// Maximum number of decisions retained in `history`. Older entries are
    /// evicted (oldest-first) once the cap is exceeded.
    public let historyCap: Int

    // MARK: - State

    /// The current candidate options, in insertion order, de-duplicated and
    /// trimmed of blank entries.
    public private(set) var options: [String]

    /// Past decisions, most-recent-last. Never exceeds `historyCap` elements.
    public private(set) var history: [Decision]

    /// The most recently chosen option, if any. Used to avoid immediate repeats.
    public private(set) var lastChoice: String?

    // MARK: - Init

    /// Create a decider.
    /// - Parameters:
    ///   - options: Initial options. Blank/whitespace-only entries are dropped
    ///     and duplicates are collapsed (first occurrence wins).
    ///   - historyCap: Maximum retained history (clamped to be >= 0).
    public init(options: [String] = [], historyCap: Int = 50) {
        self.historyCap = max(0, historyCap)
        self.options = Decider.sanitize(options)
        history = []
        lastChoice = nil
    }

    // MARK: - Option management

    /// Replace the entire option set (sanitized).
    public mutating func setOptions(_ newOptions: [String]) {
        options = Decider.sanitize(newOptions)
    }

    /// Append an option if it is non-blank and not already present.
    /// - Returns: `true` if the option was added.
    @discardableResult
    public mutating func addOption(_ option: String) -> Bool {
        let trimmed = option.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !options.contains(trimmed) else { return false }
        options.append(trimmed)
        return true
    }

    /// Remove the option at `index` if in range.
    public mutating func removeOption(at index: Int) {
        guard options.indices.contains(index) else { return }
        options.remove(at: index)
    }

    /// Remove all options. Does not touch history.
    public mutating func clearOptions() {
        options.removeAll()
    }

    // MARK: - Deciding

    /// Pick one option at random using the supplied generator.
    ///
    /// Behavior:
    /// - Throws `DecideError.noOptions` if there are zero options.
    /// - With a single option, returns it (a repeat is unavoidable).
    /// - With two or more options, never returns the same value as `lastChoice`
    ///   on consecutive calls (no immediate repeat), as long as an alternative
    ///   exists.
    /// - Records the result into `history`, evicting oldest entries beyond
    ///   `historyCap`, and updates `lastChoice`.
    ///
    /// - Parameters:
    ///   - generator: The randomness source (injected for determinism).
    ///   - date: Timestamp to stamp on the decision (injected for determinism).
    /// - Returns: The `Decision` that was recorded.
    @discardableResult
    public mutating func decide<G: RandomNumberGenerator>(
        using generator: inout G,
        date: Date = Date()
    ) throws -> Decision {
        guard !options.isEmpty else { throw DecideError.noOptions }

        // Candidate pool: exclude the immediately-previous choice when we can
        // still offer an alternative. With one option, the pool is that option.
        var pool = options
        if options.count > 1, let last = lastChoice {
            let filtered = pool.filter { $0 != last }
            if !filtered.isEmpty { pool = filtered }
        }

        let index = Int.random(in: 0 ..< pool.count, using: &generator)
        let choice = pool[index]

        let decision = Decision(choice: choice, options: options, date: date)
        appendToHistory(decision)
        lastChoice = choice
        return decision
    }

    /// Convenience overload using the system RNG. Not used by the test suite
    /// (which injects a seeded generator) but handy for app code.
    @discardableResult
    public mutating func decide(date: Date = Date()) throws -> Decision {
        var system = SystemRandomNumberGenerator()
        return try decide(using: &system, date: date)
    }

    // MARK: - History

    /// Clear recorded history. Leaves `lastChoice` intact so the no-repeat rule
    /// still applies to the next decision.
    public mutating func clearHistory() {
        history.removeAll()
    }

    private mutating func appendToHistory(_ decision: Decision) {
        guard historyCap > 0 else { return }
        history.append(decision)
        if history.count > historyCap {
            history.removeFirst(history.count - historyCap)
        }
    }

    // MARK: - Helpers

    /// Drop blank entries and de-duplicate while preserving order.
    static func sanitize(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for entry in raw {
            let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            result.append(trimmed)
        }
        return result
    }
}

// MARK: - Presets

/// Ready-made option sets the UI can offer with one tap.
public enum DecisionPreset: String, CaseIterable, Identifiable {
    case yesNo
    case coinFlip
    case rockPaperScissors
    case diceD6

    public var id: String {
        rawValue
    }

    /// Human-facing label.
    public var title: String {
        switch self {
        case .yesNo: return "Yes / No"
        case .coinFlip: return "Coin Flip"
        case .rockPaperScissors: return "Rock · Paper · Scissors"
        case .diceD6: return "Roll a D6"
        }
    }

    /// SF Symbol name for the preset chip.
    public var symbol: String {
        switch self {
        case .yesNo: return "checkmark.circle"
        case .coinFlip: return "circle.circle"
        case .rockPaperScissors: return "hand.raised"
        case .diceD6: return "die.face.5"
        }
    }

    /// The options this preset loads.
    public var options: [String] {
        switch self {
        case .yesNo: return ["Yes", "No"]
        case .coinFlip: return ["Heads", "Tails"]
        case .rockPaperScissors: return ["Rock", "Paper", "Scissors"]
        case .diceD6: return ["1", "2", "3", "4", "5", "6"]
        }
    }
}
