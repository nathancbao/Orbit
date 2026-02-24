import XCTest
@testable import Orbit

final class MissionModelTests: XCTestCase {

    // MARK: - ActivityCategory Tests

    func testActivityCategoryAllCasesCount() {
        XCTAssertEqual(ActivityCategory.allCases.count, 12)
    }

    func testActivityCategoryDisplayName() {
        XCTAssertEqual(ActivityCategory.basketball.displayName, "Basketball")
        XCTAssertEqual(ActivityCategory.cafeHopping.displayName, "Cafe Hopping")
        XCTAssertEqual(ActivityCategory.studySession.displayName, "Study Session")
        XCTAssertEqual(ActivityCategory.custom.displayName, "Custom")
    }

    func testActivityCategoryIconsAreNonEmpty() {
        for category in ActivityCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty, "\(category) should have a non-empty icon")
        }
    }

    func testActivityCategoryIdentifiable() {
        let category = ActivityCategory.basketball
        XCTAssertEqual(category.id, "Basketball")
    }

    // MARK: - TimeBlock Tests

    func testTimeBlockShortLabels() {
        XCTAssertEqual(TimeBlock.morning.shortLabel, "AM")
        XCTAssertEqual(TimeBlock.afternoon.shortLabel, "PM")
        XCTAssertEqual(TimeBlock.evening.shortLabel, "Eve")
    }

    func testTimeBlockLabels() {
        XCTAssertEqual(TimeBlock.morning.label, "Morning")
        XCTAssertEqual(TimeBlock.afternoon.label, "Afternoon")
        XCTAssertEqual(TimeBlock.evening.label, "Evening")
    }

    func testTimeBlockAllCasesCount() {
        XCTAssertEqual(TimeBlock.allCases.count, 3)
    }

    func testTimeBlockIconsAreNonEmpty() {
        for block in TimeBlock.allCases {
            XCTAssertFalse(block.icon.isEmpty, "\(block) should have a non-empty icon")
        }
    }

    // MARK: - MissionStatus Tests

    func testMissionStatusLabels() {
        XCTAssertEqual(MissionStatus.pendingMatch.label, "Pending")
        XCTAssertEqual(MissionStatus.matched.label, "Matched")
    }

    // MARK: - AvailabilitySlot Tests

    func testAvailabilitySlotDayLabel() {
        let date = makeDate(year: 2026, month: 3, day: 15) // Sunday
        let slot = AvailabilitySlot(date: date, timeBlocks: [.morning])
        XCTAssertEqual(slot.dateLabel, "3/15")
        XCTAssertFalse(slot.weekdayLabel.isEmpty)
        XCTAssertFalse(slot.dayLabel.isEmpty)
    }

    func testAvailabilitySlotEquatable() {
        let date = makeDate(year: 2026, month: 3, day: 15)
        let slot1 = AvailabilitySlot(date: date, timeBlocks: [.morning, .afternoon])
        let slot2 = AvailabilitySlot(date: date, timeBlocks: [.morning, .afternoon])
        XCTAssertEqual(slot1, slot2)
    }

    func testAvailabilitySlotIdentifiable() {
        let date = makeDate(year: 2026, month: 3, day: 15)
        let slot = AvailabilitySlot(date: date, timeBlocks: [.evening])
        XCTAssertEqual(slot.id, date)
    }

    // MARK: - Mission Computed Properties

    func testTotalSlotCount() {
        let mission = makeMission(availability: [
            AvailabilitySlot(date: Date(), timeBlocks: [.morning, .afternoon]),
            AvailabilitySlot(date: Date().addingTimeInterval(86400), timeBlocks: [.evening]),
        ])
        XCTAssertEqual(mission.totalSlotCount, 3)
    }

    func testTotalSlotCountEmpty() {
        let mission = makeMission(availability: [])
        XCTAssertEqual(mission.totalSlotCount, 0)
    }

    func testActiveDayCount() {
        let mission = makeMission(availability: [
            AvailabilitySlot(date: Date(), timeBlocks: [.morning, .afternoon]),
            AvailabilitySlot(date: Date().addingTimeInterval(86400), timeBlocks: [.evening]),
        ])
        XCTAssertEqual(mission.activeDayCount, 2)
    }

    func testAvailabilitySummaryPlural() {
        let mission = makeMission(availability: [
            AvailabilitySlot(date: Date(), timeBlocks: [.morning, .afternoon]),
            AvailabilitySlot(date: Date().addingTimeInterval(86400), timeBlocks: [.evening]),
        ])
        XCTAssertEqual(mission.availabilitySummary, "3 slots over 2 days")
    }

    func testAvailabilitySummarySingular() {
        let mission = makeMission(availability: [
            AvailabilitySlot(date: Date(), timeBlocks: [.morning]),
        ])
        XCTAssertEqual(mission.availabilitySummary, "1 slot over 1 day")
    }

    func testGroupSizeLabelRange() {
        let mission = makeMission(minGroupSize: 2, maxGroupSize: 6)
        XCTAssertEqual(mission.groupSizeLabel, "2-6 people")
    }

    func testGroupSizeLabelEqual() {
        let mission = makeMission(minGroupSize: 3, maxGroupSize: 3)
        XCTAssertEqual(mission.groupSizeLabel, "3 people")
    }

    func testDisplayTitleUsesActivityName() {
        let mission = makeMission(
            title: "",
            activityCategory: .basketball,
            customActivityName: nil
        )
        XCTAssertEqual(mission.displayTitle, "Basketball")
    }

    func testDisplayTitleUsesTitleWhenSet() {
        let mission = makeMission(
            title: "Pickup Hoops",
            activityCategory: .basketball,
            customActivityName: nil
        )
        XCTAssertEqual(mission.displayTitle, "Pickup Hoops")
    }

    func testDisplayTitleUsesCustomName() {
        let mission = makeMission(
            title: "",
            activityCategory: .custom,
            customActivityName: "Ultimate Frisbee"
        )
        XCTAssertEqual(mission.displayTitle, "Ultimate Frisbee")
    }

    func testDisplayTitleFallsBackForEmptyCustom() {
        let mission = makeMission(
            title: "Fallback",
            activityCategory: .custom,
            customActivityName: ""
        )
        XCTAssertEqual(mission.displayTitle, "Fallback")
    }

    // MARK: - Codable Round-Trip

    func testMissionCodableRoundTrip() throws {
        let original = makeMission(
            title: "Test Mission",
            activityCategory: .hiking,
            customActivityName: nil,
            minGroupSize: 3,
            maxGroupSize: 8,
            availability: [
                AvailabilitySlot(date: Date(timeIntervalSince1970: 1740000000), timeBlocks: [.morning, .evening]),
            ]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Mission.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.activityCategory, original.activityCategory)
        XCTAssertEqual(decoded.minGroupSize, original.minGroupSize)
        XCTAssertEqual(decoded.maxGroupSize, original.maxGroupSize)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.availability.count, original.availability.count)
        XCTAssertEqual(decoded.availability.first?.timeBlocks, original.availability.first?.timeBlocks)
    }

    // MARK: - MissionError Tests

    func testMissionErrorDescriptions() {
        XCTAssertEqual(MissionError.notFound.errorDescription, "Mission not found")
        XCTAssertEqual(MissionError.invalidForm("bad input").errorDescription, "bad input")
        XCTAssertEqual(MissionError.networkError.errorDescription, "Network error. Please try again.")
        XCTAssertEqual(MissionError.unknown("oops").errorDescription, "oops")
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }

    private func makeMission(
        title: String = "Test",
        activityCategory: ActivityCategory = .basketball,
        customActivityName: String? = nil,
        minGroupSize: Int = 2,
        maxGroupSize: Int = 4,
        availability: [AvailabilitySlot] = []
    ) -> Mission {
        Mission(
            id: "test-\(UUID().uuidString)",
            title: title,
            description: "",
            activityCategory: activityCategory,
            customActivityName: customActivityName,
            minGroupSize: minGroupSize,
            maxGroupSize: maxGroupSize,
            availability: availability,
            status: .pendingMatch,
            creatorId: 0,
            createdAt: nil
        )
    }
}
