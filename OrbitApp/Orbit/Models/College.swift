import Foundation

/// A selectable college from GET /colleges. The backend owns the list;
/// coordinates are used server-side for distance filtering.
struct College: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let lat: Double
    let lng: Double
}
