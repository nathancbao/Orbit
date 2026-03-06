import XCTest
@testable import Orbit

@MainActor
final class ScheduleGridTests: XCTestCase {

    // MARK: - Helpers

    private func makeDate(year: Int = 2026, month: Int = 3, day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        return Calendar.current.date(from: c)!
    }

    private func makeSlot(day: Int, hour: Int) -> TimeSlot {
        TimeSlot(date: makeDate(day: day), hour: hour)
    }

    private func makeGrid(podId: String = "pod-1", startDay: Int = 1) -> ScheduleGrid {
        let start = makeDate(day: startDay)
        let end = Calendar.current.date(byAdding: .day, value: 9, to: start)!
        return ScheduleGrid(
            missionId: "mission-1",
            podId: podId,
            startDate: start,
            endDate: end,
            entries: []
        )
    }

    private func makeEntry(userId: Int, name: String, index: Int, slots: Set<TimeSlot>) -> ScheduleEntry {
        ScheduleEntry(
            userId: userId,
            memberColor: MemberColor.forIndex(index),
            displayName: name,
            slots: slots,
            updatedAt: Date()
        )
    }

    // MARK: - TimeSlot

    func testTimeSlotCalendarEquality() async {
        // Two Date objects for the same calendar day but different times
        var c1 = DateComponents(); c1.year = 2026; c1.month = 3; c1.day = 15; c1.hour = 9
        var c2 = DateComponents(); c2.year = 2026; c2.month = 3; c2.day = 15; c2.hour = 17
        let date1 = Calendar.current.date(from: c1)!
        let date2 = Calendar.current.date(from: c2)!

        let slot1 = TimeSlot(date: date1, hour: 10)
        let slot2 = TimeSlot(date: date2, hour: 10)

        XCTAssertEqual(slot1, slot2, "Same calendar day + same hour should be equal")
    }

    func testTimeSlotDifferentDaysNotEqual() async {
        let slot1 = makeSlot(day: 15, hour: 10)
        let slot2 = makeSlot(day: 16, hour: 10)
        XCTAssertNotEqual(slot1, slot2)
    }

    func testTimeSlotDifferentHoursNotEqual() async {
        let slot1 = makeSlot(day: 15, hour: 10)
        let slot2 = makeSlot(day: 15, hour: 11)
        XCTAssertNotEqual(slot1, slot2)
    }

    func testTimeSlotHashConsistency() async {
        // Same logical slot created from different Date objects should hash the same
        var c1 = DateComponents(); c1.year = 2026; c1.month = 3; c1.day = 15; c1.hour = 0
        var c2 = DateComponents(); c2.year = 2026; c2.month = 3; c2.day = 15; c2.hour = 23
        let date1 = Calendar.current.date(from: c1)!
        let date2 = Calendar.current.date(from: c2)!

        let slot1 = TimeSlot(date: date1, hour: 14)
        let slot2 = TimeSlot(date: date2, hour: 14)

        var set = Set<TimeSlot>()
        set.insert(slot1)
        set.insert(slot2)
        XCTAssertEqual(set.count, 1, "Same logical slot should deduplicate in Set")
    }

    func testTimeSlotKey() async {
        let slot = makeSlot(day: 5, hour: 14)
        XCTAssertEqual(slot.key, "2026-3-5-14")
    }

    func testTimeSlotLabel() async {
        XCTAssertEqual(TimeSlot(date: Date(), hour: 9).label, "9 AM")
        XCTAssertEqual(TimeSlot(date: Date(), hour: 12).label, "12 PM")
        XCTAssertEqual(TimeSlot(date: Date(), hour: 15).label, "3 PM")
        XCTAssertEqual(TimeSlot(date: Date(), hour: 21).label, "9 PM")
    }

    // MARK: - MemberColor

    func testMemberColorDeterministicAssignment() async {
        XCTAssertEqual(MemberColor.forIndex(0), .pink)
        XCTAssertEqual(MemberColor.forIndex(1), .purple)
        XCTAssertEqual(MemberColor.forIndex(7), .red)
        // Cycles: index 8 wraps to pink
        XCTAssertEqual(MemberColor.forIndex(8), .pink)
        XCTAssertEqual(MemberColor.forIndex(9), .purple)
    }

    func testMemberColorAllCasesCount() async {
        XCTAssertEqual(MemberColor.allCases.count, 8)
    }

    func testMemberColorHasSwiftUIColor() async {
        // Every case should return a valid Color (non-crashing)
        for c in MemberColor.allCases {
            _ = c.color  // should not crash
        }
    }

    // MARK: - ScheduleGrid Dates

