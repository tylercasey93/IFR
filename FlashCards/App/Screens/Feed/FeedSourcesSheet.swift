// App/Screens/Feed/FeedSourcesSheet.swift
import SwiftUI

/// The grounding for one lesson: its Instrument Rating ACS task code(s) and
/// the governing FAA source, mirroring the end card baked into the video.
struct FeedSourcesSheet: View {
    let lesson: FeedLesson
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("SOURCES").placard()
                Spacer()
                Button("Done") { dismiss() }
                    .accessibilityIdentifier("feedSourcesDone")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("INSTRUMENT RATING ACS (FAA-S-ACS-8C)").placard()
                Text(lesson.references.acs.joined(separator: " · "))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .instrumentPanel()

            VStack(alignment: .leading, spacing: 6) {
                Text("FAA REFERENCE").placard()
                Text(lesson.references.faa.source)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Text(lesson.references.faa.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .instrumentPanel()

            Text("Study aid — always verify against current FAA publications.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
        .presentationBackground(.regularMaterial)
    }
}
