import XCTest
@testable import Orbit

final class MissionModelTests: XCTestCase {

    // MARK: - ActivityCategory Tests

    func testActivityCategoryAllCasesCount() {
        XCTAssertEqual(ActivityCategory.allCases.count, 6)
    }

    func testActivityCategoryDisplayName() {
        XCTAssertEqual(ActivityCategory.sports.displayName, "Sports")
        XCTAssertEqual(ActivityCategory.food.displayName, "Food")
        XCTAssertEqual(ActivityCategory.study.displayName, "Study")
        XCTAssertEqual(ActivityCategory.custom.displayName, "Custom")
    }

    func testActivityCategoryIconsAreNonEmpty() {
        for category in ActivityCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty, "\(category) should have a non-empty icon")
        }
    }

    func testActivityCategoryIdentifiable() {
        let category = ActivityCategory.sports
        XCTAssertEqual(category.id, "Sports")
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

    // MARK: - MissionMode Tests

    func testMissionModeRawValues() {
        XCTAssertEqual(MissionMode.set.rawValue, "set")
        XCTAssertEqual(MissionMode.flex.rawValue, "flex")
    }

    func testMissionModeCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let setData = try encoder.encode(MissionMode.set)
        let decoded = try decoder.decode(MissionMode.self, from: setData)
        XCTAssertEqual(decoded, .set)

        let flexData = try encoder.encode(MissionMode.flex)
        let decodedFlex = try decoder.decode(MissionMode.self, from: flexData)
        XCTAssertEqual(decodedFlex, .flex)
    }

    // MARK: - Mission Set Mode Tests

    func testSetModeInitDefaults() {
        let mission = Mission(title: "BBQ Night")
        XCTAssertEqual(mission.mode, .set)
        XCTAssertFalse(mission.isFlexMode)
        XCTAssertEqual(mission.title, "BBQ Night")
        XCTAssertEqual(mission.status, "open")
        XCTAssertEqual(mission.maxPodSize, 4)
    }

    func testSetModeDisplayTitle() {
        let mission = Mission(title: "Study Group", mode: .set)
        XCTAssertEqual(mission.displayTitle, "Study Group")
    }

    func testSetModeDisplayDate() {
        let mission = Mission(title: "Test", date: "2026-03-15", startTime: "14:00", endTime: "16:00")
        XCTAssertFalse(mission.displayDate.isEmpty)
    }

    // MARK: - Mission Flex Mode Tests

    func testFlexModeInit() {
        let mission = Mission(
            title: "Pickup Basketball",
            mode: .flex,
            activityCategory: .sports,
            minGroupSize: 4
        )
        XCTAssertEqual(mission.mode, .flex)
        XCTAssertTrue(mission.isFlexMode)
        XCTAssertEqual(mission.activityCategory, .sports)
        XCTAssertEqual(mission.minGroupSize, 4)
    }

    func testFlexModeDisplayTitleUsesCategory() {
        let mission = Mission(title: "", mode: .flex, activityCategory: .sports)
        XCTAssertEqual(mission.displayTitle, "Sports")
    }

    func testFlexModeDisplayTitleUsesTitle() {
        let mission = Mission(title: "Pickup Hoops", mode: .flex, activityCategory: .sports)
        XCTAssertEqual(mission.displayTitle, "Pickup Hoops")
    }

    func testFlexModeDisplayTitleUsesCustomName() {
        let mission = Mission(
            title: "",
            mode: .flex,
            activityCategory: .custom,
            customActivityName: "Ultimate Frisbee"
        )
        XCTAssertEqual(mission.displayTitle, "Ultimate Frisbee")
    }

    func testFlexModeDisplayTitleFallsBackForEmptyCustom() {
        let mission = Mission(
            title: "Fallback",
            mode: .flex,
            activityCategory: .custom,
            customActivityName: ""
        )
        XCTAssertEqual(mission.displayTitle, "Fallback")
    }

    func testFlexGroupSizeLabel() {
        let mission = Mission(title: "", maxPodSize: 8, mode: .flex, minGroupSize: 3)
        XCTAssertEqual(mission.flexGroupSizeLabel, "3\u{2013}8 people")
    }

    func testFlexGroupSizeLabelEqual() {
        let mission = Mission(title: "", maxPodSize: 5, mode: .flex, minGroupSize: 5)
        XCTAssertEqual(mission.flexGroupSizeLabel, "5 people")
    }

    func testFlexGroupSizeLabelNilWhenNoMin() {
        let mission = Mission(title: "", maxPodSize: 5, mode: .flex)
        XCTAssertNil(mission.flexGroupSizeLabel)
    }

    // MARK: - AvailabilitySlot Tests

    func testAvailabilitySlotDayLabel() {
        let date = makeDate(year: 2026, month: 3, day: 15)
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

    func testAvailabilitySlotHourly() {
        let date = makeDate(year: 2026, month: 3, day: 15)
        let slot = AvailabilitySlot(date: date, hours: [9, 10, 11])
        XCTAssertTrue(slot.isHourly)
        XCTAssertEqual(slot.hours, [9, 10, 11])
        XCTAssertFalse(slot.hoursLabel.isEmpty)
    }

    func testAvailabilitySlotLegacy() {
        let date = makeDate(year: 2026, month: 3, day: 15)
        let slot = AvailabilitySlot(date: date, timeBlocks: [.morning])
        XCTAssertFalse(slot.isHourly)
        XCTAssertTrue(slot.hours.isEmpty)
    }

    // MARK: - Flex Availability Summary

    func testFlexAvailabilitySummaryHourly() {
        let mission = Mission(
            title: "",
            mode: .flex,
            availability: [
                AvailabilitySlot(date: Date(), hours: [9, 10, 11]),
                AvailabilitySlot(date: Date().addingTimeInterval(86400), hours: [14, 15]),
            ]
        )
        XCTAssertEqual(mission.flexAvailabilitySummary, "5 hours over 2 days")
    }

    func testFlexAvailabilitySummaryLegacy() {
        let mission = Mission(
            title: "",
            mode: .flex,
            availability: [
                AvailabilitySlot(date: Date(), timeBlocks: [.morning, .afternoon]),
                AvailabilitySlot(date: Date().addingTimeInterval(86400), timeBlocks: [.evening]),
            ]
        )
        XCTAssertEqual(mission.flexAvailabilitySummary, "3 slots over 2 days")
    }

    func testFlexAvailabilitySummaryNilWhenEmpty() {
        let mission = Mission(title: "", mode: .flex, availability: [])
        XCTAssertNil(mission.flexAvailabilitySummary)
    }

    func testFlexAvailabilitySummaryNilWhenNil() {
        let mission = Mission(title: "", mode: .flex)
        XCTAssertNil(mission.flexAvailabilitySummary)
    }

    // MARK: - Backward Compatibility (JSON without mode field)

    func testDecoderDefaultsToSetModeWhenModeAbsent() throws {
        let json = """
        {
            "id": "test-123",
            "title": "Old Mission",
            "description": "",
            "tags": [],
            "date": "2026-03-15",
            "status": "open"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let mission = try decoder.decode(Mission.self, from: json)
        XCTAssertEqual(mission.mode, .set)
        XCTAssertEqual(mission.title, "Old Mission")
        XCTAssertEqual(mission.date, "2026-03-15")
    }

    func testDecoderHandlesFlexMode() throws {
        let json = """
        {
            "id": "flex-123",
            "title": "Sports Game",
            "description": "Let's play",
            "tags": [],
            "date": "",
            "status": "open",
            "mode": "flex",
            "activity_category": "Sports",
            "min_group_size": 3,
            "max_pod_size": 8
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let mission = try decoder.decode(Mission.self, from: json)
        XCTAssertEqual(mission.mode, .flex)
        XCTAssertEqual(mission.activityCategory, .sports)
        XCTAssertEqual(mission.minGroupSize, 3)
        XCTAssertEqual(mission.maxPodSize, 8)
    }

    // MARK: - Mission.fromSignal()

    func testFromSignalConvertsCorrectly() {
        let signal = Signal(
            id: "sig-1",
            title: "Pickup Basketball",
            description: "Let's play",
            activityCategory: .sports,
            customActivityName: nil,
            minGroupSize: 3,
            maxGroupSize: 6,
            availability: [AvailabilitySlot(date: Date(), hours: [10, 11])],
            status: .pending,
            creatorId: 42,
            createdAt: "2026-03-01",
            podId: nil,
            scheduledTime: nil,
            links: ["https://example.com"],
            timeRangeStart: 9,
            timeRangeEnd: 17
        )

        let mission = Mission.fromSignal(signal)
        XCTAssertEqual(mission.id, "sig-1")
        XCTAssertEqual(mission.title, "Pickup Basketball")
        XCTAssertEqual(mission.mode, .flex)
        XCTAssertTrue(mission.isFlexMode)
        XCTAssertEqual(mission.activityCategory, .sports)
        XCTAssertEqual(mission.minGroupSize, 3)
        XCTAssertEqual(mission.maxPodSize, 6)
        XCTAssertEqual(mission.status, "pending")
        XCTAssertEqual(mission.creatorId, 42)
        XCTAssertEqual(mission.date, "")
        XCTAssertTrue(mission.tags.isEmpty)
        XCTAssertEqual(mission.links, ["https://example.com"])
        XCTAssertEqual(mission.timeRangeStart, 9)
        XCTAssertEqual(mission.timeRangeEnd, 17)
        XCTAssertEqual(mission.signalStatus, .pending)
    }

    // MARK: - Codable Round-Trip (Set Mode)

    func testSetModeCodableRoundTrip() throws {
        let original = Mission(
            title: "Test Mission",
            description: "A test",
            tags: ["fun"],
            location: "Campus",
            date: "2026-04-01",
            startTime: "14:00",
            endTime: "16:00",
            maxPodSize: 5,
            status: "open",
            mode: .set
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Mission.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.mode, .set)
        XCTAssertEqual(decoded.date, "2026-04-01")
        XCTAssertEqual(decoded.startTime, "14:00")
        XCTAssertEqual(decoded.maxPodSize, 5)
    }

    // MARK: - Codable Round-Trip (Flex Mode)

    func testFlexModeCodableRoundTrip() throws {
        let original = Mission(
            title: "Hoops",
            mode: .flex,
            activityCategory: .sports,
            minGroupSize: 3,
            availability: [
                AvailabilitySlot(date: Date(timeIntervalSince1970: 1740000000), hours: [9, 10, 11]),
            ],
            timeRangeStart: 9,
            timeRangeEnd: 17
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Mission.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, "Hoops")
        XCTAssertEqual(decoded.mode, .flex)
        XCTAssertEqual(decoded.activityCategory, .sports)
        XCTAssertEqual(decoded.minGroupSize, 3)
        XCTAssertEqual(decoded.availability?.count, 1)
        XCTAssertEqual(decoded.availability?.first?.hours, [9, 10, 11])
    }

    // MARK: - PodSummary Tests

    func testPodSummarySpotsLeft() {
        let json = """
        {"pod_id": "p1", "member_count": 2, "max_size": 4, "status": "open"}
        """.data(using: .utf8)!

        let pod = try! JSONDecoder().decode(PodSummary.self, from: json)
        XCTAssertEqual(pod.spotsLeft, 2)
        XCTAssertEqual(pod.podId, "p1")
    }

    func testPodSummarySpotsLeftAtCapacity() {
        let json = """
        {"pod_id": "p2", "member_count": 4, "max_size": 4, "status": "full"}
        """.data(using: .utf8)!

        let pod = try! JSONDecoder().decode(PodSummary.self, from: json)
        XCTAssertEqual(pod.spotsLeft, 0)
    }

    // MARK: - MemberPreview Tests

    func testMemberPreviewDecoding() throws {
        let json = """
        {"user_id": 42, "name": "Alice", "photo": "https://example.com/photo.jpg"}
        """.data(using: .utf8)!
        let member = try JSONDecoder().decode(MemberPreview.self, from: json)
        XCTAssertEqual(member.userId, 42)
        XCTAssertEqual(member.name, "Alice")
        XCTAssertEqual(member.photo, "https://example.com/photo.jpg")
        XCTAssertEqual(member.id, 42)
    }

    func testMemberPreviewDecodingWithoutPhoto() throws {
        let json = """
        {"user_id": 7, "name": "Bob"}
        """.data(using: .utf8)!
        let member = try JSONDecoder().decode(MemberPreview.self, from: json)
        XCTAssertEqual(member.userId, 7)
        XCTAssertEqual(member.name, "Bob")
        XCTAssertNil(member.photo)
    }

    func testPodSummaryWithMemberPreviews() throws {
        let json = """
        {
            "pod_id": "p1",
            "member_count": 3,
            "max_size": 4,
            "status": "open",
            "member_previews": [
                {"user_id": 1, "name": "Alice", "photo": "https://example.com/a.jpg"},
                {"user_id": 2, "name": "Bob"}
            ]
        }
        """.data(using: .utf8)!
        let pod = try JSONDecoder().decode(PodSummary.self, from: json)
        XCTAssertEqual(pod.memberPreviews?.count, 2)
        XCTAssertEqual(pod.memberPreviews?[0].name, "Alice")
        XCTAssertNil(pod.memberPreviews?[1].photo)
    }

    func testPodSummaryWithoutMemberPreviews() throws {
        let json = """
        {"pod_id": "p2", "member_count": 2, "max_size": 4, "status": "open"}
        """.data(using: .utf8)!
        let pod = try JSONDecoder().decode(PodSummary.self, from: json)
        XCTAssertNil(pod.memberPreviews)
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }
}
