import XCTest
@testable import Orbit

@MainActor
final class MissionsViewModelTests: XCTestCase {

    // MARK: - Initial State

    func testInitialStateIsEmpty() async {
        let vm = MissionsViewModel()
        XCTAssertTrue(vm.allMissions.isEmpty)
        XCTAssertTrue(vm.suggestedMissions.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.isSubmitting)
        XCTAssertNil(vm.filterTag)
        XCTAssertFalse(vm.showToast)
    }

    // MARK: - Insert Created Mission

    func testInsertSetMission() async {
        let vm = MissionsViewModel()
        let mission = Mission(title: "Test Set", mode: .set)
        vm.insertCreatedMission(mission)
        XCTAssertEqual(vm.allMissions.count, 1)
        XCTAssertEqual(vm.allMissions.first?.title, "Test Set")
    }

    func testInsertFlexMission() async {
        let vm = MissionsViewModel()
        let mission = Mission(title: "Test Flex", mode: .flex)
        vm.insertCreatedMission(mission)
        XCTAssertEqual(vm.allMissions.count, 1)
        XCTAssertEqual(vm.allMissions.first?.mode, .flex)
    }

    func testInsertCreatedMissionAtFront() async {
        let vm = MissionsViewModel()
        let m1 = Mission(title: "First", mode: .set)
        let m2 = Mission(title: "Second", mode: .set)
        vm.insertCreatedMission(m1)
        vm.insertCreatedMission(m2)
        XCTAssertEqual(vm.allMissions.first?.title, "Second")
    }

    func testInsertCreatedMissionReplacesDuplicate() async {
        let vm = MissionsViewModel()
        let original = Mission(id: "m-1", title: "Original", mode: .set)
        let updated = Mission(id: "m-1", title: "Updated", mode: .set)
        vm.insertCreatedMission(original)
        vm.insertCreatedMission(updated)
        XCTAssertEqual(vm.allMissions.count, 1)
        XCTAssertEqual(vm.allMissions.first?.title, "Updated")
    }

    // MARK: - MyMissions

    func testMyMissionsIncludesInPodSet() async {
        let vm = MissionsViewModel()
        var m = Mission(title: "Joined Set", mode: .set)
        m.userPodStatus = "in_pod"
        vm.insertCreatedMission(m)
        XCTAssertEqual(vm.myMissions.count, 1)
    }

    func testMyMissionsIncludesInPodFlex() async {
        let vm = MissionsViewModel()
        var m = Mission(title: "Joined Flex", mode: .flex)
        m.userPodStatus = "in_pod"
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

    func testSkipMissionRemovesLocally() async {
        let vm = MissionsViewModel()
        let m1 = Mission(id: "skip-me", title: "To Skip", mode: .set)
        let m2 = Mission(id: "keep-me", title: "To Keep", mode: .flex)
        vm.insertCreatedMission(m1)
        vm.insertCreatedMission(m2)

        // skipMission calls the API, which will fail in tests, but it still removes locally
        await vm.skipMission(m1)

        XCTAssertFalse(vm.allMissions.contains { $0.id == "skip-me" })
        XCTAssertTrue(vm.allMissions.contains { $0.id == "keep-me" })
    }
}
