import KinVaultCore
import SwiftData
import SwiftUI

struct DocumentDetailView: View {
    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @Query private var matches: [VaultDocument]
    @State private var selectedFieldID: UUID?
    @State private var confirmDelete = false

    init(documentID: UUID, initialFieldID: UUID?) {
        _matches = Query(filter: #Predicate<VaultDocument> { $0.id == documentID })
        _selectedFieldID = State(initialValue: initialFieldID)
    }

    var body: some View {
        if let document = matches.first {
            HSplitView {
                PageViewer(document: document, selectedFieldID: $selectedFieldID)
                    .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                DocumentInspector(document: document, selectedFieldID: $selectedFieldID)
                    .frame(minWidth: 300, idealWidth: 340, maxWidth: 420, maxHeight: .infinity)
            }
            .navigationTitle(document.title)
            .navigationSubtitle(document.displayHolder)
            .toolbar {
                ToolbarItemGroup {
                    Button { library.reread(document) } label: {
                        Label("Read Again", systemImage: "arrow.clockwise")
                    }
                    .help("Run OCR and Apple Intelligence on this document again")
                    .disabled(document.state == .reading)

                    Button { NSWorkspace.shared.open(VaultFiles.url(for: document.storedFilename)) } label: {
                        Label("Open Original", systemImage: "arrow.up.forward.app")
                    }
                    .help("Open the original file in Preview")

                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .help("Delete this document")
                }
            }
            .confirmationDialog("Delete “\(document.title)”?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) {
                    dismiss()
                    library.delete(document)
                }
            } message: {
                Text("The original file and everything KinVault read from it are removed from this Mac.")
            }
        } else {
            ContentUnavailableView("Document deleted", systemImage: "trash")
        }
    }
}

// MARK: - Pages

private struct PageViewer: View {
    let document: VaultDocument
    @Binding var selectedFieldID: UUID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView([.vertical]) {
                LazyVStack(spacing: 22) {
                    ForEach(0..<max(document.pageCount, 1), id: \.self) { index in
                        PageView(document: document, page: index, selectedFieldID: $selectedFieldID)
                            .id(index)
                    }
                }
                .padding(28)
            }
            .background(Color(nsColor: .underPageBackgroundColor))
            .onChange(of: selectedFieldID, initial: true) { _, id in
                guard let page = document.fields.first(where: { $0.id == id })?.page else { return }
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(page, anchor: .top) }
            }
        }
    }
}

private struct PageView: View {
    let document: VaultDocument
    let page: Int
    @Binding var selectedFieldID: UUID?
    @State private var image: NSImage?

    private var fields: [DocumentField] {
        document.fields.filter { $0.page == page && $0.box != nil }
    }

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .overlay {
                        GeometryReader { proxy in
                            ForEach(fields) { field in
                                FieldBox(field: field, size: proxy.size, isSelected: field.id == selectedFieldID)
                                    .onTapGesture { selectedFieldID = field.id }
                            }
                        }
                    }
            } else {
                Rectangle()
                    .fill(.background)
                    .aspectRatio(0.75, contentMode: .fit)
                    .overlay { ProgressView() }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
        .frame(maxWidth: 900)
        .task(id: "\(document.storedFilename)-\(page)-\(document.stateRaw)") {
            image = await PageImages.shared.image(page, of: document.storedFilename)
        }
    }
}

private struct FieldBox: View {
    let field: DocumentField
    let size: CGSize
    let isSelected: Bool

    var body: some View {
        if let box = field.box?.padded(0.18) {
            let rect = CGRect(x: box.x * size.width, y: box.y * size.height, width: box.width * size.width, height: box.height * size.height)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.sourceHighlight.opacity(isSelected ? 0.42 : (field.needsReview ? 0.18 : 0.0)))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(
                            isSelected ? Color.orange : (field.needsReview ? Color.orange.opacity(0.7) : Color.accentColor.opacity(0.35)),
                            style: StrokeStyle(lineWidth: isSelected ? 2 : 1, dash: field.needsReview && !isSelected ? [4, 3] : [])
                        )
                )
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .contentShape(Rectangle())
                .help("\(field.label): \(field.value)")
                .animation(.easeOut(duration: 0.18), value: isSelected)
        }
    }
}

// MARK: - Inspector

