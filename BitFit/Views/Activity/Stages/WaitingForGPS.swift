//
//  WaitingForGPSAccuracy.swift
//  MyWorkouts
//
//  Created by Michael Dales on 23/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import SwiftUI

struct WaitingForGPS: View {
    @EnvironmentObject var workoutStateMachine: WorkoutStateMachine

    var body: some View {
        VStack {
            Image("noGPS")
            Text("Waiting for GPS")
            Button {
                workoutStateMachine.stop()
            } label: {
                Text("Cancel")
            }
        }
    }
}

struct WaitingForGPS_Previews: PreviewProvider {
    static var previews: some View {
        WaitingForGPS()
            .environmentObject(WorkoutStateMachine())
    }
}
