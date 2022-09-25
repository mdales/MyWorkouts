//
//  LocationModel.swift
//  Trigtastic
//
//  Created by Michael Dales on 06/02/2022.
//

import Foundation
import CoreLocation
import Combine

protocol AbstractLocationModel {

    var latestLocationsPublisher: Published<[CLLocation]>.Publisher { get }

    var authorizationStatusPublisher: Published<CLAuthorizationStatus>.Publisher { get }

    func requestPermission()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

// This is a work around for two limitations in SwiftUI for UI test automation:
//   1: You can't use protocols for StateObjects or for @Published methods, so this
//      class is providing an abstraction layer for that.
//   2: You can't provide constructors to StateObjects, which is why you need to switch
//      between the mock and real objects here, rather than taking locationModel as a
//      parameter.
// It's all a bit icky, but so far I've not seen a better way to enable me to do UI
// testing when I have location dependancies for my data.

let kUITestingFlag = "-isUItesting"
let kUITestingLatitude = "-testLatitude"
let kUITestingLongitude = "-testLongitude"

class AnyLocationModel: ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var latestLocations: [CLLocation] = []
    var latestLocationsPublisher: Published<[CLLocation]>.Publisher {
        return $latestLocations
    }

    private let locationModel: AbstractLocationModel
    private var cancellables = Set<AnyCancellable>()

    init() {
        locationModel = ProcessInfo.processInfo.arguments.contains(kUITestingFlag) ? MockLocationModel() : LocationModel()
        locationModel.latestLocationsPublisher.sink(receiveValue: {self.latestLocations = $0}).store(in: &cancellables)
        locationModel.authorizationStatusPublisher.sink(receiveValue: {self.authorizationStatus = $0}).store(in: &cancellables)
    }

    func requestPermission() {
        locationModel.requestPermission()
    }

    func startUpdatingLocation() {
        locationModel.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationModel.stopUpdatingLocation()
    }
}

class MockLocationModel: ObservableObject, AbstractLocationModel {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    var authorizationStatusPublisher: Published<CLAuthorizationStatus>.Publisher {
        return $authorizationStatus
    }

    @Published private(set) var latestLocations: [CLLocation] = []
    var latestLocationsPublisher: Published<[CLLocation]>.Publisher {
        return $latestLocations
    }

    init() {
        authorizationStatus = .authorizedWhenInUse
    }

    func requestPermission() {
    }

    func startUpdatingLocation() {
    }

    func stopUpdatingLocation() {
    }
}

class LocationModel: NSObject, ObservableObject, CLLocationManagerDelegate, AbstractLocationModel {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    var authorizationStatusPublisher: Published<CLAuthorizationStatus>.Publisher {
        return $authorizationStatus
    }

    @Published private(set) var latestLocations: [CLLocation] = []
    var latestLocationsPublisher: Published<[CLLocation]>.Publisher {
        return $latestLocations
    }

    private let locationManager: CLLocationManager

    override init() {
        locationManager = CLLocationManager()
        authorizationStatus = locationManager.authorizationStatus

        super.init()
        locationManager.delegate = self

        locationManager.activityType = .fitness
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        latestLocations = locations
    }
}
