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
    @State var shouldDisplayHealthKitAuthorisation = false
    @ObservedObject var settingsStore = SettingsStore()
    @State private var showingDebugMenu = false
    @State private var showingTutorialMenu = !SettingsStore().tutorialShown

    let heartRateService: RestingHeartRateService = RestingHeartRateService.shared

    var body: some View {
        Text("HealthMeter")
            .font(.title)
            .bold()
            .padding()
        Button("Show debug menu") {
            showingDebugMenu.toggle()
        }
        .sheet(isPresented: $showingDebugMenu) {
            InfoView(viewModel: InfoView.ViewModel(heartRateService: heartRateService))
        }
        Spacer()
        if settingsStore.tutorialShown {
            if !shouldDisplayHealthKitAuthorisation {
                HeartView(viewModel: HeartView.ViewModel(heartRateService: heartRateService))
            }
            Text("") // TODO: remove this
                .onAppear {
                    heartRateService.getAuthorisationStatusForRestingHeartRate(completion: { status in
                        shouldDisplayHealthKitAuthorisation = (status == .unknown || status == .shouldRequest)
                    })
                }
        }
        Spacer()
            .sheet(isPresented: $showingTutorialMenu) {
                settingsStore.tutorialShown = true
            } content: {
                TutorialView(settingsStore: settingsStore,
                             heartRateService: heartRateService,
                             viewModel: TutorialView.ViewModel())
                    .interactiveDismissDisabled(true)
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
