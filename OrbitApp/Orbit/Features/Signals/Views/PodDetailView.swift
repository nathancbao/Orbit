//
//  PodDetailView.swift
//  Orbit
//
//  Active group view — shows pod members with contact info reveal.
//  Card layout with 7-day expiry countdown.
//

import SwiftUI

struct PodDetailView: View {
    let pod: Pod
    let members: [PodMember]
    let revealed: Bool

    @State private var showContactForm = false
    @State private var instagramInput = ""
    @State private var phoneInput = ""
    @State private var isSaving = false

    var body: some View {
        ZStack {
            // Space background
            Color(red: 0.05, green: 0.05, blue: 0.15)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("You're in Orbit!")
                            .font(.title2.bold())
                            .foregroundColor(.white)

                        // 7-day badge
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .font(.caption)
                            if let expiresAt = pod.expiresAt {
                                Text("\(timeRemaining(from: expiresAt)) remaining")
                                    .font(.caption)
                            } else {
                                Text("7-day group")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                    }
                    .padding(.top, 20)

                    // Contact reveal status
                    if !revealed {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("Contact info will be revealed soon")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    }

                    // Member cards
                    ForEach(members) { member in
                        memberCard(member)
                    }

                    // Update contact info button
                    Button(action: { showContactForm = true }) {
                        Label("Update Your Contact Info", systemImage: "pencil.circle")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showContactForm) {
            contactFormSheet
        }
    }

    // MARK: - Member Card

    private func memberCard(_ member: PodMember) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Avatar + name
            HStack(spacing: 12) {
                Circle()
                    .fill(memberColor(for: member.name))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(member.name.prefix(1).uppercased())
                            .font(.title3.bold())
                            .foregroundColor(.white)
                    )
                    .shadow(color: memberColor(for: member.name).opacity(0.4), radius: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(member.interests.prefix(3).joined(separator: " · "))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()
            }

            // Contact info (if revealed)
            if revealed, let contact = member.contactInfo {
                Divider()
                    .background(Color.white.opacity(0.1))

                HStack(spacing: 16) {
                    if let instagram = contact.instagram, !instagram.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.caption2)
                                .foregroundColor(.purple)
                            Text(instagram)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    if let phone = contact.phone, !phone.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text(phone)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.07))
        .cornerRadius(16)
    }

    // MARK: - Contact Form Sheet

    private var contactFormSheet: some View {
        NavigationView {
            Form {
                Section("Your Contact Info") {
                    TextField("Instagram handle", text: $instagramInput)
                        .textContentType(.username)
                        .autocapitalization(.none)

                    TextField("Phone number", text: $phoneInput)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }

                Section {
                    Button(action: saveContactInfo) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving || (instagramInput.isEmpty && phoneInput.isEmpty))
                }
            }
            .navigationTitle("Contact Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showContactForm = false }
                }
            }
        }
    }

    // MARK: - Actions

    private func saveContactInfo() {
        isSaving = true
        Task {
            do {
                _ = try await SignalService.shared.updateContactInfo(
                    instagram: instagramInput.isEmpty ? nil : instagramInput,
                    phone: phoneInput.isEmpty ? nil : phoneInput
                )
                showContactForm = false
            } catch {
                // Silently handle for now
            }
            isSaving = false
        }
    }

    // MARK: - Helpers

    private func memberColor(for name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .orange, .pink, .green, .cyan, .indigo, .mint]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }

    private func timeRemaining(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "7 days" }
        let remaining = date.timeIntervalSinceNow
        if remaining <= 0 { return "expired" }
        let days = Int(remaining / 86400)
        let hours = Int(remaining.truncatingRemainder(dividingBy: 86400) / 3600)
        if days > 0 { return "\(days)d \(hours)h" }
        return "\(hours)h"
    }
}

#Preview {
    PodDetailView(
        pod: Pod(
            id: "preview-pod",
            members: [0, 1, 2, 3],
            createdAt: nil,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(6 * 24 * 3600)),
            revealed: true,
            signalId: "sig-1"
        ),
        members: [
            PodMember(userId: 1, name: "Alex", interests: ["Hiking", "Photography"],
                      contactInfo: ContactInfo(instagram: "@alex_explores", phone: nil)),
            PodMember(userId: 2, name: "Jordan", interests: ["Music", "Gaming"],
                      contactInfo: ContactInfo(instagram: "@jordan_beats", phone: "555-0102")),
            PodMember(userId: 3, name: "Sam", interests: ["Cooking", "Travel"],
                      contactInfo: ContactInfo(instagram: "@sam_creates", phone: nil)),
        ],
        revealed: true
    )
}
