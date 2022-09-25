//
//  WorkoutHistory.swift
//  MyWorkouts
//
//  Created by Michael Dales on 23/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import SwiftUI

struct WorkoutHistoryView: View {
    @EnvironmentObject var healthModel: AnyHealthModel

    var body: some View {
        VStack {
            List {
                ForEach(healthModel.workoutList, id: \.self) { item in
                    NavigationLink {
                        WorkoutDetailView(workout: item)
                    } label: {
                        WorkoutHistoryItem(workout: item)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("My Workouts")
        }
        .onAppear {
            healthModel.requestPermission()
        }
    }
}

struct WorkoutHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutHistoryView()
            .environmentObject(AnyHealthModel(mocked: true))
    }
}