    func testGridDatesGeneration() async {
        let grid = makeGrid(startDay: 1)
        let dates = grid.dates
        // startDate (day 1) + 9 more days = 10 days total
        XCTAssertEqual(dates.count, 10)

        let cal = Calendar.current
        XCTAssertEqual(cal.component(.day, from: dates.first!), 1)
        XCTAssertEqual(cal.component(.day, from: dates.last!), 10)
    }

    // MARK: - Entry Management

    func testEntryForUserCreatesNew() async {
        var grid = makeGrid()
        let idx = grid.entryForUser(42, name: "Alice", joinIndex: 0)
        XCTAssertEqual(idx, 0)
        XCTAssertEqual(grid.entries.count, 1)
        XCTAssertEqual(grid.entries[0].userId, 42)
        XCTAssertEqual(grid.entries[0].displayName, "Alice")
        XCTAssertEqual(grid.entries[0].memberColor, .pink) // index 0
    }

    func testEntryForUserFindsExisting() async {
        var grid = makeGrid()
        let idx1 = grid.entryForUser(42, name: "Alice", joinIndex: 0)
        let idx2 = grid.entryForUser(42, name: "Alice", joinIndex: 0)
        XCTAssertEqual(idx1, idx2)
        XCTAssertEqual(grid.entries.count, 1, "Should not create duplicate")
    }

    func testUpdateSlots() async {
        var grid = makeGrid()
        grid.entryForUser(42, name: "Alice", joinIndex: 0)
        let slots: Set<TimeSlot> = [makeSlot(day: 1, hour: 10), makeSlot(day: 1, hour: 11)]
        grid.updateSlots(for: 42, slots: slots)
        XCTAssertEqual(grid.entries[0].slots.count, 2)
    }

    // MARK: - Member Count

    func testMemberCountForSlot() async {
        var grid = makeGrid()
        let slot = makeSlot(day: 3, hour: 14)
        grid.entries = [
            makeEntry(userId: 1, name: "A", index: 0, slots: [slot]),
            makeEntry(userId: 2, name: "B", index: 1, slots: [slot]),
            makeEntry(userId: 3, name: "C", index: 2, slots: []),
        ]
        XCTAssertEqual(grid.memberCount(for: slot), 2)
    }

    func testMembersForSlotReturnsCorrectEntries() async {
        let slot = makeSlot(day: 3, hour: 14)
        let otherSlot = makeSlot(day: 3, hour: 15)
        var grid = makeGrid()
        grid.entries = [
            makeEntry(userId: 1, name: "A", index: 0, slots: [slot, otherSlot]),
            makeEntry(userId: 2, name: "B", index: 1, slots: [slot]),
            makeEntry(userId: 3, name: "C", index: 2, slots: [otherSlot]),
        ]
        let members = grid.members(for: slot)
        XCTAssertEqual(members.count, 2)
        XCTAssertTrue(members.contains { $0.userId == 1 })
        XCTAssertTrue(members.contains { $0.userId == 2 })
    }

    // MARK: - Overlap

    func testOverlapTwoMembers() async {
        let shared = makeSlot(day: 5, hour: 14)
        let onlyA = makeSlot(day: 5, hour: 10)
        let onlyB = makeSlot(day: 5, hour: 16)

        var grid = makeGrid()
        grid.entries = [
            makeEntry(userId: 1, name: "A", index: 0, slots: [shared, onlyA]),
            makeEntry(userId: 2, name: "B", index: 1, slots: [shared, onlyB]),
        ]

        let overlap = grid.overlapSlots()
        XCTAssertEqual(overlap.count, 1)
        XCTAssertTrue(overlap.contains(shared))
        XCTAssertTrue(grid.hasOverlap)
    }

    func testOverlapThreeMembers() async {
        let sharedAll = makeSlot(day: 5, hour: 14)
        let sharedAB = makeSlot(day: 5, hour: 10)
        let onlyC = makeSlot(day: 5, hour: 18)

        var grid = makeGrid()
        grid.entries = [
            makeEntry(userId: 1, name: "A", index: 0, slots: [sharedAll, sharedAB]),
            makeEntry(userId: 2, name: "B", index: 1, slots: [sharedAll, sharedAB]),
            makeEntry(userId: 3, name: "C", index: 2, slots: [sharedAll, onlyC]),
        ]

        let overlap = grid.overlapSlots()
        XCTAssertEqual(overlap.count, 1)
        XCTAssertTrue(overlap.contains(sharedAll))
        XCTAssertFalse(overlap.contains(sharedAB), "2-of-3 is not full overlap")
    }

