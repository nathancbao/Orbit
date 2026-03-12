//
//  LocationSearchView.swift
//  Orbit
//
//  Real location search using MapKit autocomplete.
//  No API key required — uses on-device MKLocalSearchCompleter.
//

import SwiftUI
import MapKit
import Combine

// MARK: - Location Search View

struct LocationSearchView: View {
    @Binding var locationName: String
    @Environment(\.dismiss) private var dismiss

    @StateObject private var completer = LocationCompleter()
    @State private var searchText = ""
    @State private var isResolving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(OrbitTheme.gradient)
                    TextField("Search for a place...", text: $searchText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .onChange(of: searchText) { _, newValue in
                    completer.search(query: newValue)
                }

                Divider()

                if completer.results.isEmpty && !searchText.isEmpty && !completer.isSearching {
                    Spacer()
                    Text("No results for \"\(searchText)\"")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Spacer()
                } else {
                    List(completer.results, id: \.self) { result in
                        Button {
                            resolve(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if isResolving {
                    Color.black.opacity(0.08)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.3)
                        .tint(OrbitTheme.purple)
                }
            }
        }
    }

    private func resolve(_ result: MKLocalSearchCompletion) {
        isResolving = true
        let request = MKLocalSearch.Request(completion: result)
        MKLocalSearch(request: request).start { response, _ in
            DispatchQueue.main.async {
                isResolving = false
                guard let item = response?.mapItems.first else { return }
                let parts = [result.title, result.subtitle].filter { !$0.isEmpty }
                locationName = parts.joined(separator: ", ")
                dismiss()
            }
        }
    }
}

// MARK: - Location Completer

class LocationCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var isSearching = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]
    }

    func search(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { results = []; return }
        isSearching = true
        completer.queryFragment = trimmed
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.isSearching = false
            self.results = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isSearching = false
            self.results = []
        }
    }
}
