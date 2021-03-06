# HealthMeter

Get a push notification when your resting heart is elevated.

## About

HealthMeter monitors the resting heart rate (RHR) from HealthKit and sends a push notification when the RHR is above your average. Everything is done locally on the device and the notifications are local notifications.

## Requirements

The app requires a HealthKit-capable device and another device that measures and stores resting heart rate (such as Apple Watch or Oura ring). 

## Motivation

I created this project for several reasons:
1. I wanted to improve my skills with SwiftUI & MVVM architecture and animations
2. to make an application with testable architecture
3. to get an early warning when I might be getting a flu.
4. I like the idea of having apps with minimal user interface that interact with the user via push notifications or widgets.

## Installation and usage

Clone the project and run `pod install` in the project root. Build & run on an iPhone. With simulator, the app shows an error view telling it can't query the resting heart rate values.   

## External dependencies

This project uses [CocoaPods](https://cocoapods.org) as external dependency manager. At the moment, the only dependency is [SwiftLint](https://github.com/realm/SwiftLint), which only helps to write well-formatted code.

## App Store

This project is also available in the App Store as [Restful - Heart rate monitor](https://apps.apple.com/fi/app/restful-heart-rate-monitor/id1610317388?l=en).
