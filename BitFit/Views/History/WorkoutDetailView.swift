//
//  WorkoutDetailView.swift
//  MyWorkouts
//
//  Created by Michael Dales on 23/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import HealthKit
import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject var healthManager: AnyHealthModel
    var workout: WorkoutInstance

    let dateFormatter = DateFormatter()
    let durationFormatter = DateComponentsFormatter()

    init(workout: WorkoutInstance) {
        self.workout = workout

        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        durationFormatter.allowedUnits = [.hour, .minute, .second, .nanosecond]
        durationFormatter.unitsStyle = .abbreviated
    }
    
    var body: some View {
        VStack  {
            InfoCell(
                title: "Date",
                value: dateFormatter.string(from: workout.date)
            )
            InfoCell(
                title: "Duration",
                value: durationFormatter.string(from: workout.duration) ?? ""
            )
            InfoCell(
                title: "Distance",
                value: ""
            )
            InfoCell(
                title: "Avg speed",
                value: ""
            )
            InfoCell(
                title: "Peak speed",
                value: ""
            )
            EmbeddedMapView(workout: workout)
        }.navigationTitle(workout.title)
    }
}

struct WorkoutDetailView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutDetailView(workout: WorkoutInstance(
            workout: HKWorkout(activityType: .running, start: Date(), end: Date()),
            healthManager: MockHealthModel()
        ))
    }
}

// date
// duration
// distance
// avg speed
// peak speed
// map
