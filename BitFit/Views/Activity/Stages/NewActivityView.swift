//
//  NewActivityView.swift
//  MyWorkouts
//
//  Created by Michael Dales on 23/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import HealthKit
import SwiftUI

struct NewActivityView: View {
    @AppStorage("LastActivityIndex") private var selectedActivityInt: Int = Int(HKWorkoutActivityType.walking.rawValue)
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var locationManager: AnyLocationModel
    @EnvironmentObject var healthManager: AnyHealthModel

    let workoutStateMachine: WorkoutStateMachine

    let supportedWorkouts: [HKWorkoutActivityType] = [
        .walking,
        .wheelchairWalkPace,
        .running,
        .wheelchairRunPace,
        .cycling,
        .skatingSports
    ]

    var body: some View {
        VStack {
            Picker(selection: $selectedActivityInt, label: Text("Activity type")) {
                ForEach(supportedWorkouts, id: \.self) { item in
                    HStack {
                        Image(item.String())
                        Text(item.DisplayString())
                    }.tag(Int(item.rawValue))
                }
            }
            if let activity = HKWorkoutActivityType(rawValue: UInt(selectedActivityInt)) {
                Button {
                    workoutStateMachine.start(
                        activity: activity,
                        locationManager: locationManager,
                        healthManager: healthManager)
                } label: {
                    Text("Start")
                }.buttonStyle(ActionButtonStyle())
            } else {
                Text("Select activity")
            }
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Text("Cancel")
            }
        }
    }
}

struct NewActivityView_Previews: PreviewProvider {
    static var previews: some View {
        NewActivityView(workoutStateMachine: WorkoutStateMachine())
    }
}