    func testNoOverlapReturnsEmpty() async {
        var grid = makeGrid()
        grid.entries = [
            makeEntry(userId: 1, name: "A", index: 0, slots: [makeSlot(day: 1, hour: 9)]),
            makeEntry(userId: 2, name: "B", index: 1, slots: [makeSlot(day: 1, hour: 15)]),
            makeEntry(userId: 3, name: "C", index: 2, slots: [makeSlot(day: 1, hour: 20)]),
        ]
        XCTAssertTrue(grid.overlapSlots().isEmpty)
        XCTAssertFalse(grid.hasOverlap)
    }

    func testOverlapSlotsWithNoEntries() async {
        let grid = makeGrid()
        XCTAssertTrue(grid.overlapSlots().isEmpty)
    }

    func testOverlapSlotsWithSingleMember() async {
        var grid = makeGrid()
        grid.entries = [
            makeEntry(userId: 1, name: "A", index: 0, slots: [makeSlot(day: 1, hour: 10)]),
        ]
        // Need at least 2 submitted members for overlap
        XCTAssertTrue(grid.overlapSlots().isEmpty)
    }

    func testOverlapIgnoresEmptyEntries() async {
        let shared = makeSlot(day: 5, hour: 14)
        var grid = makeGrid()
        grid.entries = [
            makeEntry(userId: 1, name: "A", index: 0, slots: [shared]),
            makeEntry(userId: 2, name: "B", index: 1, slots: [shared]),
            makeEntry(userId: 3, name: "C", index: 2, slots: []),  // not submitted yet
        ]
        let overlap = grid.overlapSlots()
        XCTAssertEqual(overlap.count, 1, "Unsubmitted member should be ignored")
    }

    // MARK: - Near Overlap

    func testNearOverlapFindsPartialMatches() async {
        let sharedAll = makeSlot(day: 5, hour: 14)
        let sharedAB = makeSlot(day: 5, hour: 10)  // 2-of-3
        let onlyA = makeSlot(day: 5, hour: 9)

        var grid = makeGrid()
        grid.entries = [
            makeEntry(userId: 1, name: "A", index: 0, slots: [sharedAll, sharedAB, onlyA]),
            makeEntry(userId: 2, name: "B", index: 1, slots: [sharedAll, sharedAB]),
            makeEntry(userId: 3, name: "C", index: 2, slots: [sharedAll]),
        ]

        let near = grid.nearOverlapSlots()
        // sharedAB is 2-of-3 (A and B have it, but not C), and it's not full overlap
        XCTAssertTrue(near.keys.contains(sharedAB))
        // sharedAll IS full overlap, so should NOT be in near
        XCTAssertFalse(near.keys.contains(sharedAll))
        // onlyA is 1-of-3, so should NOT be in near (threshold is 2)
        XCTAssertFalse(near.keys.contains(onlyA))
    }

    // MARK: - Submitted Count

    func testSubmittedCount() async {
        var grid = makeGrid()
        grid.entries = [
            makeEntry(userId: 1, name: "A", index: 0, slots: [makeSlot(day: 1, hour: 10)]),
            makeEntry(userId: 2, name: "B", index: 1, slots: []),
            makeEntry(userId: 3, name: "C", index: 2, slots: [makeSlot(day: 1, hour: 11)]),
        ]
        XCTAssertEqual(grid.submittedCount, 2)
    }

    // MARK: - FlexPodPhase Equality

    func testFlexPodPhaseEquality() async {
        XCTAssertEqual(FlexPodPhase.forming, FlexPodPhase.forming)
        XCTAssertEqual(FlexPodPhase.dissolved, FlexPodPhase.dissolved)
        XCTAssertEqual(FlexPodPhase.locked(hasOverlap: true), FlexPodPhase.locked(hasOverlap: true))
        XCTAssertNotEqual(FlexPodPhase.locked(hasOverlap: true), FlexPodPhase.locked(hasOverlap: false))
        XCTAssertNotEqual(FlexPodPhase.forming, FlexPodPhase.dissolved)
    }

    // MARK: - Drag Interaction (ScheduleViewModel)

    private func makeScheduleVM() -> ScheduleViewModel {
        ScheduleViewModel(
            podId: "pod-1",
            missionId: "mission-1",
            currentUserId: 1,
            currentUserName: "Alice",
            startDate: makeDate(day: 1)
        )
    }

    func testBeginDragOnEmptyCellSelectsMode() async {
        let vm = makeScheduleVM()
        let slot = makeSlot(day: 3, hour: 14)
        XCTAssertFalse(vm.currentUserSlots.contains(slot))

        vm.beginDrag(at: slot)

        XCTAssertTrue(vm.isDragging)
        XCTAssertEqual(vm.dragMode, .selecting)
        XCTAssertTrue(vm.currentUserSlots.contains(slot))
    }

