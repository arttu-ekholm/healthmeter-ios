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
    @State var debugValue: Double = 100.0
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .padding()
            }
            Spacer()

            Text("How HealthMeter does work?")
                .font(.title2)
                .bold()

            Text(notificationFootnoteString)
                .font(.footnote)
                .foregroundColor(.secondary)

            if let date = heartRateService.latestHighRHRNotificationPostDate, Calendar.current.isDateInToday(date) {
                Text("You have received a notification about your elevated resting heart rate today.")
            }

            Spacer()

            if let date = heartRateService.latestHighRHRNotificationPostDate {
                Text("The last time HealthMeter notified you about elevated resting heart rate was \(date.timeAgoDisplay())")
                    .padding()
            } else {
                Text("No elevated resting heart levels detected.")
                    .padding()
            }

            Spacer()

            VStack(alignment: .center, spacing: 12, content: {
                Text("Test the notification")
                    .font(.title3)
                    .bold()
                HStack {
                    Spacer()
                    Stepper("Fake resting heart rate: \(String(format: "%.0f", (debugValue))) bpm", value: $debugValue, in: 1...150)
                        .font(.footnote)
                    Spacer()
                }
                Button {
                    heartRateService.handleDebugUpdate(update: RestingHeartRateUpdate(date: Date(), value: debugValue))
                } label: {
                    Text("Handle fake update")
                        .bold()
                }
                .font(.title2)
                .padding()
                .foregroundColor(.white)
                .background(.blue)
                .cornerRadius(12)
                Text(fakeUpdateDescriptionText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            })
                .padding()
                .border(.secondary, width: 2)

            Spacer()
        }
        .onAppear(perform: {
            if let averageHeartRate = heartRateService.averageHeartRate {
                debugValue = averageHeartRate * 1.1 // this heart rate is above the threshold and will trigger the notification
            }
        })
        .padding()
    }

    private var fakeUpdateDescriptionText: String {
        return """
        Tapping the button will make the app to process a fake resting heart rate update with a resting heart rate of \(String(format: "%.0f", (debugValue))) bpm.

        The value won't be saved to the HealthKit database and it won't affect the notifications you'd receive from HealthMeter normally, so it's safe to test the update.
        """
    }

    private var notificationFootnoteString: String {
        let thresholdRestingHeartRate: String
        if let averageHeartRate = heartRateService.averageHeartRate {
            thresholdRestingHeartRate = String(format: " (above %.0f bpm)", averageHeartRate * 1.05)
        } else {
            thresholdRestingHeartRate = ""
        }

        return """
        If HealthMeter detects an elevated resting heart rate\(thresholdRestingHeartRate), you'll receive a push notification. You'll be notified only once per day about elevated resting heart rate.
        """
    }

    private func latestHighRHR(date: Date?) -> Text {
        guard let date = date else { return Text("No high HRH notification") }

        return Text("Latest high HRH notification: \(date)")
    }

    private func latestLowRHR(date: Date?) -> Text {
        guard let date = date else { return Text("No low HRH notification") }

        return Text("Latest low HRH notification: \(date)")
    }
}

struct DebugView_Previews: PreviewProvider {
    static var previews: some View {
        DebugView(heartRateService: RestingHeartRateService.shared)
    }
}
