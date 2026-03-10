//
//  VoyageViewModel.swift
//  Orbit
//
//  Manages tile loading, position tracking, and heartbeat for Voyage mode.
//

import SwiftUI
import Combine

@MainActor
class VoyageViewModel: ObservableObject {

    // MARK: - Published State

    /// Cumulative pan offset from origin (0,0) in points.
    @Published var voyagePosition: CGPoint = .zero

    /// Currently loaded tiles keyed by "x,y".
    @Published var loadedTiles: [String: VoyageTile] = [:]

    /// Set of tile keys currently being fetched.
    @Published var loadingTileKeys: Set<String> = []

    /// Whether the initial cluster fetch is in progress.
    @Published var isLoading = false

    /// Current drag velocity for warp-speed effect.
    @Published var dragVelocity: CGSize = .zero

    // MARK: - Constants

    let tileSize: CGFloat = 600

    /// Max tiles held in memory at once.
    private let maxTilesInMemory = 25

    // MARK: - Private

    private var heartbeatTask: Task<Void, Never>?

    // MARK: - Tile Coordinate Helpers

    /// The tile coordinate the viewport center is currently in.
    var currentTileX: Int {
        Int(floor(-voyagePosition.x / tileSize))
    }

    var currentTileY: Int {
        Int(floor(-voyagePosition.y / tileSize))
    }

    /// Distance from origin in tile units.
    var distanceFromHome: CGFloat {
        hypot(voyagePosition.x / tileSize, voyagePosition.y / tileSize)
    }

    /// Angle from current position back toward origin (radians).
    var homeAngle: CGFloat {
        atan2(-voyagePosition.y, -voyagePosition.x)
    }

    // MARK: - Lifecycle

    func startVoyage() async {
        isLoading = true
        defer { isLoading = false }

        // Load initial region
        await fetchTilesAround(x: 0, y: 0)

        // Start heartbeat timer
        startHeartbeat()
    }

    func endVoyage() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        Task {
            try? await VoyageService.shared.endVoyage()
        }
    }

    // MARK: - Panning

    func updatePosition(translation: CGSize) {
        voyagePosition.x += translation.width
        voyagePosition.y += translation.height

        // Check if we need to load new tiles
        Task {
            await fetchTilesAround(x: currentTileX, y: currentTileY)
        }

        // Evict far-away tiles to stay under memory limit
        evictDistantTiles()
    }

    // MARK: - Tile Loading

    func fetchTilesAround(x: Int, y: Int) async {
        // Check which tiles in the 5x5 region we don't have yet
        var needsFetch = false
        for dx in -2...2 {
            for dy in -2...2 {
                let key = "\(x + dx),\(y + dy)"
                if loadedTiles[key] == nil && !loadingTileKeys.contains(key) {
                    needsFetch = true
                    break
                }
            }
            if needsFetch { break }
        }

        guard needsFetch else { return }

        // Mark the region as loading
        for dx in -2...2 {
            for dy in -2...2 {
                loadingTileKeys.insert("\(x + dx),\(y + dy)")
            }
        }

        do {
            let tiles = try await VoyageService.shared.fetchClusters(x: x, y: y, radius: 2)
            for tile in tiles {
                let key = "\(tile.x),\(tile.y)"
                loadedTiles[key] = tile
                loadingTileKeys.remove(key)
            }
        } catch {
            // Remove loading state on failure so retry is possible
            for dx in -2...2 {
                for dy in -2...2 {
                    loadingTileKeys.remove("\(x + dx),\(y + dy)")
                }
            }
        }
    }

    // MARK: - Memory Management

    private func evictDistantTiles() {
        guard loadedTiles.count > maxTilesInMemory else { return }

        let cx = currentTileX
        let cy = currentTileY

        // Sort tiles by distance from current position, evict farthest
        let sorted = loadedTiles.sorted { a, b in
            let aParts = a.key.split(separator: ",").compactMap { Int($0) }
            let bParts = b.key.split(separator: ",").compactMap { Int($0) }
            guard aParts.count == 2, bParts.count == 2 else { return false }
            let aDist = abs(aParts[0] - cx) + abs(aParts[1] - cy)
            let bDist = abs(bParts[0] - cx) + abs(bParts[1] - cy)
            return aDist > bDist
        }

        let toRemove = sorted.prefix(loadedTiles.count - maxTilesInMemory)
        for (key, _) in toRemove {
            loadedTiles.removeValue(forKey: key)
        }
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                try? await VoyageService.shared.sendHeartbeat(
                    tileX: currentTileX, tileY: currentTileY
                )
            }
        }
    }

    // MARK: - Seeded Layout Helpers

    /// Generate deterministic scatter positions for items within a tile.
    /// Returns positions as fractions (0...1) of tile size.
    static func scatterPositions(tileX: Int, tileY: Int, count: Int) -> [CGPoint] {
        var seed = UInt64(abs(tileX &* 73856093 ^ tileY &* 19349663))
        var positions: [CGPoint] = []

        func nextRandom() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((seed >> 33) % 1000) / 1000.0
        }

        let padding: CGFloat = 0.12
        let range = padding...(1.0 - padding)

        for _ in 0..<count {
            var candidate = CGPoint(x: nextRandom(), y: nextRandom())
            // Clamp to padded range
            candidate.x = min(max(candidate.x, range.lowerBound), range.upperBound)
            candidate.y = min(max(candidate.y, range.lowerBound), range.upperBound)

            // Push apart from existing positions (simple repulsion)
            for _ in 0..<5 {
                for existing in positions {
                    let dx = candidate.x - existing.x
                    let dy = candidate.y - existing.y
                    let dist = hypot(dx, dy)
                    if dist < 0.18 && dist > 0.001 {
                        candidate.x += (dx / dist) * 0.05
                        candidate.y += (dy / dist) * 0.05
                        candidate.x = min(max(candidate.x, range.lowerBound), range.upperBound)
                        candidate.y = min(max(candidate.y, range.lowerBound), range.upperBound)
                    }
                }
            }

            positions.append(candidate)
        }

        return positions
    }
}
