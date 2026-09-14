import SwiftUI

/// The whole window, wrapped edge to edge in a knitted frame: the folder side on the left,
/// the design side on the right.
struct RootView: View {
    @Environment(Studio.self) private var studio

    var body: some View {
        KnittedFrame(sweater: studio.previewSweater, thickness: 18, cornerRadius: 14, bleed: 4) {
            VStack(spacing: 0) {
                // Title row, sharing its height with the traffic lights.
                Text("Cozy Folders")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Cozy.softInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                StitchedDivider().padding(.horizontal, 16)

                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        SelectionPane()
                        if !studio.wardrobe.isEmpty {
                            StitchedDivider().padding(.horizontal, 20)
                            WardrobeShelf()
                        }
                    }
                    StitchedDivider(vertical: true).padding(.vertical, 20)
                    DesignPanel()
                        .frame(width: 350)
                }
            }
            .background(Cozy.paper)
        }
        .overlay(alignment: .bottom) {
            if let toast = studio.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 44)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(toast.id)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: studio.toast)
        .ignoresSafeArea()
        .knittedWindowChrome(trafficLightOffset: CGSize(width: 12, height: 10))
        .foregroundStyle(Cozy.ink)
        .fontDesign(.rounded)
        .preferredColorScheme(.light)
    }
}
