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
                .tint(Cozy.accent)
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
                .foregroundStyle(Cozy.softInk)
                .lineLimit(1)
            Button {
                studio.apply()
            } label: {
                Label(count == 0 ? "Add folders to knit" : "Knit \(count) Sweater\(count == 1 ? "" : "s")",
                      systemImage: "scissors")
            }
            .buttonStyle(CozyButtonStyle(kind: .primary, fullWidth: true))
            .disabled(count == 0)
            .help("⌘↩")
        }
        .padding(16)
    }
}
