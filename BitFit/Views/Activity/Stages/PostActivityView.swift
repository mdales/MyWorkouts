//
//  PostActivityView.swift
//  MyWorkouts
//
//  Created by Michael Dales on 24/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import SwiftUI

struct PostActivityView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var healthManager: AnyHealthModel
    @EnvironmentObject var workoutStateMachine: WorkoutStateMachine

    var body: some View {
        VStack {
            Image(workoutStateMachine.activityType.String())
            Button {
                healthManager.reloadHistory()
                presentationMode.wrappedValue.dismiss()
            } label: {
                Text("Done")
            }
            .buttonStyle(ActionButtonStyle())
            if let firstSplit = workoutStateMachine.splits.first {
                ScrollView {
                    ForEach(workoutStateMachine.splits[1...].reversed(), id: \.self) { split in
                        SplitCellView(split: split, startTime: firstSplit.time)
                    }
                }
            }
        }
    }
}

struct PostActivityView_Previews: PreviewProvider {
    static var previews: some View {
        PostActivityView()
            .environmentObject(WorkoutStateMachine())
    }
}
