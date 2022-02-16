//
//  DebugView.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 14.2.2022.
//

import SwiftUI

struct DebugView: View {
    let heartRateService: RestingHeartRateService
    /// Value for mock update text field
    @State var debugValue: Double = 50.0
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {

            HStack {
                Spacer()
                Button("Dismiss") {
                    dismiss()
                }
                .padding()
            }
            Spacer()
            Text("Debug view:")
            latestHighRHR(date: heartRateService.latestHighRHRNotificationPostDate)
            latestLowRHR(date: heartRateService.latestLoweredRHRNotificationPostDate)
            latestDebugDate(date: heartRateService.latestDebugNotificationDate)

            TextField("", value: $debugValue, format: .number)
                .keyboardType(.numberPad)

            Button("Handle fake update") {
                heartRateService.handleDebugUpdate(update: RestingHeartRateUpdate(date: Date(), value: debugValue))
            }
            Spacer()
        }
    }

    private func latestHighRHR(date: Date?) -> Text {
        guard let date = date else { return Text("No high HRH notification") }

        return Text("Latest high HRH notification: \(date)")
    }

    private func latestLowRHR(date: Date?) -> Text {
        guard let date = date else { return Text("No low HRH notification") }

        return Text("Latest low HRH notification: \(date)")
    }

    private func latestDebugDate(date: Date?) -> Text {
        guard let date = date else { return Text("No debug HRH notification") }

        return Text("Latest debug HRH notification: \(date)")
    }
}

struct DebugView_Previews: PreviewProvider {
    static var previews: some View {
        DebugView(heartRateService: RestingHeartRateService.shared)
    }
}
