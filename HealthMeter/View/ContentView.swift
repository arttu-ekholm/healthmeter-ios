//
//  ContentView.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 23.1.2022.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @Environment(\.scenePhase) var scenePhase
    @ObservedObject var settingsStore = SettingsStore()
    @State private var showingDebugMenu = false
    @State private var showingTutorialMenu = !SettingsStore().tutorialShown

    let heartRateService: RestingHeartRateService = RestingHeartRateService.shared

    var body: some View {
        VStack {
            ZStack {
                HStack {
                    Text("Restful")
                        .font(.title)
                        .bold()
                        .padding()
                }
                HStack {
                    Spacer()
                    Button {
                        showingDebugMenu.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 24, weight: .medium))
                    }
                    .padding(.trailing)
                    .sheet(isPresented: $showingDebugMenu) {
                        InfoView(viewModel: InfoView.ViewModel(heartRateService: heartRateService))
                    }
                }
            }

            Spacer()
            if settingsStore.tutorialShown {
                HeartView(viewModel: HeartView.ViewModel(heartRateService: heartRateService))
                //HeartView(viewModel: HeartView.ViewModel(heartRateService: MockHeartRateService()))
            }
            Spacer()
                .sheet(isPresented: $showingTutorialMenu) {
                    settingsStore.tutorialShown = true
                } content: {
                    TutorialView(settingsStore: settingsStore,
                                 viewModel: TutorialView.ViewModel(heartRateService: heartRateService))
                        .interactiveDismissDisabled(true)
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
