//
//  ScheduleService.swift
//  Orbit
//
//  Local-first schedule management for flex mode pods.
//  In-memory storage with TODO stubs for backend API endpoints.
//

import Foundation

class ScheduleService {
    static let shared = ScheduleService()
    private init() {}

    /// In-memory grids keyed by podId.
    /// TODO: Replace with API calls when backend supports schedule grids.
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

    // MARK: - Save Availability

    /// Save a user's selected time slots.
    /// TODO: POST /pods/{podId}/schedule/availability { user_id, slots: [{date, hour}] }
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
    }

    // MARK: - Confirm Slot (Leader Action)

    /// Record the leader's confirmed time slot.
    /// TODO: POST /pods/{podId}/schedule/confirm { date, hour }
    /// This should update the pod status to "meeting_confirmed" on the backend.
    func confirmSlot(podId: String, slot: TimeSlot) {
        // Local-only: the ViewModel handles status transitions.
        // When backend is ready, this would:
        // 1. POST to backend
        // 2. Backend updates pod.status → "meeting_confirmed"
        // 3. Backend sets pod.scheduledTime
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
