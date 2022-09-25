//
//  WorkoutHistoryItem.swift
//  BitFit
//
//  Created by Michael Dales on 23/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import HealthKit
import SwiftUI

struct WorkoutHistoryItem: View {
    @AppStorage(SettingsNames.DistanceUnits.rawValue) private var distanceUnits: String = DistanceUnit.Miles.rawValue

    var workout: WorkoutInstance

    private let durationFormatter = DateComponentsFormatter()
    private let dateFormatter = DateFormatter()


    init(workout: WorkoutInstance) {
        self.workout = workout
        
        durationFormatter.allowedUnits = [.hour, .minute, .second, .nanosecond]
        durationFormatter.unitsStyle = .abbreviated
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .medium
    }

    var body: some View {
        HStack {
            Image(workout.iconName)
            VStack {
                HStack {
                    if let distance = workout.distance {
                        let distance_str = String(format: "%.2f ", distance)
                        Text("\(distance_str) \(distanceUnits)")
                    } else {
                        Text("No distance recorded")
                    }
                    Spacer()
                }
                HStack {
                    Text(durationFormatter.string(from: workout.duration) ?? "")
                    Spacer()
                }.padding(.vertical, 5)
                HStack {
                    Text(dateFormatter.string(from: workout.date))
                    Spacer()
                }
            }
        }
    }
}

struct WorkoutHistoryItem_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WorkoutHistoryItem(workout: WorkoutInstance(
                workout: HKWorkout(activityType: .running, start: Date(), end: Date()),
                healthManager: MockHealthModel()
            ))
            WorkoutHistoryItem(workout: WorkoutInstance(
                workout: HKWorkout(activityType: .wheelchairWalkPace, start: Date(), end: Date()),
                healthManager: MockHealthModel()
            )).preferredColorScheme(.dark)
        }
        .previewLayout(.fixed(width: 300, height: 70))
    }
}
