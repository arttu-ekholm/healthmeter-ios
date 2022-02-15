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
            DebugView(heartRateService: heartRateService)
        }
        Spacer()
        if settingsStore.tutorialShown {
            if !shouldDisplayHealthKitAuthorisation {
                HeartView(viewModel: HeartView.ViewModel(heartRateService: heartRateService))
            }
            Text("")
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
                TutorialView(settingsStore: settingsStore, heartRateService: heartRateService, viewModel: TutorialView.ViewModel())
            }

    }

    func averageHeartRateText(result: Result<Double, Error>?) -> Text? {
        guard let result = result else { return nil }

        switch result {
        case .success(let avgHeartRate):
            return Text("Your heart rate is \(avgHeartRate) bpm")
        case .failure(let error):
            return Text("Heart rate query failed with an error: \(error.localizedDescription)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

class SettingsStore: ObservableObject {
    static let tutorialShownKey = "tutorialShown"
    @Published var tutorialShown: Bool = UserDefaults.standard.bool(forKey: SettingsStore.tutorialShownKey) {
        didSet {
            UserDefaults.standard.set(self.tutorialShown, forKey: SettingsStore.tutorialShownKey)
        }
    }
}
