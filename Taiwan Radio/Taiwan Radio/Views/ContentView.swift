//
//  ContentView.swift
//  Taiwan Radio
//
//  Created by marc huang on 2026/4/10.
//

import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: RadioViewModel
    @State private var isShowingSettings = false

    private let shouldFetchStations: Bool

    init() {
        _viewModel = StateObject(wrappedValue: RadioViewModel())
        shouldFetchStations = true
    }

    fileprivate init(previewViewModel: RadioViewModel, shouldFetchStations: Bool) {
        _viewModel = StateObject(wrappedValue: previewViewModel)
        self.shouldFetchStations = shouldFetchStations
    }

    var body: some View {
        VStack(spacing: 0) {
            SectionPickerView(viewModel: viewModel)
            StationListView(viewModel: viewModel)
            RecentActionsBarView(viewModel: viewModel)
            PlayerBarView(viewModel: viewModel) {
                isShowingSettings = true
            }
        }
        .frame(minWidth: 520, minHeight: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(.dark)
        .task {
            guard shouldFetchStations else { return }
            await viewModel.fetchStations()
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(viewModel: viewModel)
        }
    }
}

#if DEBUG
extension ContentView {
    static var previewHarness: some View {
        ContentView(
            previewViewModel: .preview(),
            shouldFetchStations: false
        )
        .frame(width: 520, height: 640)
    }
}
#endif
