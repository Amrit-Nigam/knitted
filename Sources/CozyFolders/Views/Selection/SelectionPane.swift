import SwiftUI

/// Where folders arrive: an empty drop zone at first, then the folders waiting to be knitted.
/// The whole pane accepts drops either way.
struct SelectionPane: View {
    @Environment(Studio.self) private var studio
    @State private var dropTargeted = false

    var body: some View {
        Group {
            if studio.staged.isEmpty {
                EmptyDropZone(targeted: dropTargeted)
            } else {
                StagedFoldersView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if dropTargeted && !studio.staged.isEmpty {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Cozy.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10, 9]))
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Cozy.accent.opacity(0.06)))
                    .overlay(alignment: .top) {
                        Label("Add to the basket", systemImage: "plus.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Cozy.accent)
                            .padding(.top, 14)
                    }
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            studio.stage(urls)
            return true
        } isTargeted: { dropTargeted = $0 }
        .animation(.easeOut(duration: 0.15), value: dropTargeted)
    }
}

private struct EmptyDropZone: View {
    @Environment(Studio.self) private var studio
    let targeted: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(targeted ? Cozy.card : Cozy.card.opacity(0.4))
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(targeted ? Cozy.accent : Cozy.stitch,
                              style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10, 9]))

            VStack(spacing: 16) {
                SweaterImage(sweater: studio.previewSweater, pixelSize: 512)
                    .frame(width: 220, height: 220)
                    .scaleEffect(targeted ? 1.06 : 1)
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: targeted)
                VStack(spacing: 6) {
                    Text(targeted ? "Let go to add them" : "Drop folders here")
                        .font(.system(size: 24, weight: .bold))
                    Text("Pick a pattern and yarn, then knit them all at once.\nYou can take a sweater off any time.")
                        .font(.system(size: 13))
                        .foregroundStyle(Cozy.softInk)
                        .multilineTextAlignment(.center)
                }
                Button("Choose Folders…") { studio.chooseFolders() }
                    .buttonStyle(CozyButtonStyle(kind: .primary))
            }
            .padding(30)
        }
        .padding(20)
    }
}

private struct StagedFoldersView: View {
    @Environment(Studio.self) private var studio

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "Ready to knit", subtitle: "\(studio.staged.count) folder\(studio.staged.count == 1 ? "" : "s")")
                Spacer()
                Button("Add Folders…") { studio.chooseFolders() }
                    .buttonStyle(CozyButtonStyle())
                Button("Clear") { studio.clearStaged() }
                    .buttonStyle(CozyButtonStyle())
            }

            if let focused = studio.focused {
                FocusedPreview(folder: focused)
                    .frame(maxWidth: .infinity)
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 12)], spacing: 12) {
                    ForEach(studio.staged) { folder in
                        StagedFolderCard(folder: folder, focused: folder.id == studio.focused?.id)
                    }
                }
                .padding(2)
            }
        }
        .padding(20)
    }
}

private struct FocusedPreview: View {
    @Environment(Studio.self) private var studio
    let folder: StagedFolder

    var body: some View {
        HStack(spacing: 20) {
            SweaterImage(sweater: studio.sweater(forFolderNamed: folder.name), pixelSize: 512)
                .frame(width: 190, height: 190)
                .id(folder.id)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            VStack(alignment: .leading, spacing: 6) {
                Text(folder.name)
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(1)
                Text(folder.url.deletingLastPathComponent().path)
                    .font(.system(size: 12))
                    .foregroundStyle(Cozy.softInk)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    Text("Currently")
                        .font(.system(size: 11))
                        .foregroundStyle(Cozy.softInk)
                    Image(nsImage: NSWorkspace.shared.icon(forFile: folder.url.path))
                        .resizable()
                        .frame(width: 22, height: 22)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Cozy.softInk)
                    SweaterImage(sweater: studio.sweater(forFolderNamed: folder.name), pixelSize: 64)
                        .frame(width: 22, height: 22)
                }
                .padding(.top, 4)
                if folder.isGitRepository {
                    Label("Git repo: add Icon? to .gitignore after knitting", systemImage: "info.circle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Cozy.warning)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Cozy.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Cozy.stitch.opacity(0.45)))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: folder.id)
    }
}

private struct StagedFolderCard: View {
    @Environment(Studio.self) private var studio
    let folder: StagedFolder
    let focused: Bool
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 6) {
            SweaterImage(sweater: studio.sweater(forFolderNamed: folder.name), pixelSize: 160)
                .frame(width: 64, height: 64)
            Text(folder.name)
                .font(.system(size: 11, weight: focused ? .bold : .medium))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(focused ? Cozy.card : Cozy.card.opacity(0.45)))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(focused ? Cozy.accent : Cozy.stitch.opacity(0.45), lineWidth: focused ? 2 : 1)
        )
        .overlay(alignment: .topTrailing) {
            if hovering {
                Button { studio.unstage(folder) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Cozy.ink, Cozy.card)
                }
                .buttonStyle(.plain)
                .help("Remove from the basket")
                .padding(5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { studio.focusedID = folder.id }
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([folder.url]) }
            Button("Remove from Basket") { studio.unstage(folder) }
        }
    }
}