private struct DocumentInspector: View {
    @Environment(Library.self) private var library
    @Bindable var document: VaultDocument
    @Binding var selectedFieldID: UUID?
    @State private var holderDraft = ""

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    if document.state == .reading {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text(document.progressNote).foregroundStyle(.secondary)
                        }
                    } else if document.state == .failed {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("KinVault couldn’t read this file", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                            if let note = document.note { Text(note).font(.callout).foregroundStyle(.secondary) }
                            Button("Read Again") { library.reread(document) }
                        }
                    }

                    details
                    fieldsSection(proxy: proxy)
                    RecognisedText(lines: document.lines)
                    footer
                }
                .padding(20)
            }
        }
        .background(.background)
        .onAppear { holderDraft = document.holderName }
        .onChange(of: document.holderName) { _, name in holderDraft = name }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            KindIcon(kind: document.kind, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.title2.weight(.semibold))
                    .textSelection(.enabled)
                if !document.summary.isEmpty {
                    Text(document.summary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var details: some View {
        VStack(spacing: 0) {
            KeyValueRow(label: "Person") {
                TextField("Household", text: $holderDraft)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { library.rename(document, holder: holderDraft) }
            }
            KeyValueRow(label: "Type") {
                Picker("Type", selection: $document.kind) {
                    ForEach(DocumentKind.allCases) { Text($0.displayName).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                .onChange(of: document.kindRaw) { library.save() }
            }
            if !document.issuer.isEmpty {
                KeyValueRow(label: "Issued by") { Text(document.issuer).multilineTextAlignment(.trailing) }
            }
            if let issued = document.issueDate {
                KeyValueRow(label: "Issued") { Text(issued, format: .dateTime.day().month(.wide).year()).monospacedDigit() }
            }
            KeyValueRow(label: "Expires", showDivider: false) {
                VStack(alignment: .trailing, spacing: 2) {
                    if let expiry = document.expiryDate {
                        Text(expiry, format: .dateTime.day().month(.wide).year()).monospacedDigit()
                    }
                    ExpiryBadge(status: document.expiry).font(.caption)
                }
            }
        }
    }

    private func fieldsSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(
                title: "Read from the page",
                detail: document.fields.isEmpty ? nil : "\(document.fields.count) details"
            )
            if document.fields.isEmpty && document.state == .ready {
                Text("KinVault didn’t find any labelled details on this document. Try Read Again, or check the recognised text below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 6) {
                ForEach(document.sortedFields) { field in
                    FieldRow(field: field, isSelected: field.id == selectedFieldID)
                        .id(field.id)
                        .onTapGesture { selectedFieldID = field.id }
                }
            }
        }
        .onChange(of: selectedFieldID) { _, id in
            guard let id else { return }
            withAnimation { proxy.scrollTo(id, anchor: .center) }
        }
        .task {
            // Arriving from an answer: wait for layout, then bring the cited detail into view.
            guard let id = selectedFieldID else { return }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation { proxy.scrollTo(id, anchor: .center) }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let note = document.note, document.state == .ready {
                Label(note, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Read by \(document.reader.displayName) and Vision on this Mac")
            Text("Added \(document.importedAt.formatted(date: .long, time: .shortened)) from \(document.originalFilename)")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

struct KeyValueRow<Value: View>: View {
    let label: String
    var showDivider = true
    @ViewBuilder var value: Value

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).foregroundStyle(.secondary)
                Spacer(minLength: 16)
                value
            }
            .padding(.vertical, 9)
            if showDivider { Divider() }
        }
    }
}

private struct FieldRow: View {
    @Environment(Library.self) private var library
    @Bindable var field: DocumentField
    let isSelected: Bool
    @State private var isEditing = false
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(field.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let page = field.page {
                    Text("Page \(page + 1)").font(.caption).foregroundStyle(.tertiary)
                } else {
                    Text("Not found on page").font(.caption).foregroundStyle(.orange)
                }
            }

            if isEditing {
                HStack {
                    TextField(field.label, text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(save)
                    Button("Save", action: save).keyboardShortcut(.defaultAction)
                    Button("Cancel") { isEditing = false }
                }
            } else {
                Text(field.value)
                    .font(.body.monospacedDigit())
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if field.needsReview && !isEditing {
                HStack(spacing: 8) {
                    Label(field.page == nil ? "Check this value" : "Low confidence — check this value", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Correct") { startEditing() }
                    Button("Looks right") { library.confirm(field) }
                }
                .controlSize(.small)
            } else if let original = field.originalValue, !isEditing {
                Text("Corrected by you · read as “\(original)”")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.sourceHighlight.opacity(0.18) : Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Color.orange.opacity(0.6) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy Value") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(field.value, forType: .string)
            }
            Button("Edit Value…") { startEditing() }
            Divider()
            Button("Remove Detail", role: .destructive) { library.remove(field) }
        }
    }

    private func startEditing() {
        draft = field.value
        isEditing = true
    }

    private func save() {
        library.correct(field, to: draft)
        isEditing = false
    }
}

private struct RecognisedText: View {
    let lines: [RecognizedLine]
    @State private var isExpanded = false

    var body: some View {
        if !lines.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                Text(lines.transcript())
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            } label: {
                Text("Recognised text · \(lines.count) lines")
                    .font(.headline)
            }
        }
    }
}
