//
//  EmbeddedMapView.swift
//  Trigtastic
//
//  Created by Michael Dales on 06/02/2022.
//

import HealthKit
import MapKit
import SwiftUI

struct EmbeddedMapView: View {
    let workout: WorkoutInstance

    @State private var userTrackingMode: MapUserTrackingMode = .none
    @State private var region = MKCoordinateRegion()

    var body: some View {
        Map(
            coordinateRegion: $region,
            userTrackingMode: $userTrackingMode,
            annotationItems: workout.routePoints.compactMap {
                switch $0.position {
                case .start, .end, .waypoint(_):
                    return $0
                default:
                    return nil
                }
            }
        ) { (routeAnnotation: RouteAnnotation) in
            MapMarker(coordinate: routeAnnotation.coordinate)
        }
            .onAppear {
                self.region = workout.region
            }
    }

    private func setRegion(_ coordinate: CLLocationCoordinate2D) {
        region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }
}

struct EmbeddedMapView_Previews: PreviewProvider {
    static var previews: some View {
        EmbeddedMapView(workout: WorkoutInstance(
            workout: HKWorkout(activityType: .running, start: Date(), end: Date()),
            healthManager: MockHealthModel()
        ))
    }
}
