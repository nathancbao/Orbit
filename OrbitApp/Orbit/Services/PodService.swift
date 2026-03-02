import Foundation

class PodService {
    static let shared = PodService()
    private init() {}

    func getPod(id: String) async throws -> Pod {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.pod(id),
            authenticated: true
        )
    }

    func kickMember(podId: String, targetUserId: Int) async throws -> KickResponse {
        let body: [String: Any] = ["target_user_id": targetUserId]
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.podKick(podId),
            method: "POST",
            body: body,
            authenticated: true
        )
    }

    func leavePod(podId: String) async throws {
        let _: EmptyResponse = try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.podLeave(podId),
            method: "DELETE",
            authenticated: true
        )
    }

    func renamePod(podId: String, name: String) async throws -> Pod {
        let body: [String: Any] = ["name": name]
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.podRename(podId),
            method: "PUT",
            body: body,
            authenticated: true
        )
    }

    func confirmAttendance(podId: String) async throws -> ConfirmResponse {
        return try await APIService.shared.request(
            endpoint: Constants.API.Endpoints.podConfirm(podId),
            method: "POST",
            authenticated: true
        )
    }
}

struct KickResponse: Codable {
    var pod: Pod
    var kicked: Bool
    var message: String
}

struct ConfirmResponse: Codable {
    var pod: Pod
    var message: String
}
