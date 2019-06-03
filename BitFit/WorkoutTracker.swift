//
//  WorkoutTracker.swift
//  BitFit
//
//  Created by Michael Dales on 29/05/2019.
//  Copyright © 2019 Digital Flapjack Ltd. All rights reserved.
//

import Foundation
import HealthKit
import CoreLocation

enum DistanceUnit: String {
    case Miles
    case Kilometers
}

enum WorkoutState {
    case Before
    case WaitingForLocationStream
    case WaitingForGPS
    case Started
    case Paused // not yet implemented
    case Stopped
    case Failed
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
        default:
            return "unknownWorkoutActivityType"
        }
    }
    
    func DistanceType() -> HKQuantityType {
        switch self {
        case .downhillSkiing:
            return HKObjectType.quantityType(forIdentifier: .distanceDownhillSnowSports)!
        case .cycling:
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

enum WorkoutTrackerError: Error {
    case UnexplainedBeginingFailure
    case WorkoutAlreadyStarted
    case NoWorkoutStarted
    case ErrorEndingCollection
    case MissingWorkout
}

struct WorkoutSplit {
    let time: Date
    let distance: Double
    
    init(time: Date, distance: Double) {
        self.time = time
        self.distance = distance
    }
}

protocol WorkoutTrackerDelegate {
    /**
     * Lets the delegate know the workout state has changed, so i can update the UI appropriately.
     *
     * - Parameters:
     *   - newState: The current state the workout is now in.
     */
    func stateUpdated(newState: WorkoutState)
    
    /**
     * Provides updated split information to the UI.
     *
     * - Parameters:
     *   - latestSplits: A copy of the most recent split data, usually provided as the split is
     *                   passed.
     *   - finalUpdate: If true, this will be the last split data for this workout.
     */
    func splitsUpdated(latestSplits: [WorkoutSplit], finalUpdate: Bool)
}

class WorkoutTracker: NSObject {
    
    static let supportedWorkouts: [HKWorkoutActivityType] = [.walking,
                                                             .running,
                                                             .cycling,
                                                             .wheelchairWalkPace,
                                                             .wheelchairRunPace]
    
    let syncQ = DispatchQueue(label: "workout")
    let delegateQ = DispatchQueue(label: "workout delegate")
    
    let activityType: HKWorkoutActivityType
    let splitDistance: Double
    let locationManager: CLLocationManager
    
    let delegate: WorkoutTrackerDelegate
    
    // Should only be updated on syncQ
    var state = WorkoutState.Before
    var splits = [WorkoutSplit]()
    var peakSpeed = 0.0
    var currentSpeed = 0.0
    var workoutBuilder: HKWorkoutBuilder?
    var routeBuilder: HKWorkoutRouteBuilder?
    var lastLocation: CLLocation?
    private var distance: CLLocationDistance = 0.0
    
    var estimatedDistance: Double {
        get {
            dispatchPrecondition(condition: .notOnQueue(syncQ))
            var res = 0.0
            syncQ.sync {
                res = distance
            }
            return res
        }
    }
    
    var startDate: Date? {
        get {
            dispatchPrecondition(condition: .notOnQueue(syncQ))
            var res: Date? = nil
            syncQ.sync {
                res = self.workoutBuilder?.startDate
            }
            return res
        }
    }
    
    var splitTimes: [WorkoutSplit] {
        get {
            dispatchPrecondition(condition: .notOnQueue(syncQ))
            var res: [WorkoutSplit] = []
            syncQ.sync {
                res = splits
            }
            return res
        }
    }
    
    var isRunning: Bool {
        get {
            dispatchPrecondition(condition: .notOnQueue(syncQ))
            var res = false
            syncQ.sync {
                res = workoutBuilder != nil
            }
            return res
        }
    }
    
    /**
     * Create a new workout tracker.
     *
     * - Parameters:
     *   - activityType: The type of activity to be tracked by this object
     *   - splitDistance: When creating splits, what's the distance covered, in meters
     *   - locationManaged: A setup and authorized location management object
     */
    init(activityType: HKWorkoutActivityType,
         splitDistance: Double,
         locationManager: CLLocationManager,
         delegate: WorkoutTrackerDelegate
        ) {
        self.splitDistance = splitDistance
        self.activityType = activityType
        self.locationManager = locationManager
        self.delegate = delegate
    }
    
    /**
     * Start tracking a workout.
     *
     * - Parameters:
     *   - healthStore: The health store to which to store the workout.
     */
    func startWorkout(healthStore: HKHealthStore) throws {
        dispatchPrecondition(condition: .notOnQueue(syncQ))
        try syncQ.sync {
            
            if state != .Before {
                throw WorkoutTrackerError.WorkoutAlreadyStarted
            }
            
            assert(workoutBuilder == nil)
            assert(routeBuilder == nil)
            
            self.lastLocation = nil
            self.distance = 0.0
            self.splits.removeAll()
            
            locationManager.delegate = self
            
            let config = HKWorkoutConfiguration()
            config.activityType = activityType
            config.locationType = .outdoor
            
            let builder = HKWorkoutBuilder(healthStore: healthStore,
                                           configuration: config,
                                           device: nil)
            workoutBuilder = builder
            
            
            self.state = .WaitingForLocationStream
            self.delegateQ.async {
                self.delegate.stateUpdated(newState: .WaitingForLocationStream)
            }
            
            HKSeriesType.workoutRoute()
            self.routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
            
            self.locationManager.startUpdatingLocation()
        }
    }
    
    /**
     * Stops tracking a workout.
     *
     * - Parameters:
     *   - completion: A callback to indicate that the workout has completed, and optionally an error
     *                 if there was a problem stopping the workout. Regardless the workout is considered
     *                 stopped after this call.
     */
    func stopWorkout(completion: @escaping (Error?) -> Void) {
        dispatchPrecondition(condition: .notOnQueue(syncQ))
        syncQ.sync {
            locationManager.stopUpdatingLocation()
            
            guard let workoutBuilder = self.workoutBuilder else {
                DispatchQueue.global().async {
                    completion(WorkoutTrackerError.NoWorkoutStarted)
                }
                return
            }
            
            let endDate = Date()
            
            // Add one final split
            self.splits.append(WorkoutSplit(time: endDate, distance: distance))
            let s = self.splits
            self.delegateQ.async {
                self.delegate.splitsUpdated(latestSplits: s, finalUpdate: true)
            }
            
            let distanceQuantity = HKQuantity(unit: HKUnit.meter(), doubleValue: distance)
            let distanceSample = HKQuantitySample(type: activityType.DistanceType(),
                                                  quantity: distanceQuantity,
                                                  start: workoutBuilder.startDate!,
                                                  end: endDate)
            
            let peakSpeedQuantity = HKQuantity(unit: HKUnit.meter().unitDivided(by: HKUnit.second()), doubleValue: peakSpeed)
            
            let duration = endDate.timeIntervalSince(workoutBuilder.startDate!)
            let averageSpeed = distance / duration
            let averageSpeedQuantity = HKQuantity(unit: HKUnit.meter().unitDivided(by: HKUnit.second()), doubleValue: averageSpeed)

            
            workoutBuilder.addMetadata([HKMetadataKeyMaximumSpeed: peakSpeedQuantity, HKMetadataKeyAverageSpeed: averageSpeedQuantity], completion: { (success, error) in
         
                workoutBuilder.add([distanceSample]) { (success, error) in
                    if let err = error {
                        print("Failed to add sample: \(err)")
                    }
                    if !success {
                        print("adding sample wasn't a success")
                    }
                    
                    workoutBuilder.endCollection(withEnd: endDate, completion: { (success, error) in
                        dispatchPrecondition(condition: .notOnQueue(self.syncQ))
                        if error != nil {
                            self.syncQ.sync {
                                self.workoutBuilder = nil
                                self.routeBuilder = nil
                            }
                            completion(error)
                            return
                        }
                        if !success {
                            self.syncQ.sync {
                                self.workoutBuilder = nil
                                self.routeBuilder = nil
                            }
                            completion(WorkoutTrackerError.ErrorEndingCollection)
                            return
                        }
                 
                        workoutBuilder.finishWorkout(completion: { (workout, error) in
                            dispatchPrecondition(condition: .notOnQueue(self.syncQ))
                            if error != nil {
                                self.syncQ.sync {
                                    self.workoutBuilder = nil
                                    self.routeBuilder = nil
                                }
                                completion(error)
                                return
                            }
                            guard let finishedWorkout = workout else {
                                self.syncQ.sync {
                                    self.workoutBuilder = nil
                                    self.routeBuilder = nil
                                    
                                    self.state = .Stopped
                                    self.delegateQ.async {
                                        self.delegate.stateUpdated(newState: .Stopped)
                                    }
                                    
                                }
                                completion(WorkoutTrackerError.MissingWorkout)
                                return
                            }
                            
                            self.syncQ.sync {
                                self.workoutBuilder = nil
                                self.routeBuilder?.finishRoute(with: finishedWorkout, metadata: nil, completion: { (route, error) in
                                    dispatchPrecondition(condition: .notOnQueue(self.syncQ))
                                    self.syncQ.sync {
                                        self.routeBuilder = nil
                                    }
                                    completion(error)
                                })
                            }
                        })
                    })
                }
            })
        }
    }
}

extension WorkoutTracker: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        syncQ.sync {
            
            guard let builder = workoutBuilder else {
                return
            }
            
            var filteredLocations = locations
            
            if state == .WaitingForGPS || state == .WaitingForLocationStream {
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
                    
                    switch state {
                    case .WaitingForGPS, .WaitingForLocationStream:

                        print("speed: \(location.speed)")
                        
                        switch Int(location.horizontalAccuracy) {
                        case 0...10:
                            state = .Started
                            delegateQ.async {
                                self.delegate.stateUpdated(newState: .Started)
                            }
                            
                            let startDate = Date()
                            builder.beginCollection(withStart: startDate, completion: { (success, error) in
                                
                                dispatchPrecondition(condition: .notOnQueue(self.syncQ))
                                self.syncQ.sync {
                                    
                                    if error != nil {
                                        self.locationManager.stopUpdatingLocation()
                                        self.workoutBuilder = nil
                                        self.state = .Failed
                                        self.delegateQ.async {
                                            self.delegate.stateUpdated(newState: .Failed)
                                        }
                                        return
                                    }
                                    
                                    // we assume if there was no error everything is okay
                                    assert(success)
                                }
                            })
                            
                            self.splits.append(WorkoutSplit(time: startDate, distance: 0.0))
                            let s = self.splits
                            self.delegateQ.async {
                                self.delegate.splitsUpdated(latestSplits: s, finalUpdate: false)
                            }
                                                        
                            remaining.append(location)
                        default:
                            if state == .WaitingForLocationStream {
                                state = .WaitingForGPS
                                delegateQ.async {
                                    self.delegate.stateUpdated(newState: .WaitingForGPS)
                                }
                            }
                            break
                        }
                    default:
                        remaining.append(location)
                    }
                }
                filteredLocations = remaining
            }
            
            if state == .Started {
                guard let builder = routeBuilder else {
                    return
                }
                
                for location in filteredLocations {
                    print("speed: \(location.speed)")
                    if let last = lastLocation {
                        let newDistance = location.distance(from: last)
                        print("distance: \(newDistance)")
                        distance += newDistance
                        
                        if distance > (self.splitDistance * Double(self.splits.count)) {
                            self.splits.append(WorkoutSplit(time: Date(), distance: distance))
                            let s = self.splits
                            self.delegateQ.async {
                                self.delegate.splitsUpdated(latestSplits: s, finalUpdate: false)
                            }
                        }
                        
                        let currentDuration = location.timestamp.timeIntervalSince(last.timestamp)
                        let currentDistance = location.distance(from: last)
                        self.currentSpeed = currentDistance / currentDuration
                        if self.currentSpeed > self.peakSpeed {
                            self.peakSpeed = self.currentSpeed
                        }
                    }
                    lastLocation = location
                }
                
                builder.insertRouteData(locations) { (success, error) in
                    if let err = error {
                        print("Failed to insert data! \(err)")
                    } else if !success {
                        print("Failed to insert data")
                    }
                }
            }
        }
    }
    
}

extension WorkoutTracker {
    static func getDistanceUnitSetting() -> DistanceUnit {
        if let distanceUnits = UserDefaults.standard.string(forKey: "distance_units") {
            if let newUnits = DistanceUnit(rawValue: distanceUnits) {
                return newUnits
            }
        }
        return .Miles
    }
}
