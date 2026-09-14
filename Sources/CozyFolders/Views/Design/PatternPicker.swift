import KnitCore
import SwiftUI

struct PatternPicker: View {
    @Environment(Studio.self) private var studio

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 10)]

    var body: some View {
        let palette = studio.sweater(forFolderNamed: studio.previewName).palette
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Pattern")
            LazyVGrid(columns: columns, spacing: 10) {
                ChoiceTile(title: "Surprise", selected: studio.design.pattern == .surprise) {
                    studio.design.pattern = .surprise
                } preview: {
                    SurpriseBadge()
                }
            }
            ForEach(PatternID.Family.allCases, id: \.self) { family in
                VStack(alignment: .leading, spacing: 8) {
                    Text(family.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Cozy.softInk)
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(PatternID.allCases.filter { $0.family == family }, id: \.self) { pattern in
                            ChoiceTile(title: pattern.displayName, selected: studio.design.pattern == .pattern(pattern)) {
                                studio.design.pattern = .pattern(pattern)
                            } preview: {
                                SwatchThumbnail(pattern: pattern, palette: palette)
                            }
                        }
                    }
                }
            }
        }
    }
}
