import Foundation

struct CloudFile: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let size: Int64
    let downloadURL: URL
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}