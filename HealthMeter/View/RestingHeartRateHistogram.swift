//
//  RestingHeartRateHistogram.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 24.2.2022.
//

import SwiftUI

struct RestingHeartRateHistogram: View {
    let histogram: RestingHeartRateHistory
    let levels: HeartRateRanges
    let average: Double
    let active: Double
    @State var spacing: CGFloat = 4.0

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(histogram.histogramItems, id: \.self) { item in
                    let width = (geometry.size.width / CGFloat(histogram.histogramItems.count)) - spacing
                    HistogramBar(
                        item: item,
                        value: normalizedValue(value: item.count,
                                               maximumValue: histogram.maximumValue),
                        level: levels.levelForRestingHeartRate(rate: Double(item.item)) ?? nil,
                        isAverage: Int(average) == item.item,
                        isActive: Int(active) == item.item)
                        .frame(width: width, alignment: .bottom)
                }
            }
        }
    }

    func normalizedValue(value: Int, maximumValue: Int) -> Double {
        return Double(value) / Double(maximumValue)
    }
}

private let history = RestingHeartRateHistory(histogramItems: [
    RestingHeartRateHistogramItem(item: 50, count: 3),
    RestingHeartRateHistogramItem(item: 51, count: 0),
    RestingHeartRateHistogramItem(item: 52, count: 4),
    RestingHeartRateHistogramItem(item: 53, count: 6),
    RestingHeartRateHistogramItem(item: 54, count: 8),
    RestingHeartRateHistogramItem(item: 55, count: 4),
    RestingHeartRateHistogramItem(item: 56, count: 3),
    RestingHeartRateHistogramItem(item: 57, count: 1),
    RestingHeartRateHistogramItem(item: 58, count: 3),
    RestingHeartRateHistogramItem(item: 59, count: 0),
    RestingHeartRateHistogramItem(item: 60, count: 4),
    RestingHeartRateHistogramItem(item: 61, count: 6),
    RestingHeartRateHistogramItem(item: 62, count: 8),
    RestingHeartRateHistogramItem(item: 63, count: 4),
    RestingHeartRateHistogramItem(item: 64, count: 3),
    RestingHeartRateHistogramItem(item: 65, count: 1)
])

struct RestingHeartRateHistogram_Previews: PreviewProvider {
    static var previews: some View {
        RestingHeartRateHistogram(
            histogram: history,
            levels: RestingHeartRateService.shared.rangesForHeartRateLevels(average: 50.0),
            average: 50.0,
            active: 52.0)
            .frame(width: 350, height: 200, alignment: .bottom)
    }
}

private struct HistogramBar: View {
    let item: RestingHeartRateHistogramItem
    let value: Double
    let level: HeartRateLevel?
    let isAverage: Bool
    let isActive: Bool

    var body: some View {
        VStack {
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 4.0)
                    .foregroundColor(color)
                    .brightness(isActive ? 0.1 : 0)
                    .frame(width: geometry.size.width, height: geometry.size.height * value, alignment: .bottom)
                    .offset(x: 0, y: geometry.size.height * (1 - value))

            }
            Text(text)
                .font(.footnote)
                .foregroundColor(.white)
                .fontWeight(isAverage ? .heavy : .regular)
                .padding(.horizontal, isAverage ? 6 : 4)
                .background(text != " " ? color : .clear)
                .cornerRadius(5)
                .fixedSize()
        }
    }

    private var text: String {
        if isAverage { return String(item.item) }
        return item.item.isMultiple(of: 5) ? String(item.item) : " "
    }

    private var color: Color {
        return colorForLevel(level)
    }
}
