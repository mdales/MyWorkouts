//
//  WorkoutStateMachine.swift
//  MyWorkouts
//
//  Created by Michael Dales on 23/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import Combine
import CoreLocation
import Foundation
import HealthKit

enum DistanceUnit: String, CaseIterable {
    case Miles
    case Kilometers
}

extension HKWorkoutActivityType {
    func DisplayString() -> String {
        switch self {
        case .running:
            return "Running"
        case .walking:
            return "Walking"
        case .cycling:
            return "Cycling"
        case .skatingSports:
            return "Skating"
        case .wheelchairRunPace:
            return "Wheelchair, fast pace"
        case .wheelchairWalkPace:
            return "Wheelchair, medium pace"
        default:
            return "Unknown activity"
        }
    }
}

extension HKWorkoutActivityType {
    func String() -> String {
        switch self {
        case .running:
            return "running"
        case .walking:
            return "walking"
        case .cycling:
            return "cycling"
        case .wheelchairRunPace:
            return "wheelchairRunPace"
        case .wheelchairWalkPace:
            return "wheelchairWalkPace"
        case .skatingSports:
            return "skatingSports"
        default:
            return "unknownWorkoutActivityType"
        }
    }

    func DistanceType() -> HKQuantityType {
        switch self {
        case .downhillSkiing:
            return HKObjectType.quantityType(forIdentifier: .distanceDownhillSnowSports)!
        case .cycling, .skatingSports:
            return HKObjectType.quantityType(forIdentifier: .distanceCycling)!
        case .running, .walking, .crossCountrySkiing, .golf:
            return HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        case .wheelchairWalkPace, .wheelchairRunPace:
            return HKObjectType.quantityType(forIdentifier: .distanceWheelchair)!
        default:
            fatalError()
        }
    }
}

struct WorkoutSplit: Hashable {
    let time: Date
    let distance: Double

    init(time: Date, distance: Double) {
        self.time = time
        self.distance = distance
    }
}

final class WorkoutStateMachine: ObservableObject {

    enum WorkoutState {
        case Before
        case WaitingForGPSToStart
        case WaitingForGPSAccuracy
        case Started
        case Paused // not yet implemented
        case Stopped
        case Failed // TODO: This should contain the error, but that breaks equitable
    }

    let peakSpeedBufferSize = 5

    @Published private(set) var currentState: WorkoutState = .Before
    @Published private(set) var activityType: HKWorkoutActivityType = .walking
    @Published private(set) var splits: [WorkoutSplit] = []

    let syncQ = DispatchQueue(label: "workout")
    var workoutBuilder: HKWorkoutBuilder?
    var routeBuilder: HKWorkoutRouteBuilder?
    var peakSpeedBuffer = [CLLocation]()
    var peakSpeed = 0.0
    var currentSpeed = 0.0
    let splitDistance: Double = 100.0
    var lastLocation: CLLocation?
    private var distance: CLLocationDistance = 0.0

    // Ideally this would be a constant set in the constructor, but because this
    // is a StateObject, I can't pass any args to the constructor, so the best we can
    // do is set it at start
    private var locationManager: AnyLocationModel?
    private var healthManager: AnyHealthModel?

    private var cancellables = Set<AnyCancellable>()


