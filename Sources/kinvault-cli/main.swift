import Foundation
import KinVaultCore

// A command-line front end to KinVaultCore — the same reading and answering engine the app uses.
// Everything runs on this Mac. Output is JSON so scripts and tests can check it.

let usage = """
    Usage:
      kinvault-cli status
      kinvault-cli read <file> [--no-ai] [--text]
      kinvault-cli ask "<question>" <file>... [--no-ai] [--alias "Full Name=Nickname"]...

    Commands:
      status   Whether Apple Intelligence is ready on this Mac.
      read     Read one PDF or image and print what was found, with page positions.
      ask      Read the files, then answer a question from them with citations.

    Options:
      --no-ai    Use the pattern reader instead of Apple Intelligence.
      --text     Include the recognised text in the output of read.
      --alias    Let questions use a nickname, e.g. --alias "Daniel James Rowan=Dad".

    Exit codes: 0 success, 1 bad usage, 2 a file couldn't be read, 3 the answer was not found.
    """

struct Failure: Error {
    var message: String
    var code: Int32
}

// MARK: - Output

func printJSON(_ value: some Encodable) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(value), let text = String(data: data, encoding: .utf8) else { return }
    print(text)
}

struct FieldOutput: Encodable {
    var label: String
    var value: String
    var type: String
    var page: Int?
    var box: PageBox?
    var confidence: Double
    var needsReview: Bool

    init(_ field: LocatedField) {
        label = field.label
        value = field.value
        type = field.type.rawValue
        page = field.page.map { $0 + 1 }
        box = field.box.map { box in
            func round4(_ v: Double) -> Double { (v * 10_000).rounded() / 10_000 }
            return PageBox(x: round4(box.x), y: round4(box.y), width: round4(box.width), height: round4(box.height))
        }
        confidence = (field.confidence * 100).rounded() / 100
        needsReview = field.needsReview
    }
}

struct ReadOutput: Encodable {
    var file: String
    var kind: String
    var title: String
    var holder: String
    var issuer: String
    var issueDate: String?
    var expiryDate: String?
    var expiry: String
    var readBy: String
    var pages: Int
    var lines: Int
    var note: String?
    var fields: [FieldOutput]
    var text: String?
}

struct CitationOutput: Encodable {
    var file: String
    var document: String
    var person: String
    var label: String
    var value: String
    var page: Int?
    var confirmed: Bool
}

struct AskOutput: Encodable {
    var question: String
    var found: Bool
    var answer: String?
    var answeredBy: String
    var citations: [CitationOutput]
    var closestMatches: [CitationOutput]
    var documentsRead: Int
}

struct StatusOutput: Encodable {
    var appleIntelligence: String
    var ready: Bool
    var detail: String
}

// MARK: - Commands

func read(_ path: String, useAI: Bool) async throws -> (URL, DocumentReading) {
    let url = URL(filePath: (path as NSString).expandingTildeInPath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw Failure(message: "No such file: \(path)", code: 2)
    }
    guard PageRenderer.isSupported(url) else {
        throw Failure(message: "\(url.lastPathComponent) isn’t a PDF or image.", code: 2)
    }
    do {
        return (url, try await ReadingPipeline.read(url, useAppleIntelligence: useAI))
    } catch {
        throw Failure(message: "Couldn’t read \(url.lastPathComponent): \(error.localizedDescription)", code: 2)
    }
}

func readOutput(_ url: URL, _ reading: DocumentReading, includeText: Bool) -> ReadOutput {
    let draft = reading.draft
    return ReadOutput(
        file: url.lastPathComponent,
        kind: draft.kind.rawValue,
        title: draft.title,
        holder: draft.holderName,
        issuer: draft.issuer,
        issueDate: draft.issueDate.map(DateReader.isoString),
        expiryDate: draft.expiryDate.map(DateReader.isoString),
        expiry: ExpiryStatus(expiry: draft.expiryDate).phrase,
        readBy: draft.reader.displayName,
        pages: reading.pageCount,
        lines: reading.lines.count,
        note: reading.fallbackReason,
        fields: reading.fields.map(FieldOutput.init),
        text: includeText ? reading.lines.transcript() : nil
    )
}

