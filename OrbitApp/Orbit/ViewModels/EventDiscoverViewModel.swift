import Foundation
import Combine

@MainActor
class EventDiscoverViewModel: ObservableObject {
    @Published var suggestedEvents: [Event] = []
    @Published var allEvents: [Event] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var filterTag: String?
    @Published var showMyYearOnly = false

    private var userYear: String = ""

    func load(userYear: String) async {
        self.userYear = userYear
        isLoading = true
        errorMessage = nil

        async let suggested = try? EventService.shared.suggestedEvents()
        async let all = try? EventService.shared.listEvents(
            tag: filterTag,
            year: showMyYearOnly ? userYear : nil
        )

        suggestedEvents = await suggested ?? []
        allEvents = await all ?? []
        isLoading = false
    }

    func reload() async {
        await load(userYear: userYear)
    }

    func applyTag(_ tag: String?) async {
        filterTag = tag
        await reload()
    }

    func toggleYearFilter() async {
        showMyYearOnly.toggle()
        await reload()
    }

    func skipEvent(_ event: Event) async {
        try? await EventService.shared.skipEvent(id: event.id)
        allEvents.removeAll { $0.id == event.id }
        suggestedEvents.removeAll { $0.id == event.id }
    }
}
