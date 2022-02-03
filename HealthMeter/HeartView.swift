//
//  HeartView.swift
//  HealthMeter
//
//  Created by Arttu Ekholm on 2.2.2022.
//

import SwiftUI

enum HeartViewState {
    case animating
    case failed
    case loading
}

struct HeartView: View {
    @State private var animationAmount: CGFloat = 1
    @State var state: HeartViewState = .loading

    var body: some View {
        switch state {
        case .loading:
            Image(systemName: "heart.text.square")
                .resizable()
                .frame(width: 100, height: 100, alignment: .center)
                .foregroundColor(.red)
        case .failed:
            Image(systemName: "heart.slash")
                .resizable()
                .frame(width: 100, height: 100, alignment: .center)
                .foregroundColor(.red)
        case .animating:
            Image(systemName: "heart")
                .resizable()
                .frame(width: 100, height: 100, alignment: .center)
                .foregroundColor(.red)
                .scaleEffect(animationAmount)
                .animation(
                    .spring(response: 0.3, dampingFraction: 0.4, blendDuration: 0.0)
                        .delay(0.01)
                        .repeatForever(autoreverses: true),
                    value: animationAmount
                )
                .onAppear {
                    animationAmount = 1.08
                }
        }

    }
}
