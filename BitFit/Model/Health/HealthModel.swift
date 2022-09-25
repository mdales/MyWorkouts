//
//  HealthModel.swift
//  BitFit
//
//  Created by Michael Dales on 23/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import Foundation
import HealthKit
import Combine

protocol AbstractHealthModel {
    var workoutListPublisher: Published<[WorkoutInstance]>.Publisher { get }
    func reloadHistory()
    func requestPermission()
    func newHealthBuilderForConfig(config: HKWorkoutConfiguration) -> HKWorkoutBuilder
    func newRouteBuilder() -> HKWorkoutRouteBuilder
    func execute(_ query: HKQuery)
}

// This is a work around for two limitations in SwiftUI for UI test automation:
//   1: You can't use protocols for StateObjects or for @Published methods, so this
//      class is providing an abstraction layer for that.
//   2: You can't provide constructors to StateObjects, which is why you need to switch
//      between the mock and real objects here, rather than taking locationModel as a
//      parameter.
// It's all a bit icky, but so far I've not seen a better way to enable me to do UI
// testing when I have location dependancies for my data.
//let kUITestingFlag = "-isUItesting"

class AnyHealthModel: ObservableObject {
    @Published private(set) var workoutList: [WorkoutInstance] = []
    var workoutListPublished: Published<[WorkoutInstance]>.Publisher{
        return $workoutList
    }

    private let healthModel: AbstractHealthModel
    private var cancellables = Set<AnyCancellable>()

    init(mocked: Bool) {
        healthModel = mocked ? MockHealthModel() : HealthModel()
        healthModel.workoutListPublisher.sink(receiveValue: {self.workoutList = $0}).store(in: &cancellables)
    }

    func reloadHistory() {
        healthModel.reloadHistory()
    }

    func requestPermission() {
        healthModel.requestPermission()
    }

    func newHealthBuilderForConfig(config: HKWorkoutConfiguration) -> HKWorkoutBuilder {
        return healthModel.newHealthBuilderForConfig(config: config)
    }

    func newRouteBuilder() -> HKWorkoutRouteBuilder {
        return healthModel.newRouteBuilder()
    }

    func execute(_ query: HKQuery) {
        healthModel.execute(query)
    }
}


class MockHealthModel: ObservableObject, AbstractHealthModel {
    @Published private(set) var workoutList: [WorkoutInstance] = []
    var workoutListPublisher: Published<[WorkoutInstance]>.Publisher{
        return $workoutList
    }

    private let healthStore = HKHealthStore()
    
    init() {
        workoutList = [
            WorkoutInstance(workout: HKWorkout(activityType: .running, start: Date(), end: Date()), healthManager: self),
            WorkoutInstance(workout: HKWorkout(activityType: .cycling, start: Date(), end: Date()), healthManager: self),
            WorkoutInstance(workout: HKWorkout(activityType: .wheelchairWalkPace, start: Date(), end: Date()), healthManager: self),
            WorkoutInstance(workout: HKWorkout(activityType: .wheelchairRunPace, start: Date(), end: Date()), healthManager: self),
            WorkoutInstance(workout: HKWorkout(activityType: .walking, start: Date(), end: Date()), healthManager: self),
            WorkoutInstance(workout: HKWorkout(activityType: .skatingSports, start: Date(), end: Date()), healthManager: self),
        ]
    }

    func requestPermission() {
    }

    func reloadHistory() {
    }

    func newHealthBuilderForConfig(config: HKWorkoutConfiguration) -> HKWorkoutBuilder {
        return HKWorkoutBuilder(healthStore: healthStore,
                                configuration: config,
                                device: nil)
    }

    func newRouteBuilder() -> HKWorkoutRouteBuilder {
        return HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
    }

    func execute(_ query: HKQuery) {
        healthStore.execute(query)
    }
}

class HealthModel: ObservableObject, AbstractHealthModel {
    @Published private(set) var workoutList: [WorkoutInstance] = []
    var workoutListPublisher: Published<[WorkoutInstance]>.Publisher{
        return $workoutList
    }

    private let healthStore = HKHealthStore()

    init() {
    }

    func requestPermission() {
        var healthKitTypes: Set<HKSampleType> = [HKObjectType.workoutType(), HKSeriesType.workoutRoute()]
        for activityType in WorkoutTracker.supportedWorkouts {
            let distanceType = activityType.DistanceType()
            healthKitTypes.insert(distanceType)
        }
        healthStore.requestAuthorization(toShare: healthKitTypes, read: healthKitTypes) { (success, error) in
            if let err = error {
                print("Failed to auth health store: \(err)")
                return
            }

            if !success {
                print("health store auth wasn't a success")
                return
            }
            self.reloadHistory()
        }
    }

    func reloadHistory() {
        let sourcePredicate = HKQuery.predicateForObjects(from: HKSource.default())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: HKWorkoutType.workoutType(),
                                  predicate: sourcePredicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sort]) { (query, result, error) in

            if let err = error {
                print("Failed query: \(err)")
                return
            }

            guard let samples = result else {
                print("We got no samples!")
                return
            }

            // Published properties need to be updated on main thread
            DispatchQueue.main.async {
                self.workoutList = samples.compactMap {
                    if let workout =  $0 as? HKWorkout {
                        return WorkoutInstance(workout: workout, healthManager: self)
                    }
                    return nil
                }
            }
        }

        healthStore.execute(query)
    }

    func newHealthBuilderForConfig(config: HKWorkoutConfiguration) -> HKWorkoutBuilder {
        return HKWorkoutBuilder(healthStore: healthStore,
                                configuration: config,
                                device: nil)
    }

    func newRouteBuilder() -> HKWorkoutRouteBuilder {
        return HKWorkoutRouteBuilder(healthStore: healthStore, device: nil)
    }

    func execute(_ query: HKQuery) {
        healthStore.execute(query)
    }
}
