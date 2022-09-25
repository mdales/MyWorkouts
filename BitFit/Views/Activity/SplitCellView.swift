//
//  SplitCellView.swift
//  MyWorkouts
//
//  Created by Michael Dales on 23/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import SwiftUI

struct SplitCellView: View {
    @AppStorage(SettingsNames.DistanceUnits.rawValue) private var rawDistanceUnits: String = DistanceUnit.Miles.rawValue
    var distanceUnits: DistanceUnit {
        DistanceUnit(rawValue: rawDistanceUnits) ?? .Miles
    }
    var distanceProse: String {
        switch distanceUnits {
        case .Miles:
            let distance = split.distance / 1609.34
            var unit = "s"
            if Int(distance * 100) == 100 {
                unit = ""
            }
            return String(format: "%.2f mile%@", distance, unit)
        case .Kilometers:
            return String(format: "%.2f km", split.distance / 1000.0)
        }
    }


    let split: WorkoutSplit
    let splitDuration : TimeInterval

    let dateFormatter = DateComponentsFormatter()

    init(split: WorkoutSplit, startTime: Date) {
        self.split = split
        self.splitDuration = split.time.timeIntervalSince(startTime)

        dateFormatter.allowedUnits = [.hour, .minute, .second, .nanosecond]
        dateFormatter.unitsStyle = .abbreviated
    }

    var body: some View {
        HStack {
            Text(distanceProse)
            Spacer()
            Text(dateFormatter.string(from: splitDuration) ?? "Unknown")
        }.padding()
    }
}

struct SplitCellView_Previews: PreviewProvider {
    static var previews: some View {
        SplitCellView(split: WorkoutSplit(time: Date(), distance: 42.0), startTime: Date())
    }
}
