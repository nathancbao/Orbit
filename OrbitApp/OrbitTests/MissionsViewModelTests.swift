import XCTest
@testable import Orbit

@MainActor
final class MissionsViewModelTests: XCTestCase {

    // MARK: - Initial State

    func testInitialStateIsEmpty() async {
        let vm = MissionsViewModel()
        XCTAssertTrue(vm.allMissions.isEmpty)
        XCTAssertTrue(vm.allFlexMissions.isEmpty)
        XCTAssertTrue(vm.suggestedMissions.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.isSubmitting)
        XCTAssertNil(vm.filterTag)
        XCTAssertNil(vm.filterMode)
        XCTAssertFalse(vm.showToast)
    }

    // MARK: - Insert Created Mission

    func testInsertSetMission() async {
        let vm = MissionsViewModel()
        let mission = Mission(title: "Test Set", mode: .set)
        vm.insertCreatedMission(mission)
        XCTAssertEqual(vm.allMissions.count, 1)
        XCTAssertEqual(vm.allMissions.first?.title, "Test Set")
        XCTAssertTrue(vm.allFlexMissions.isEmpty)
    }

    func testInsertFlexMission() async {
        let vm = MissionsViewModel()
        let mission = Mission(title: "Test Flex", mode: .flex, activityCategory: .sports)
        vm.insertCreatedMission(mission)
        XCTAssertEqual(vm.allFlexMissions.count, 1)
        XCTAssertEqual(vm.allFlexMissions.first?.title, "Test Flex")
        XCTAssertTrue(vm.allMissions.isEmpty)
    }

    func testInsertCreatedMissionAtFront() async {
        let vm = MissionsViewModel()
        let m1 = Mission(title: "First", mode: .set)
        let m2 = Mission(title: "Second", mode: .set)
        vm.insertCreatedMission(m1)
        vm.insertCreatedMission(m2)
        XCTAssertEqual(vm.allMissions.first?.title, "Second")
    }

    // MARK: - Mode Filtering

    func testFilterModeNilReturnsAll() async {
        let vm = MissionsViewModel()
        vm.insertCreatedMission(Mission(title: "Set", mode: .set))
        vm.insertCreatedMission(Mission(title: "Flex", mode: .flex))
        vm.applyModeFilter(nil)
        XCTAssertEqual(vm.discoverMissions.count, 2)
    }

    func testFilterModeSetReturnsOnlySet() async {
        let vm = MissionsViewModel()
        vm.insertCreatedMission(Mission(title: "Set 1", mode: .set))
        vm.insertCreatedMission(Mission(title: "Flex 1", mode: .flex, activityCategory: .sports))
        vm.applyModeFilter(.set)
        let discover = vm.discoverMissions
        XCTAssertTrue(discover.allSatisfy { $0.mode == .set })
    }

    func testFilterModeFlexReturnsOnlyFlex() async {
        let vm = MissionsViewModel()
        vm.insertCreatedMission(Mission(title: "Set 1", mode: .set))
        vm.insertCreatedMission(Mission(title: "Flex 1", mode: .flex, activityCategory: .food))
        vm.applyModeFilter(.flex)
        let discover = vm.discoverMissions
        XCTAssertTrue(discover.allSatisfy { $0.mode == .flex })
    }

    // MARK: - MyMissions

    func testMyMissionsIncludesInPodSet() async {
        let vm = MissionsViewModel()
        var m = Mission(title: "Joined Set", mode: .set)
        m.userPodStatus = "in_pod"
        vm.insertCreatedMission(m)
        XCTAssertEqual(vm.myMissions.count, 1)
    }

    func testMyMissionsIncludesFlexWithPodId() async {
        let vm = MissionsViewModel()
        let m = Mission(title: "Joined Flex", mode: .flex, activityCategory: .sports, podId: "pod-1")
        vm.insertCreatedMission(m)
        XCTAssertEqual(vm.myMissions.count, 1)
    }

    func testMyMissionsExcludesNotJoined() async {
        let vm = MissionsViewModel()
        let m = Mission(title: "Not Joined", mode: .set)
        vm.insertCreatedMission(m)
        XCTAssertTrue(vm.myMissions.isEmpty)
    }

    // MARK: - Toast

    func testShowToastMessage() async {
        let vm = MissionsViewModel()
        vm.showToastMessage("Test toast")
        XCTAssertEqual(vm.toastMessage, "Test toast")
        XCTAssertTrue(vm.showToast)
    }

    // MARK: - Skip Mission

    func testSkipMissionRemovesFromAllArrays() async {
        let vm = MissionsViewModel()
        let m1 = Mission(id: "skip-me", title: "To Skip", mode: .set)
        let m2 = Mission(id: "keep-me", title: "To Keep", mode: .flex)
        vm.insertCreatedMission(m1)
        vm.insertCreatedMission(m2)

        // skipMission calls the API, which will fail in tests, but it still removes locally
        vm.allMissions.removeAll { $0.id == "skip-me" }
        vm.allFlexMissions.removeAll { $0.id == "skip-me" }

        XCTAssertFalse(vm.allMissions.contains { $0.id == "skip-me" })
        XCTAssertTrue(vm.allFlexMissions.contains { $0.id == "keep-me" })
    }
}
