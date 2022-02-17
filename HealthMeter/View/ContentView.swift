//
//  ContentView.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 23.1.2022.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @ObservedObject var settingsStore = SettingsStore()
    @State private var showingInfoMenu = false
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
                        showingInfoMenu.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 24, weight: .medium))
                    }
                    .padding(.trailing)
                    .sheet(isPresented: $showingInfoMenu) {
                        InfoView(viewModel: InfoView.ViewModel(heartRateService: heartRateService))
                    }
                }
            }

            Spacer()
            if settingsStore.tutorialShown {
                if heartRateService.isHealthDataAvailable {
                    HeartView(viewModel: HeartView.ViewModel(heartRateService: heartRateService))
                    // HeartView(viewModel: HeartView.ViewModel(heartRateService: MockHeartRateService())) // uncomment this for App Store screenshots
                } else {
                    NoHealthKitView()
                }
            }
            Spacer()
                .sheet(isPresented: $showingTutorialMenu) {
                    settingsStore.tutorialShown = true
                } content: {
                    if heartRateService.isHealthDataAvailable {
                        TutorialView(settingsStore: settingsStore,
                                     viewModel: TutorialView.ViewModel(heartRateService: heartRateService))
                            .interactiveDismissDisabled(true)
                    } else {
                        NoHealthKitView()
                            .interactiveDismissDisabled(true)
                    }
                }
        }
    }
}

/**
 Shown when the device doesn't have the HealthKit available.
 */
struct NoHealthKitView: View {
    var body: some View {
        Text("Your device doesn't have access to HealthKit. Restful requires access to HealthKit")
            .font(.title2)
            .bold()
            .padding()
        Spacer()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
