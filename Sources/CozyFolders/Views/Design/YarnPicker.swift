import KnitCore
import SwiftUI

struct YarnPicker: View {
    @Environment(Studio.self) private var studio

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Yarn")
            LazyVGrid(columns: columns, spacing: 10) {
                tile("Surprise", .surprise) { SurpriseBadge() }
                tile("Wallpaper", .wallpaper) { YarnDots(palette: studio.wallpaperPalette) }
                ForEach(YarnPreset.all) { preset in
                    tile(preset.name, .preset(preset.id)) { YarnDots(palette: preset.palette) }
                }
                tile("Custom", .custom) { YarnDots(palette: studio.design.customPalette) }
            }
            if studio.design.yarn == .custom {
                CustomYarnEditor()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: studio.design.yarn)
    }

    private func tile<Preview: View>(_ title: String, _ choice: YarnChoice, @ViewBuilder preview: @escaping () -> Preview) -> some View {
        ChoiceTile(title: title, selected: studio.design.yarn == choice) {
            studio.design.yarn = choice
        } preview: {
            preview()
        }
    }
}

private struct CustomYarnEditor: View {
    @Environment(Studio.self) private var studio

    var body: some View {
        HStack(spacing: 14) {
            ForEach(Array(["Main", "Second", "Accent"].enumerated()), id: \.offset) { index, label in
                ColorPicker(label, selection: binding(index), supportsOpacity: false)
                    .font(.system(size: 12))
            }
        }
        .padding(.top, 2)
    }

    private func binding(_ index: Int) -> Binding<Color> {
        Binding {
            Color(hex: studio.design.customHexes[index])
        } set: { color in
            studio.design.customHexes[index] = YarnColor(swiftUI: color).hex
        }
    }
}