    func testBeginDragOnFilledCellDeselectsMode() async {
        let vm = makeScheduleVM()
        let slot = makeSlot(day: 3, hour: 14)
        vm.currentUserSlots.insert(slot)

        vm.beginDrag(at: slot)

        XCTAssertTrue(vm.isDragging)
        XCTAssertEqual(vm.dragMode, .deselecting)
        XCTAssertFalse(vm.currentUserSlots.contains(slot))
    }

    func testContinueDragAppliesCorrectMode() async {
        let vm = makeScheduleVM()
        let slotA = makeSlot(day: 3, hour: 14)
        let slotB = makeSlot(day: 3, hour: 15)
        let slotC = makeSlot(day: 3, hour: 16)

        // Start selecting
        vm.beginDrag(at: slotA)
        XCTAssertEqual(vm.dragMode, .selecting)

        vm.continueDrag(over: slotB)
        vm.continueDrag(over: slotC)

        XCTAssertTrue(vm.currentUserSlots.contains(slotA))
        XCTAssertTrue(vm.currentUserSlots.contains(slotB))
        XCTAssertTrue(vm.currentUserSlots.contains(slotC))
    }

    func testEndDragResetsState() async {
        let vm = makeScheduleVM()
        let slot = makeSlot(day: 3, hour: 14)

        vm.beginDrag(at: slot)
        XCTAssertTrue(vm.isDragging)

        vm.endDrag()
        XCTAssertFalse(vm.isDragging)
    }

    func testDragModeLockedForEntireGesture() async {
        let vm = makeScheduleVM()
        let emptySlot = makeSlot(day: 3, hour: 14)
        let filledSlot = makeSlot(day: 3, hour: 15)
        vm.currentUserSlots.insert(filledSlot)

        // Begin on empty → selecting mode
        vm.beginDrag(at: emptySlot)
        XCTAssertEqual(vm.dragMode, .selecting)

        // Continue over filled slot — should still ADD (not switch to deselecting)
        vm.continueDrag(over: filledSlot)
        XCTAssertTrue(vm.currentUserSlots.contains(filledSlot), "Selecting mode should keep filled slot")
        XCTAssertTrue(vm.currentUserSlots.contains(emptySlot))
    }

    func testToggleSlotWorks() async {
        let vm = makeScheduleVM()
        let slot = makeSlot(day: 3, hour: 14)

        XCTAssertFalse(vm.currentUserSlots.contains(slot))
        vm.toggleSlot(slot)
        XCTAssertTrue(vm.currentUserSlots.contains(slot))
        vm.toggleSlot(slot)
        XCTAssertFalse(vm.currentUserSlots.contains(slot))
    }

    // MARK: - Save / Load (ScheduleService)

    func testSaveAvailabilityPersistsLocally() async {
        let slots: Set<TimeSlot> = [makeSlot(day: 3, hour: 14), makeSlot(day: 3, hour: 15)]
        ScheduleService.shared.saveAvailability(
            podId: "test-save-pod",
            userId: 99,
            name: "Tester",
            joinIndex: 0,
            slots: slots
        )
        let grid = ScheduleService.shared.getGrid(podId: "test-save-pod", missionId: "m1", startDate: makeDate(day: 1))
        let entry = grid.entries.first(where: { $0.userId == 99 })
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.slots.count, 2)
        XCTAssertTrue(entry?.hasSubmitted == true)
        // Cleanup
        ScheduleService.shared.clearGrid(podId: "test-save-pod")
    }

    func testScheduleVMLoadsPreExistingSlots() async {
        let slots: Set<TimeSlot> = [makeSlot(day: 3, hour: 10), makeSlot(day: 4, hour: 11)]
        ScheduleService.shared.saveAvailability(
            podId: "test-preload-pod",
            userId: 1,
            name: "Alice",
            joinIndex: 0,
            slots: slots
        )
        let vm = ScheduleViewModel(
            podId: "test-preload-pod",
            missionId: "m1",
            currentUserId: 1,
            currentUserName: "Alice",
            startDate: makeDate(day: 1)
        )
        XCTAssertEqual(vm.currentUserSlots.count, 2)
        XCTAssertTrue(vm.currentUserSlots.contains(makeSlot(day: 3, hour: 10)))
        // Cleanup
        ScheduleService.shared.clearGrid(podId: "test-preload-pod")
    }

    func testHasSubmittedReflectsSlotState() async {
        let entry1 = makeEntry(userId: 1, name: "A", index: 0, slots: [makeSlot(day: 1, hour: 10)])
        let entry2 = makeEntry(userId: 2, name: "B", index: 1, slots: [])
        XCTAssertTrue(entry1.hasSubmitted)
        XCTAssertFalse(entry2.hasSubmitted)
    }
}
