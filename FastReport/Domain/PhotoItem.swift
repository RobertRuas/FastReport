import Foundation

/// Representação em memória de uma foto no projeto. O ficheiro continua no Finder.
struct PhotoItem: Equatable, Identifiable, Sendable, Hashable {
    let id: UUID
    let fileName: String
    let slotId: String

    init(id: UUID = UUID(), fileName: String, slotId: String) {
        self.id = id
        self.fileName = fileName
        self.slotId = slotId
    }
}
