//
//  ScheduleViewModel.swift
//  Orbit
//
//  Manages the When2Meet grid state, drag gesture, phase transitions,
//  leader timeouts, and dissolution timers for flex mode pods.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class ScheduleViewModel: ObservableObject {

    // MARK: - Published State

    @Published var grid: ScheduleGrid
    @Published var currentUserSlots: Set<TimeSlot> = []
    @Published var phase: FlexPodPhase = .forming
    @Published var isEditable: Bool = true

    // Overlap
    @Published var overlapSlots: Set<TimeSlot> = []
    @Published var nearOverlapInfo: [TimeSlot: [ScheduleEntry]] = [:]

    // Leader picking
    @Published var selectedConfirmSlot: TimeSlot?
    @Published var showLeaderPickSheet: Bool = false

    // Timers / countdowns
    @Published var leaderDeadline: Date?
    @Published var noOverlapDeadline: Date?
    @Published var countdownText: String = ""

    // Drag gesture
    @Published var isDragging: Bool = false
    @Published var dragMode: DragMode = .selecting

    enum DragMode { case selecting, deselecting }

    // MARK: - Identity

    let podId: String
    let missionId: String
    let currentUserId: Int
    let currentUserName: String

    // MARK: - Timers

    private var countdownTask: Task<Void, Never>?
    private var leaderTimerTask: Task<Void, Never>?

    // MARK: - Init

    init(podId: String, missionId: String, currentUserId: Int, currentUserName: String, startDate: Date = Date()) {
        self.podId = podId
        self.missionId = missionId
        self.currentUserId = currentUserId
        self.currentUserName = currentUserName
        self.grid = ScheduleService.shared.getGrid(
            podId: podId,
            missionId: missionId,
            startDate: startDate
        )

        // Register the current user immediately so they appear in the legend
        // before they've saved any slots. Join index 0 is a safe default;
        // saveAvailability() will recompute the correct index from pod.memberIds.
        if grid.entries.first(where: { $0.userId == currentUserId }) == nil {
            grid.entryForUser(currentUserId, name: currentUserName, joinIndex: 0)
        }

        // Load current user's existing slots (if they saved before)
        if let entry = grid.entries.first(where: { $0.userId == currentUserId }) {
            currentUserSlots = entry.slots
        }
    }

    // MARK: - Reload Grid from Service

    /// Re-read the grid from ScheduleService to pick up newly populated backend data.
    func reloadGrid() {
        let freshGrid = ScheduleService.shared.getGrid(
            podId: podId,
            missionId: missionId,
            startDate: grid.startDate
        )
        grid = freshGrid
        print("[Schedule] reloadGrid: \(grid.entries.count) entries: \(grid.entries.map { "\($0.userId):\($0.slots.count)slots" })")

        // Re-register current user if absent (e.g., first time before save)
        if grid.entries.first(where: { $0.userId == currentUserId }) == nil {
            grid.entryForUser(currentUserId, name: currentUserName, joinIndex: 0)
        }

        // Merge live unsaved selections with backend data
        if let entry = grid.entries.first(where: { $0.userId == currentUserId }) {
            currentUserSlots = currentUserSlots.union(entry.slots)
        }
    }

    // MARK: - Grid Interaction (Single Tap)

    func toggleSlot(_ slot: TimeSlot) {
        guard isEditable else { return }
        if currentUserSlots.contains(slot) {
            currentUserSlots.remove(slot)
        } else {
            currentUserSlots.insert(slot)
        }
    }

    // MARK: - Grid Interaction (Drag Gesture)

    /// Begin a drag from a slot. Determines mode based on initial state.
    func beginDrag(at slot: TimeSlot) {
        guard isEditable else { return }
        isDragging = true
        if currentUserSlots.contains(slot) {
            dragMode = .deselecting
            currentUserSlots.remove(slot)
        } else {
            dragMode = .selecting
            currentUserSlots.insert(slot)
        }
    }

    /// Continue drag over a slot.
    func continueDrag(over slot: TimeSlot) {
        guard isDragging, isEditable else { return }
        switch dragMode {
        case .selecting:
            currentUserSlots.insert(slot)
        case .deselecting:
            currentUserSlots.remove(slot)
        }
    }

    /// End drag.
    func endDrag() {
        isDragging = false
    }

    // MARK: - Save Availability

    /// Persist the user's current selections to the ScheduleService.
    func saveAvailability(pod: Pod) {
        let joinIndex = pod.memberIds.firstIndex(of: currentUserId) ?? 0
        ScheduleService.shared.saveAvailability(
            podId: podId,
            userId: currentUserId,
            name: currentUserName,
            joinIndex: joinIndex,
            slots: currentUserSlots,
            onServerSync: { [weak self] in
                // Backend responded with all members' data — refresh grid
                self?.reloadGrid()
            }
        )
        // Refresh grid from service (immediate local update)
        grid = ScheduleService.shared.getGrid(podId: podId, missionId: missionId, startDate: grid.startDate)
        // Recompute phase
        computePhase(pod: pod)
    }

    // MARK: - Phase Computation (State Machine)

    func computePhase(pod: Pod) {
        // Already scheduled?
        if pod.status == "meeting_confirmed" {
            phase = .scheduled(confirmedTime: pod.confirmedTime ?? Date())
            isEditable = false
            overlapSlots = []
            return
        }

        // Dissolved/cancelled?
        if pod.status == "cancelled" {
            phase = .dissolved
            isEditable = false
            return
        }

        let memberCount = pod.memberIds.count

        // Check if all members who have entries have submitted
        let submitted = grid.submittedCount

        // Forming: fewer than 3 members
        if memberCount < 3 {
            phase = .forming
            isEditable = true
            overlapSlots = []
            nearOverlapInfo = [:]
            return
        }

        // 3+ members: check if all 3 have submitted
        if submitted < 3 {
            // Still waiting for remaining members to save
            phase = .forming
            isEditable = true
            return
        }

        // All 3 have submitted → Lock check
        let overlap = grid.overlapSlots()
        overlapSlots = overlap
        nearOverlapInfo = grid.nearOverlapSlots()

        if !overlap.isEmpty {
            // Overlap exists → leader picks
            let leaderId = currentLeaderId(pod: pod)
            if currentUserId == leaderId {
                phase = .leaderPicking
                isEditable = false  // grid locked, but leader can pick overlap slots
                if leaderDeadline == nil {
                    leaderDeadline = Date().addingTimeInterval(2 * 24 * 3600)  // 2 days
                    startLeaderTimer(pod: pod)
                }
            } else {
                phase = .locked(hasOverlap: true)
                isEditable = false
            }
        } else {
            // No overlap → 48h countdown, members can update
            if noOverlapDeadline == nil {
                noOverlapDeadline = Date().addingTimeInterval(48 * 3600)
            }
            phase = .noOverlapCountdown(deadline: noOverlapDeadline!)
            isEditable = true  // members can update their availability
            startCountdownTimer(deadline: noOverlapDeadline!)
        }
    }

    // MARK: - Leader Actions

    /// Leader selects an overlap slot to tap it; toggles selection.
    func selectOverlapSlot(_ slot: TimeSlot) {
        guard phase == .leaderPicking, overlapSlots.contains(slot) else { return }
        if selectedConfirmSlot == slot {
            selectedConfirmSlot = nil
        } else {
            selectedConfirmSlot = slot
        }
    }

    /// Leader confirms the selected time slot.
    func confirmTimeSlot() async {
        guard let slot = selectedConfirmSlot else { return }
        ScheduleService.shared.confirmSlot(podId: podId, slot: slot)
        // TODO: When backend is ready, this would POST and get back updated pod
        // For now, transition locally
        phase = .scheduled(confirmedTime: slot.date)
        isEditable = false
        leaderTimerTask?.cancel()
        countdownTask?.cancel()
    }

    // MARK: - Leader Timeout / Transfer

    /// Determine the current leader (handles timeout-based rotation).
    private var leaderRotationIndex: Int = 0

    func currentLeaderId(pod: Pod) -> Int {
        guard !pod.memberIds.isEmpty else { return 0 }
        let idx = leaderRotationIndex % min(pod.memberIds.count, 3)
        return pod.memberIds[idx]
    }

    /// Start the leader pick timer. On timeout, rotate leadership.
    private func startLeaderTimer(pod: Pod) {
        leaderTimerTask?.cancel()
        leaderTimerTask = Task { [weak self] in
            guard let self, let deadline = self.leaderDeadline else { return }
            while !Task.isCancelled {
                let remaining = deadline.timeIntervalSinceNow
                if remaining <= 0 {
                    // Timeout → rotate leadership
                    self.transferLeadership(pod: pod)
                    return
                }
                // Update countdown text
                self.countdownText = Self.formatCountdown(remaining)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    /// Rotate leadership to the next member. If all exhausted → dissolve.
    private func transferLeadership(pod: Pod) {
        leaderRotationIndex += 1
        let maxLeaders = min(pod.memberIds.count, 3)

        if leaderRotationIndex >= maxLeaders {
            // All leaders exhausted → dissolve
            phase = .dissolved
            isEditable = false
            leaderTimerTask?.cancel()
            countdownTask?.cancel()
            ScheduleService.shared.clearGrid(podId: podId)
            return
        }

        // New leader gets 2 days
        leaderDeadline = Date().addingTimeInterval(2 * 24 * 3600)
        let newLeaderId = currentLeaderId(pod: pod)

        if currentUserId == newLeaderId {
            phase = .leaderPicking
            isEditable = false
        } else {
            phase = .locked(hasOverlap: true)
            isEditable = false
        }

        startLeaderTimer(pod: pod)
    }

    // MARK: - Countdown Timer (No Overlap)

    private func startCountdownTimer(deadline: Date) {
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let remaining = deadline.timeIntervalSinceNow
                if remaining <= 0 {
                    // 48h expired with no overlap → dissolve
                    self.phase = .dissolved
                    self.isEditable = false
                    ScheduleService.shared.clearGrid(podId: self.podId)
                    return
                }
                self.countdownText = Self.formatCountdown(remaining)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    // MARK: - Formatting

    static func formatCountdown(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m \(s)s"
    }

    /// Format a TimeSlot for display: "Mon Mar 15, 3 PM".
    static func formatSlot(_ slot: TimeSlot) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEE MMM d"
        return "\(df.string(from: slot.date)), \(slot.label)"
    }

    // MARK: - Cleanup

    deinit {
        countdownTask?.cancel()
        leaderTimerTask?.cancel()
    }
}