func run(_ arguments: [String]) async throws {
    var positional: [String] = []
    var useAI = true
    var includeText = false
    var aliases: [String: [String]] = [:]

    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--no-ai": useAI = false
        case "--text": includeText = true
        case "--alias":
            index += 1
            guard index < arguments.count, let split = arguments[index].firstIndex(of: "=") else {
                throw Failure(message: "--alias needs \"Full Name=Nickname\".", code: 1)
            }
            let name = arguments[index][..<split].trimmingCharacters(in: .whitespaces).lowercased()
            let alias = arguments[index][arguments[index].index(after: split)...].trimmingCharacters(in: .whitespaces)
            aliases[name, default: []].append(alias)
        case "-h", "--help", "help":
            print(usage)
            return
        default:
            if argument.hasPrefix("--") { throw Failure(message: "Unknown option \(argument).", code: 1) }
            positional.append(argument)
        }
        index += 1
    }

    guard let command = positional.first else { throw Failure(message: usage, code: 1) }
    let rest = Array(positional.dropFirst())

    switch command {
    case "status":
        let status = OnDeviceModel.status
        printJSON(StatusOutput(appleIntelligence: status.title, ready: status.isReady, detail: status.detail))

    case "read":
        guard rest.count == 1 else { throw Failure(message: "read takes exactly one file.\n\n\(usage)", code: 1) }
        let (url, reading) = try await read(rest[0], useAI: useAI)
        printJSON(readOutput(url, reading, includeText: includeText))

    case "ask":
        guard rest.count >= 2 else { throw Failure(message: "ask needs a question and at least one file.\n\n\(usage)", code: 1) }
        let question = rest[0]
        var facts: [Fact] = []
        var files: [UUID: String] = [:]
        for path in rest.dropFirst() {
            let (url, reading) = try await read(path, useAI: useAI)
            let documentID = UUID()
            files[documentID] = url.lastPathComponent
            for field in reading.fields {
                facts.append(Fact(
                    id: UUID().uuidString, documentID: documentID, fieldID: nil,
                    person: reading.draft.holderName,
                    personAliases: aliases[reading.draft.holderName.lowercased()] ?? [],
                    documentTitle: reading.draft.title, kind: reading.draft.kind,
                    label: field.label, value: field.value, type: field.type,
                    page: field.page, isConfirmed: !field.needsReview
                ))
            }
        }

        let answer = await Answerer.answer(question, facts: facts, useAppleIntelligence: useAI)
        func citation(_ fact: Fact) -> CitationOutput {
            CitationOutput(
                file: files[fact.documentID] ?? "", document: fact.documentTitle, person: fact.person,
                label: fact.label, value: fact.value, page: fact.page.map { $0 + 1 }, confirmed: fact.isConfirmed
            )
        }
        var text: String?
        if case .answered(let value) = answer.outcome { text = value }
        printJSON(AskOutput(
            question: question,
            found: text != nil,
            answer: text,
            answeredBy: text == nil && answer.facts.isEmpty ? "No matching details" : answer.method.displayName,
            citations: text == nil ? [] : answer.facts.map(citation),
            closestMatches: text == nil ? answer.facts.map(citation) : [],
            documentsRead: files.count
        ))
        if text == nil { throw Failure(message: "", code: 3) }

    default:
        throw Failure(message: "Unknown command \(command).\n\n\(usage)", code: 1)
    }
}

do {
    try await run(Array(CommandLine.arguments.dropFirst()))
} catch let failure as Failure {
    if !failure.message.isEmpty { FileHandle.standardError.write(Data((failure.message + "\n").utf8)) }
    exit(failure.code)
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
    exit(2)
}
