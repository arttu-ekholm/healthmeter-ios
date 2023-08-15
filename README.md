# HealthMeter

Get a push notification when your resting heart is elevated.

## About

HealthMeter monitors the resting heart rate (RHR) and resting wrist temperature from HealthKit and sends a push notification when either measurement is elevated. Everything is done locally on the device and the notifications are local notifications. The app doesn't require or use network connection.

## Requirements

The app requires a HealthKit-capable device and another device that measures and stores resting heart rate (such as Apple Watch).

## Motivation

I created this project for several reasons:
1. I wanted to improve my skills with SwiftUI & MVVM architecture and animations
2. to make an application with testable architecture
3. to get an early warning when I might be getting a flu.
4. I like the idea of having apps with minimal user interface that interact with the user via push notifications or widgets
5. I'm too cheap to buy an Oura ring

## Installation and usage

Clone the project and hit Build & run on an iPhone device. The app can also be run on a simulator, but the HealthKit records need to be added manually using Health app. 

## External dependencies

External dependencies are managed by Swift packages.


## App Store

The app is available for free in the App Store as [Restful - Heart rate monitor](https://apps.apple.com/fi/app/restful-heart-rate-monitor/id1610317388?l=en).
