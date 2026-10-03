import SwiftUI

/// A blocking screen shown when the installed app version is below the minimum
/// required version. The user cannot dismiss it — the only action is to update.
struct ForceUpdateView: View {
    let message: String?
    let appStoreURL: URL?

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            Text("נדרש עדכון")
                .font(.largeTitle.bold())

            Text(message ?? "יצאה גרסה חדשה של האפליקציה. יש לעדכן כדי להמשיך להשתמש.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 480)

            if let appStoreURL {
                Button {
                    openURL(appStoreURL)
                } label: {
                    Text("עדכן עכשיו")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: 280)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}
