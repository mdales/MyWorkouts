//
//  RouteMap.swift
//  MyWorkouts
//
//  Created by Michael Dales on 26/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import HealthKit
import SwiftUI

import Map
import class MapKit.MKPolyline
import struct MapKit.MKCoordinateRegion
import class MapKit.MKPolylineRenderer
import class MapKit.MKOverlayRenderer

struct RouteMap: View {
    let workout: WorkoutInstance

    @State private var region = MKCoordinateRegion()
    @State private var userTrackingMode: MapUserTrackingMode  = .none

    var overlays: [MKPolyline] {
        return [workout.polyline]
    }

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
            },
            annotationContent: { (location: RouteAnnotation) in
                ViewMapAnnotation(coordinate: location.coordinate) {
                    ZStack {
                        Color("AccentColor")
                            .frame(width: 70, height: 24)
                            .cornerRadius(5)
                        switch location.position {
                        case .start:
                            Text("start")
                        case .end:
                            Text("end")
                        case .waypoint(let title):
                            Text(title)
                        default:
                            Text("")
                        }
                    }
                }
            },
            overlays: overlays,
            overlayContent: { overlay in
                RendererMapOverlay(overlay: overlay) { _, overlay in
                    if let polyline = overlay as? MKPolyline {
                        let renderer = MKPolylineRenderer(polyline: polyline)
                        renderer.lineWidth = 2
                        renderer.strokeColor = UIColor(named: "AccentColor")
                        return renderer
                    } else {
                        assertionFailure("Unknown overlay type found.")
                        return MKOverlayRenderer(overlay: overlay)
                    }
                }

            }
        )
        .onAppear {
            self.region = workout.region
        }
    }
}

struct RouteMap_Previews: PreviewProvider {
    static var previews: some View {
        RouteMap(workout: WorkoutInstance(
            workout: HKWorkout(activityType: .cycling, start: Date(), end: Date()),
            healthManager: MockHealthModel()
        ))
    }
}
