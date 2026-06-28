//
//  DeciderViewModel.swift
//  DecideForMe
//
//  Observable bridge between the pure `Decider` core and SwiftUI. All decision
//  logic lives in `Decider`; this layer only manages presentation state
//  (the in-progress text field, the spin animation, the displayed result).
//

import Combine
import Foundation

@MainActor
final class DeciderViewModel: ObservableObject {
    /// The pure decision engine. Kept private; the view talks to published
    /// mirrors below.
    private var decider: Decider

    // MARK: - Published presentation state

    /// Current options, mirrored from the core for the list UI.
    @Published private(set) var options: [String]
    /// Past decisions for the history section (most recent last in the core;
    /// the view reverses for display).
    @Published private(set) var history: [Decision]
    /// The text currently being typed into the "add option" field.
    @Published var draft: String = ""
    /// The currently displayed result label (final or mid-spin).
    @Published private(set) var displayedChoice: String?
    /// Whether the picker is mid-animation.
    @Published private(set) var isSpinning: Bool = false

    /// True when a decision can be made.
    var canDecide: Bool {
        !options.isEmpty && !isSpinning
    }

    init(decider: Decider = Decider(options: ["Yes", "No"], historyCap: 50)) {
        self.decider = decider
        options = decider.options
        history = decider.history
    }

    // MARK: - Option editing

    func addDraftOption() {
        let added = decider.addOption(draft)
        if added {
            draft = ""
            sync()
            Haptics.selection()
        }
    }

    func removeOptions(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            decider.removeOption(at: index)
        }
        sync()
        Haptics.selection()
    }

    func applyPreset(_ preset: DecisionPreset) {
        decider.setOptions(preset.options)
        displayedChoice = nil
        sync()
        Haptics.selection()
    }

    func clearOptions() {
        decider.clearOptions()
        displayedChoice = nil
        sync()
    }

    func clearHistory() {
        decider.clearHistory()
        sync()
    }

    // MARK: - Deciding

    /// Run the spin animation, then commit a real decision from the core.
    ///
    /// The visual spin is cosmetic — it flashes random options to build
    /// suspense. The committed result comes from `Decider.decide`, which is the
    /// only source of truth (and the part covered by tests).
    func decide() {
        guard canDecide else { return }
        isSpinning = true

        // Commit the authoritative decision up front so we always land on it.
        let result: Decision
        do {
            result = try decider.decide()
        } catch {
            isSpinning = false
            return
        }

        let spinFrames = 14
        let snapshot = options
        for frame in 0 ..< spinFrames {
            let delay = Double(frame) * 0.06
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                self.displayedChoice = snapshot.randomElement()
                Haptics.tick()
            }
        }

        // Land on the real result after the spin completes.
        let finishDelay = Double(spinFrames) * 0.06 + 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + finishDelay) { [weak self] in
            guard let self else { return }
            self.displayedChoice = result.choice
            self.isSpinning = false
            self.sync()
            Haptics.success()
        }
    }

    // MARK: - Sync

    private func sync() {
        options = decider.options
        history = decider.history
    }
}
