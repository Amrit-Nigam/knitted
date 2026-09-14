import KnitCore
import SwiftUI

/// Pattern, yarn and details, with the Knit button pinned at the bottom.
struct DesignPanel: View {
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PatternPicker()
                    YarnPicker()
                    DetailsSection()
                }
                .padding(20)
            }
            StitchedDivider().padding(.horizontal, 16)
            ApplyBar()
        }
    }
}

private struct DetailsSection: View {
    @Environment(Studio.self) private var studio

    var body: some View {
        @Bindable var studio = studio
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Details")
            Toggle("Ribbed cuff along the pocket", isOn: $studio.design.hasCuff)
                .toggleStyle(.switch)
                .tint(Theme.accent)
                .font(.system(size: 13))
        }
    }
}

private struct ApplyBar: View {
    @Environment(Studio.self) private var studio

    var body: some View {
        let count = studio.staged.count
        VStack(alignment: .leading, spacing: 10) {
            Text("\(studio.design.patternLabel) in \(studio.design.yarnLabel)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.softInk)
                .lineLimit(1)
            Button {
                Task { await studio.apply() }
            } label: {
                if studio.isKnitting {
                    Label("Knitting…", systemImage: "hourglass")
                } else {
                    Label(count == 0 ? "Add folders to knit" : "Knit \(count) Sweater\(count == 1 ? "" : "s")",
                          systemImage: "scissors")
                }
            }
            .buttonStyle(KnitButtonStyle(kind: .primary, fullWidth: true))
            .disabled(count == 0 || studio.isKnitting)
            .help("⌘↩")
        }
        .padding(16)
    }
}
