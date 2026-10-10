import Foundation
import Observation

enum SidebarItem: Hashable {
    case ask
    case all
    case expiring
    case review
    case person(String)
}

struct DocumentRoute: Hashable {
    var documentID: UUID
    var fieldID: UUID?
}

@Observable
final class Navigator {
    var selection: SidebarItem? = .ask {
        didSet { if oldValue != selection { path = [] } }
    }
    var path: [DocumentRoute] = []
    var isImporting = false

    func show(_ item: SidebarItem) {
        selection = item
        path = []
    }

    func open(_ documentID: UUID, field: UUID? = nil) {
        path.append(DocumentRoute(documentID: documentID, fieldID: field))
    }
}
