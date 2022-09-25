//
//  WorkoutInstance.swift
//  BitFit
//
//  Created by Michael Dales on 23/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import CoreLocation
import Foundation
import HealthKit
import MapKit


// This has to be a class for Map(...)
final class RouteAnnotation: Identifiable {

    enum Position {
        case start
        case end
        case waypoint(String)
        case point
    }

    let position: Position
    let coordinate: CLLocationCoordinate2D

    init(position: Position, coordinate: CLLocationCoordinate2D) {
        self.position = position
        self.coordinate = coordinate
    }
}

final class WorkoutInstance: ObservableObject {
    private let workout: HKWorkout

    @Published private(set) var routePoints: [RouteAnnotation] = []
    @Published private(set) var region = MKCoordinateRegion()

    init(workout: HKWorkout, healthManager: AbstractHealthModel) {
        self.workout = workout

        // the lookup of the route is async, so we should kick that off now
        let runningObjectQuery = HKQuery.predicateForObjects(from: workout)
        let routeQuery = HKAnchoredObjectQuery(
            type: HKSeriesType.workoutRoute(),
            predicate: runningObjectQuery,
            anchor: nil,
            limit: HKObjectQueryNoLimit)
        { (query, samples, deletedObjects, anchor, error) in
            if let err = error {
                print("Failed to load route data: \(err)")
                return
            }
            if let sampleList = samples {
                for sample in sampleList {
                    self.getRouteForSample(sample: sample, healthManager: healthManager)
                }
            }
        }
        routeQuery.updateHandler = { (query, samples, deleted, anchor, error) in
            guard error == nil else {
                // Handle any errors here.
                fatalError("The update failed.")
            }
            if let sampleList = samples {
                for sample in sampleList {
                    self.getRouteForSample(sample: sample, healthManager: healthManager)
                }
            }
        }
        healthManager.execute(routeQuery)
    }

    func getRouteForSample(sample: HKSample, healthManager: AbstractHealthModel) {
        guard let route = sample as? HKWorkoutRoute else {
            print("This wasn't a workout route")
            return
        }

        var distance = 0.0
        var last_loc: CLLocation? = nil

        let query = HKWorkoutRouteQuery(route: route) { (query, locations, done, error) in
            // This block may be called multiple times.
            if let error = error {
                print("Failed to get route data: \(error)")
                return
            }
            guard let locations = locations else {
                fatalError("*** Invalid State: This can only fail if there was an error. ***")
            }

            var newAnnotations: [RouteAnnotation] = []

            // is this the first batch, in which case add a start
            if self.routePoints.count == 0 {
                newAnnotations.append(RouteAnnotation(position: .start, coordinate: locations[0].coordinate))
            }

            let splitDistance = WorkoutStateMachine.getDistanceUnitSetting() == .Miles ? 1609.34 : 1000.0
            let units = WorkoutStateMachine.getDistanceUnitSetting() == .Miles ? "m" : "km"
            for loc in locations {
                if let last = last_loc {
                    let delta = loc.distance(from: last)
                    let last_disance = distance
                    distance += delta
                    if Int(distance / splitDistance) != Int(last_disance / splitDistance) {
                        newAnnotations.append(RouteAnnotation(
                            position: .waypoint("\(Int(distance/splitDistance)) \(units)"),
                            coordinate: loc.coordinate
                        ))
                    }
                }
                last_loc = loc
            }

            newAnnotations.append(contentsOf: locations.map { RouteAnnotation(position: .point, coordinate:  $0.coordinate) })

            if done {
                var finalLocation: CLLocationCoordinate2D? = locations.last?.coordinate
                if finalLocation == nil {
                    finalLocation = self.routePoints.last?.coordinate
                }
                if let finalLocation = finalLocation {
                    newAnnotations.append(RouteAnnotation(position: .end, coordinate: finalLocation))
                }
            }

            DispatchQueue.main.async {
                self.routePoints.append(contentsOf: newAnnotations)

                // TODO: do this better
                let polyline = MKPolyline(coordinates: self.routePoints.map { $0.coordinate}, count: self.routePoints.count)
                self.region = MKCoordinateRegion(polyline.boundingMapRect)
            }

        }
        healthManager.execute(query)
    }

    var title: String {
        workout.workoutActivityType.DisplayString()
    }

    var iconName: String {
        workout.workoutActivityType.String()
    }

    var date: Date {
        workout.startDate
    }

    var duration: TimeInterval {
        workout.duration
    }

    var distance: Double? {
        guard let distanceStatistic = workout.statistics(for: workout.workoutActivityType.DistanceType()) else {
            return nil
        }
        guard let distanceQuantity = distanceStatistic.sumQuantity() else {
            return nil
        }
        let units = WorkoutStateMachine.getDistanceUnitSetting()
        switch units {
        case .Miles:
            return distanceQuantity.doubleValue(for: .mile())
        case .Kilometers:
            return distanceQuantity.doubleValue(for: .meter()) / 1000.0
        }
    }
}

extension WorkoutInstance: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(workout.uuid)
    }

    static func == (lhs: WorkoutInstance, rhs: WorkoutInstance) -> Bool {
        lhs.workout.uuid == rhs.workout.uuid
    }
}
