import SwiftUI

/// Discreet over-venster met de ralphoei.ai-verwijzing (de lead-funnel). Geen
/// telemetrie of dataverzameling — puur een link (KTD3/KTD7).
struct AboutView: View {
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "versie \(short)"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)

            Text("Fluister")
                .font(.largeTitle.bold())
            Text(version)
                .foregroundStyle(.secondary)

            Text("Lokaal dicteren voor macOS. Je stem en tekst verlaten je Mac niet.")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)

            Divider()

            Text("Gemaakt door ralphoei.ai — AI die voor je werkt.")
                .font(.callout)
            Link("ralphoei.ai openen", destination: URL(string: "https://ralphoei.ai")!)

            Text("Gratis en open source (MIT).")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(28)
        .frame(width: 380)
    }
}