    func start(
        activity: HKWorkoutActivityType,
        locationManager: AnyLocationModel,
        healthManager: AnyHealthModel
    ) {
        dispatchPrecondition(condition: .notOnQueue(syncQ))
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))

        // TODO: handle all the permutations. Should we go to failed? if we do that
        // we need to ensure we also free up resources (i.e., do pass STOP/CANCEL)
        // or we could assert because this is a programmer error and if we're not going
        // to save fitness data when this happens there's no real loss?
        assert(currentState == .Before)

        syncQ.sync {
            activityType = activity
            self.locationManager = locationManager
            self.healthManager = healthManager

            assert(workoutBuilder == nil)
            assert(routeBuilder == nil)

            self.distance = 0.0

            let config = HKWorkoutConfiguration()
            config.activityType = activityType
            config.locationType = .outdoor

            let builder = healthManager.newHealthBuilderForConfig(config: config)
            workoutBuilder = builder

            HKSeriesType.workoutRoute()
            self.routeBuilder = healthManager.newRouteBuilder()

            // published, so must be updated on main queue. At some point I'll tidy this up,
            // but for now it's like safe to assume start is called from a button and this on
            // main therad
            self.currentState = .WaitingForGPSToStart
            self.splits.removeAll()
        }

        locationManager.latestLocationsPublisher
            .receive(on: syncQ)
            .sink(receiveValue: { location in
            self.processLocationUpdate(locations: location)

        })
        .store(in: &cancellables)

        locationManager.startUpdatingLocation()
    }

    func pause() {
        // TODO: TODO
        assert(false)
    }

    func stop() {
        dispatchPrecondition(condition: .notOnQueue(syncQ))
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))

        syncQ.sync {
            if let locationManager = self.locationManager {
                locationManager.stopUpdatingLocation()
            }

            guard let workoutBuilder = self.workoutBuilder else {
                // TODO: handle error
                return
            }

            // XXXX if not start date we didn't get a GPS lock...
            if currentState == .WaitingForGPSToStart || currentState == .WaitingForGPSAccuracy {
                self.workoutBuilder = nil
                routeBuilder = nil
                currentState = .Stopped
                return
            }

            let endDate = Date()

            // Add one final split
            self.splits.append(WorkoutSplit(time: endDate, distance: distance))

            let distanceQuantity = HKQuantity(unit: HKUnit.meter(), doubleValue: self.distance)
            let distanceSample = HKQuantitySample(type: self.activityType.DistanceType(),
                                                  quantity: distanceQuantity,
                                                  start: workoutBuilder.startDate!,
                                                  end: endDate)

            let peakSpeedQuantity = HKQuantity(unit: HKUnit.meter().unitDivided(by: HKUnit.second()), doubleValue: self.peakSpeed)

            let duration = endDate.timeIntervalSince(workoutBuilder.startDate!)
            let averageSpeed = self.distance / duration
            let averageSpeedQuantity = HKQuantity(unit: HKUnit.meter().unitDivided(by: HKUnit.second()), doubleValue: averageSpeed)


            workoutBuilder.addMetadata([HKMetadataKeyMaximumSpeed: peakSpeedQuantity, HKMetadataKeyAverageSpeed: averageSpeedQuantity], completion: { (success, error) in

                if let err = error {
                    print("Failed to add metadata: \(err)")
                }
                if !success {
                    print("adding metadata wasn't a success")
                }

                workoutBuilder.add([distanceSample]) { (success, error) in
                    if let err = error {
                        print("Failed to add distance sample: \(err)")
                    }
                    if !success {
                        print("adding distance sample wasn't a success")
                    }
                    print("distance \(distanceSample) was accepted")

                    workoutBuilder.endCollection(withEnd: endDate, completion: { (success, error) in
                        dispatchPrecondition(condition: .notOnQueue(self.syncQ))
                        if error != nil {
                            self.syncQ.sync {
                                self.workoutBuilder = nil
                                self.routeBuilder = nil
                                self.currentState = .Failed
                            }
                            return
                        }
                        if !success {
                            self.syncQ.sync {
                                self.workoutBuilder = nil
                                self.routeBuilder = nil
                                self.currentState = .Failed
                            }
                            return
                        }

                        workoutBuilder.finishWorkout(completion: { (workout, error) in
                            dispatchPrecondition(condition: .notOnQueue(self.syncQ))
                            if error != nil {
                                self.syncQ.sync {
                                    self.workoutBuilder = nil
                                    self.routeBuilder = nil
                                    self.currentState = .Failed
                                }
                                return
                            }
                            guard let finishedWorkout = workout else {
                                self.syncQ.sync {
                                    self.workoutBuilder = nil
                                    self.routeBuilder = nil

                                    self.currentState = .Failed

                                }
                                return
                            }

                            self.syncQ.sync {
                                self.workoutBuilder = nil
                                self.routeBuilder?.finishRoute(with: finishedWorkout, metadata: nil, completion: { (route, error) in
                                    dispatchPrecondition(condition: .notOnQueue(self.syncQ))
                                    self.syncQ.sync {
                                        self.routeBuilder = nil
                                        DispatchQueue.main.async {
                                            self.currentState = .Stopped
                                        }
                                    }
                                })
                            }
                        })
                    })
                }
            })
        }

        for cancellable in cancellables {
            cancellable.cancel()
        }
        cancellables.removeAll()
    }

    func processLocationUpdate(locations: [CLLocation]) {
        // TODO: assert on syncQ and assert not on mainQ
        dispatchPrecondition(condition: .notOnQueue(DispatchQueue.main))

        guard let builder = workoutBuilder else {
            return
        }

        var nextState = currentState
        var newSplits: [WorkoutSplit] = []
        var filteredLocations = locations

        if currentState == .WaitingForGPSAccuracy || currentState == .WaitingForGPSToStart {
            var remaining = [CLLocation]()

            for location in locations {

                if lastLocation == nil {
                    lastLocation = location
                    continue
                }

                let newDistance = location.distance(from: lastLocation!)
                if newDistance > 10.0 {
                    print("distance: \(newDistance)")
                    lastLocation = location
                    continue
                }

                switch currentState {
                case .WaitingForGPSAccuracy, .WaitingForGPSToStart:

                    print("speed: \(location.speed)")

                    switch Int(location.horizontalAccuracy) {
                    case 0...10:
                        nextState = .Started

                        let startDate = Date()
                        builder.beginCollection(withStart: startDate, completion: { (success, error) in

                            dispatchPrecondition(condition: .notOnQueue(self.syncQ))
                            self.syncQ.sync {

                                if error != nil {
                                    self.locationManager!.stopUpdatingLocation()
                                    self.workoutBuilder = nil
                                    self.currentState = .Failed
                                    return
                                }

                                // we assume if there was no error everything is okay
                                assert(success)
                            }
                        })

                        newSplits.append(WorkoutSplit(time: startDate, distance: 0.0))
                        remaining.append(location)
                    default:
                        if currentState == .WaitingForGPSToStart {
                            nextState = .WaitingForGPSAccuracy
                        }
                        break
                    }
                default:
                    remaining.append(location)
                }
            }
            filteredLocations = remaining
        }

        let oldFiltered = filteredLocations
        filteredLocations = oldFiltered.filter() { return $0.horizontalAccuracy <= 10.0 }

        if nextState == .Started {
            guard let builder = routeBuilder else {
                return
            }

            for location in filteredLocations {
                if let last = lastLocation {
                    let newDistance = location.distance(from: last)
                    distance += newDistance

                    if distance > (self.splitDistance * Double(self.splits.count)) {
                        newSplits.append(WorkoutSplit(time: location.timestamp, distance: distance))
                    }
                }
                lastLocation = location

                if peakSpeedBuffer.count >= peakSpeedBufferSize {
                    peakSpeedBuffer.remove(at: 0)
                }
                peakSpeedBuffer.append(location)
                if peakSpeedBuffer.count == peakSpeedBufferSize {

                    // If any individual hop in the buffer is faster than
                    // an olypian 100m sprint, disregard the entire buffer, as
                    // the GPS jumps are ruinous
                    var possible = true
                    for i in 1..<peakSpeedBufferSize {
                        let duration = peakSpeedBuffer[i].timestamp.timeIntervalSince(peakSpeedBuffer[i-1].timestamp)
                        let distance = peakSpeedBuffer[i].distance(from: peakSpeedBuffer[i-1])
                        let speed = distance / duration
                        if speed > 10.0 {
                            possible = false
                            break
                        }
                    }

                    if possible {
                        let last = peakSpeedBuffer[0]
                        let currentDuration = location.timestamp.timeIntervalSince(last.timestamp)
                        let currentDistance = location.distance(from: last)
                        self.currentSpeed = currentDistance / currentDuration
                        if self.currentSpeed > self.peakSpeed {
                            self.peakSpeed = self.currentSpeed
                        }
                    }
                }
            }

            builder.insertRouteData(filteredLocations) { (success, error) in
                if let err = error {
                    print("Failed to insert data! \(err)")
                } else if !success {
                    print("Failed to insert data")
                }
            }
        }

        DispatchQueue.main.sync {
            if nextState != currentState {
                currentState = nextState
            }
            if newSplits.count > 1 {
                self.splits += newSplits
            }
        }
    }
}
