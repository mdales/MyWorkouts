//
//  ActiveActivityView.swift
//  MyWorkouts
//
//  Created by Michael Dales on 23/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import SwiftUI

struct ActiveActivityView: View {
    @EnvironmentObject var workoutStateMachine: WorkoutStateMachine

    var body: some View {
        VStack {
            Image(workoutStateMachine.activityType.String())
            Button {
                // TODO: are you sure?
                workoutStateMachine.stop()
            } label: {
                Text("Stop")
            }
            .buttonStyle(ActionButtonStyle())
            if let firstSplit = workoutStateMachine.splits.first {
//                ScrollView {
                    List {
                        SplitCellView(
                            split: WorkoutSplit(
                                time: Date(),
                                distance: workoutStateMachine.distance
                            ),
                            startTime: firstSplit.time
                        )
                        ForEach(workoutStateMachine.splits[1...].reversed(), id: \.self) { split in
                            SplitCellView(split: split, startTime: firstSplit.time)
                        }
                    }
//                }
            } else {
                Text("Missing first split!")
            }
            Spacer()
        }
    }
}

struct ActiveActivityView_Previews: PreviewProvider {
    static let wsm = WorkoutStateMachine()
    static var previews: some View {
        ActiveActivityView()
            .environmentObject(wsm)
    }
}
