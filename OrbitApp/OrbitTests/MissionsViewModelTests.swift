import XCTest
@testable import Orbit

@MainActor
final class MissionsViewModelTests: XCTestCase {

    // MARK: - Initial State

    func testInitialStateIsEmpty() async throws {
        let vm = MissionsViewModel()
        XCTAssertTrue(vm.missions.isEmpty)
        XCTAssertTrue(vm.pendingMissions.isEmpty)
        XCTAssertTrue(vm.matchedMissions.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.isSubmitting)
    }

    // MARK: - Load Missions

    func testLoadMissionsPopulatesArray() async throws {
        let vm = MissionsViewModel()
        vm.loadMissions()

        // Wait for the internal Task to complete
        try await Task.sleep(for: .milliseconds(500))

        XCTAssertFalse(vm.missions.isEmpty)
        XCTAssertFalse(vm.isLoading)
    }

    func testLoadMissionsOnlyLoadsOnce() async throws {
        let vm = MissionsViewModel()
        vm.loadMissions()
        try await Task.sleep(for: .milliseconds(500))

        let count = vm.missions.count
        vm.loadMissions() // Second call should be no-op (guard)
        try await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(vm.missions.count, count)
    }

    // MARK: - Computed Filters

    func testPendingMissionsFilter() async throws {
        let vm = MissionsViewModel()
        vm.loadMissions()
        try await Task.sleep(for: .milliseconds(500))

        for mission in vm.pendingMissions {
            XCTAssertEqual(mission.status, .pendingMatch)
        }
    }

    func testMatchedMissionsFilter() async throws {
        let vm = MissionsViewModel()
        vm.loadMissions()
        try await Task.sleep(for: .milliseconds(500))

        for mission in vm.matchedMissions {
            XCTAssertEqual(mission.status, .matched)
        }
    }

    func testPendingPlusMatchedEqualsTotal() async throws {
        let vm = MissionsViewModel()
        vm.loadMissions()
        try await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(vm.pendingMissions.count + vm.matchedMissions.count, vm.missions.count)
    }

    // MARK: - Create Mission

    func testCreateMissionAppendsMission() {
        let vm = MissionsViewModel()

        vm.createMission(
            activityCategory: .yoga,
            customActivityName: nil,
            minGroupSize: 2,
            maxGroupSize: 5,
            availability: [
                AvailabilitySlot(date: Date(), timeBlocks: [.morning]),
            ],
            description: "Morning yoga"
        )

        XCTAssertEqual(vm.missions.count, 1)
        XCTAssertEqual(vm.missions.first?.activityCategory, .yoga)
        XCTAssertEqual(vm.missions.first?.status, .pendingMatch)
    }

    func testCreateMissionInsertsAtFront() async throws {
        let vm = MissionsViewModel()
        vm.loadMissions()
        try await Task.sleep(for: .milliseconds(500))

        vm.createMission(
            activityCategory: .running,
            customActivityName: nil,
            minGroupSize: 2,
            maxGroupSize: 3,
            availability: [
                AvailabilitySlot(date: Date(), timeBlocks: [.evening]),
            ],
            description: ""
        )

        XCTAssertEqual(vm.missions.first?.activityCategory, .running)
    }

    func testCreateMissionWithCustomName() {
        let vm = MissionsViewModel()

        vm.createMission(
            activityCategory: .custom,
            customActivityName: "Ultimate Frisbee",
            minGroupSize: 4,
            maxGroupSize: 8,
            availability: [
                AvailabilitySlot(date: Date(), timeBlocks: [.afternoon]),
            ],
            description: ""
        )

        XCTAssertEqual(vm.missions.first?.title, "Ultimate Frisbee")
        XCTAssertEqual(vm.missions.first?.customActivityName, "Ultimate Frisbee")
        XCTAssertEqual(vm.missions.first?.activityCategory, .custom)
    }

    func testCreateMissionShowsToast() {
        let vm = MissionsViewModel()

        vm.createMission(
            activityCategory: .basketball,
            customActivityName: nil,
            minGroupSize: 2,
            maxGroupSize: 4,
            availability: [
                AvailabilitySlot(date: Date(), timeBlocks: [.morning]),
            ],
            description: ""
        )

        XCTAssertEqual(vm.toastMessage, "Mission created!")
        XCTAssertTrue(vm.showToast)
    }

    // MARK: - Delete Mission

    func testDeleteMissionRemovesCorrectMission() {
        let vm = MissionsViewModel()

        vm.createMission(
            activityCategory: .hiking,
            customActivityName: nil,
            minGroupSize: 3,
            maxGroupSize: 6,
            availability: [
                AvailabilitySlot(date: Date(), timeBlocks: [.morning]),
            ],
            description: ""
        )

        let missionId = vm.missions.first!.id
        vm.deleteMission(id: missionId)

        XCTAssertTrue(vm.missions.isEmpty)
    }

    func testDeleteMissionNoOpForNonexistentId() {
        let vm = MissionsViewModel()

        vm.createMission(
            activityCategory: .gym,
            customActivityName: nil,
            minGroupSize: 2,
            maxGroupSize: 4,
            availability: [
                AvailabilitySlot(date: Date(), timeBlocks: [.evening]),
            ],
            description: ""
        )

        let countBefore = vm.missions.count
        vm.deleteMission(id: "nonexistent-id")

        XCTAssertEqual(vm.missions.count, countBefore)
    }

    func testDeleteMissionShowsToast() {
        let vm = MissionsViewModel()

        vm.createMission(
            activityCategory: .movies,
            customActivityName: nil,
            minGroupSize: 2,
            maxGroupSize: 4,
            availability: [
                AvailabilitySlot(date: Date(), timeBlocks: [.evening]),
            ],
            description: ""
        )

        let missionId = vm.missions.first!.id
        vm.deleteMission(id: missionId)

        XCTAssertEqual(vm.toastMessage, "Mission deleted")
    }
}
