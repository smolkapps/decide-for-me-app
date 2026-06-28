//
//  ContentView.swift
//  DecideForMe
//
//  Thin SwiftUI layer over `DeciderViewModel` / `Decider`. No decision logic
//  lives here — only layout, animation, and input plumbing.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var model = DeciderViewModel()
    @FocusState private var draftFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    resultCard
                    decideButton
                    presetRow
                    optionsSection
                    if !model.history.isEmpty {
                        historySection
                    }
                }
                .padding()
            }
            .navigationTitle("Decide For Me")
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: - Result

    private var resultCard: some View {
        VStack(spacing: 8) {
            Text(model.isSpinning ? "Deciding…" : "Result")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(model.displayedChoice ?? "—")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.4)
                .lineLimit(2)
                .scaleEffect(model.isSpinning ? 0.92 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.6),
                           value: model.displayedChoice)
                .frame(maxWidth: .infinity, minHeight: 90)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var decideButton: some View {
        Button {
            draftFocused = false
            model.decide()
        } label: {
            Text(model.isSpinning ? "…" : "Decide")
                .font(.title2.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!model.canDecide)
    }

    // MARK: - Presets

    private var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(DecisionPreset.allCases) { preset in
                    Button {
                        model.applyPreset(preset)
                    } label: {
                        Label(preset.title, systemImage: preset.symbol)
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(.tertiarySystemGroupedBackground)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Options

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Options")
                    .font(.headline)
                Spacer()
                if !model.options.isEmpty {
                    Button("Clear", role: .destructive) { model.clearOptions() }
                        .font(.caption)
                }
            }

            HStack {
                TextField("Add an option…", text: $model.draft)
                    .textFieldStyle(.roundedBorder)
                    .focused($draftFocused)
                    .submitLabel(.done)
                    .onSubmit { model.addDraftOption() }
                Button {
                    model.addDraftOption()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if model.options.isEmpty {
                Text("No options yet. Add some, or tap a preset above.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.options.enumerated()), id: \.offset) { index, option in
                        HStack {
                            Text(option)
                            Spacer()
                            Button {
                                model.removeOptions(at: IndexSet(integer: index))
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 10)
                        if index < model.options.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
                Button("Clear", role: .destructive) { model.clearHistory() }
                    .font(.caption)
            }
            VStack(spacing: 0) {
                // Most recent first for display.
                let recent = Array(model.history.reversed())
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, decision in
                    HStack {
                        Text(decision.choice)
                            .fontWeight(.medium)
                        Spacer()
                        Text(decision.date, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                    if index < recent.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
}

#Preview {
    ContentView()
}
