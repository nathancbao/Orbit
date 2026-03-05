//
//  ScheduleService.swift
//  Orbit
//
//  Local-first schedule management for flex mode pods.
//  In-memory grid as cache, synced to backend via API calls.
//

import Foundation

class ScheduleService {
    static let shared = ScheduleService()
    private init() {}

    /// In-memory grids keyed by podId.
    private var grids: [String: ScheduleGrid] = [:]

    // MARK: - Get / Create Grid

    /// Retrieve the schedule grid for a pod, creating one if it doesn't exist.
    func getGrid(podId: String, missionId: String, startDate: Date) -> ScheduleGrid {
        if let existing = grids[podId] { return existing }
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let end = cal.date(byAdding: .day, value: 9, to: start)!
        let grid = ScheduleGrid(
            missionId: missionId,
            podId: podId,
            startDate: start,
            endDate: end,
            entries: []
        )
        grids[podId] = grid
        return grid
    }

    /// Return the latest grid for a pod (nil if not created yet).
    func existingGrid(podId: String) -> ScheduleGrid? {
        grids[podId]
    }

    // MARK: - Populate from Backend

    /// Merge backend schedule_data into the local in-memory grid.
    /// Called after a pod loads. Preserves any unsaved local selections.
    func populateFromBackend(podId: String, data: PodScheduleData?) {
        guard let data = data, !data.entries.isEmpty else { return }

        // Parse the earliest date across all entries to anchor the grid
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        var allDates: [Date] = []
        for entry in data.entries.values {
            for slot in entry.slots {
                if let d = dateFormatter.date(from: slot.date) {
                    allDates.append(d)
                }
            }
        }

        let cal = Calendar.current
        let startDate = allDates.min().map { cal.startOfDay(for: $0) } ?? cal.startOfDay(for: Date())
        let endDate = cal.date(byAdding: .day, value: 9, to: startDate) ?? startDate

        var grid = grids[podId] ?? ScheduleGrid(
            missionId: "",
            podId: podId,
            startDate: startDate,
            endDate: endDate,
            entries: []
        )

        // Merge backend entries — overwrite existing entries from backend,
        // but keep any local-only entry not yet on the backend.
        for (userIdStr, backendEntry) in data.entries {
            guard let userId = Int(userIdStr) else { continue }
            // Convert PodTimeSlot → TimeSlot
            var slots = Set<TimeSlot>()
            for podSlot in backendEntry.slots {
                if let date = dateFormatter.date(from: podSlot.date) {
                    slots.insert(TimeSlot(date: date, hour: podSlot.hour))
                }
            }
            let joinIndex = backendEntry.joinIndex
            grid.entryForUser(userId, name: backendEntry.name, joinIndex: joinIndex)
            grid.updateSlots(for: userId, slots: slots)
        }

        grids[podId] = grid
    }

    // MARK: - Save Availability

    /// Save a user's selected time slots locally and sync to backend.
    func saveAvailability(
        podId: String,
        userId: Int,
        name: String,
        joinIndex: Int,
        slots: Set<TimeSlot>
    ) {
        guard var grid = grids[podId] else { return }
        grid.entryForUser(userId, name: name, joinIndex: joinIndex)
        grid.updateSlots(for: userId, slots: slots)
        grids[podId] = grid

        // Build slot payload for backend
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let slotsPayload: [[String: Any]] = slots.map { slot in
            [
                "date": dateFormatter.string(from: slot.date),
                "hour": slot.hour,
            ]
        }

        Task {
            let body: [String: Any] = [
                "name": name,
                "join_index": joinIndex,
                "slots": slotsPayload,
            ]
            let endpoint = Constants.API.Endpoints.podScheduleAvailability(podId)
            _ = try? await APIService.shared.request(
                endpoint: endpoint,
                method: "POST",
                body: body,
                authenticated: true
            ) as Pod
        }
    }

    // MARK: - Confirm Slot (Leader Action)

    /// Record the leader's confirmed time slot locally and on backend.
    func confirmSlot(podId: String, slot: TimeSlot) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let body: [String: Any] = [
            "date": dateFormatter.string(from: slot.date),
            "hour": slot.hour,
        ]
        Task {
            _ = try? await APIService.shared.request(
                endpoint: Constants.API.Endpoints.podScheduleConfirm(podId),
                method: "POST",
                body: body,
                authenticated: true
            ) as Pod
        }
    }

    // MARK: - Clear

    /// Remove all schedule data for a pod (used on dissolution).
    func clearGrid(podId: String) {
        grids.removeValue(forKey: podId)
    }

    // MARK: - Debug

    /// All stored grids (for debugging/testing).
    var allGrids: [String: ScheduleGrid] { grids }
}
