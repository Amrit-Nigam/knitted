import AppKit
import SwiftUI

/// Folders already wearing sweaters: change them, reveal them, or take the sweater off.
struct WardrobeShelf: View {
    @Environment(Studio.self) private var studio

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Wearing sweaters", subtitle: "\(studio.wardrobe.count)")
                Spacer()
                Button("Change All") { studio.restage(studio.wardrobe) }
                    .buttonStyle(KnitButtonStyle())
                    .help("Put every knitted folder back in the basket to pick a new sweater")
                Button("Take All Off") { studio.unknitAll() }
                    .buttonStyle(KnitButtonStyle())
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(studio.wardrobe) { folder in
                        WardrobeItem(folder: folder)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 76)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

private struct WardrobeItem: View {
    @Environment(Studio.self) private var studio
    let folder: KnittedFolder
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: folder.path))
                .resizable()
                .frame(width: 50, height: 50)
                .overlay(alignment: .topTrailing) {
                    if hovering {
                        Button { studio.unknit(folder) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.ink, Theme.card)
                        }
                        .buttonStyle(.plain)
                        .help("Take the sweater off")
                        .offset(x: 6, y: -4)
                    }
                }
            Text(folder.name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: 76)
        }
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { studio.restage([folder]) }
        .help("\(folder.path)\nDouble-click to change its sweater")
        .contextMenu {
            Button("Change Sweater") { studio.restage([folder]) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([folder.url]) }
            Divider()
            Button("Take Sweater Off") { studio.unknit(folder) }
        }
    }
}
