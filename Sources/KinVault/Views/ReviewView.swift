import KinVaultCore
import SwiftData
import SwiftUI

struct ReviewView: View {
    @Query(sort: \VaultDocument.importedAt, order: .reverse) private var documents: [VaultDocument]

    private var pending: [(VaultDocument, [DocumentField])] {
        documents.compactMap { document in
            let fields = document.sortedFields.filter(\.needsReview)
            return fields.isEmpty ? nil : (document, fields)
        }
    }

    var body: some View {
        Group {
            if pending.isEmpty {
                ContentUnavailableView {
                    Label("Nothing to check", systemImage: "checkmark.circle")
                } description: {
                    Text("Every detail KinVault read was found on the page with high confidence, or you’ve confirmed it.")
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Check these details")
                                .font(.system(size: 28, weight: .bold))
                            Text("KinVault flags a value when OCR confidence is low or the value couldn’t be matched to the page. Unchecked values are still searchable, but answers mark them.")
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(pending, id: \.0.id) { document, fields in
                            VStack(alignment: .leading, spacing: 10) {
                                SectionHeading(title: "\(document.displayHolder) · \(document.title)")
                                ForEach(fields) { field in
                                    ReviewCard(document: document, field: field)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 720, alignment: .leading)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Needs Review")
    }
}

private struct ReviewCard: View {
    @Environment(Library.self) private var library
    @Environment(Navigator.self) private var navigator
    let document: VaultDocument
    @Bindable var field: DocumentField
    @State private var draft = ""

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Group {
                if let page = field.page, let box = field.box {
                    SourceCrop(storedFilename: document.storedFilename, page: page, box: box)
                        .background(.white)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "questionmark.square.dashed").font(.title2)
                        Text("Not found on the page").font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary.opacity(0.5))
                }
            }
            .frame(width: 220, height: 74)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.08)))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(field.label).font(.callout.weight(.medium))
                    Spacer()
                    Text("Confidence \(Int((field.confidence * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                TextField(field.label, text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospacedDigit())
                    .onSubmit(save)
                HStack {
                    Button("Show on Page") { navigator.open(document.id, field: field.id) }
                        .buttonStyle(.link)
                    Spacer()
                    if draft != field.value {
                        Button("Save Correction", action: save).buttonStyle(.borderedProminent)
                    } else {
                        Button("Looks Right") { library.confirm(field) }.buttonStyle(.borderedProminent)
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        .onAppear { draft = field.value }
    }

    private func save() {
        library.correct(field, to: draft)
    }
}
