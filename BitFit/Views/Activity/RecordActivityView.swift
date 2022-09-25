//
//  RecordActivityView.swift
//  MyWorkouts
//
//  Created by Michael Dales on 23/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import Combine
import SwiftUI

struct RecordActivityView: View {
    @AppStorage(SettingsNames.AnnounceDistance.rawValue) private var announceDistance: Bool = true
    @AppStorage(SettingsNames.AnnouncePace.rawValue) private var announcePace: Bool = true
    @AppStorage(SettingsNames.AnnounceTime.rawValue) private var announceTime: Bool = true

    @EnvironmentObject private var locationManager: AnyLocationModel

    @StateObject private var workoutStateMachine = WorkoutStateMachine()
    @StateObject private var speachManager = SpeachManager()

    @State private var cancellables: [AnyCancellable] = []

    var body: some View {
        VStack {
            switch workoutStateMachine.currentState {
            case .Before:
                NewActivityView()
                    .environmentObject(workoutStateMachine)
            case .WaitingForGPSAccuracy:
                WaitingForGPS()
                    .environmentObject(workoutStateMachine)
            case .WaitingForGPSToStart:
                WaitingForGPS()
                    .environmentObject(workoutStateMachine)
            case .Paused:
                Text("Paused") // TODO: currently unsupported
            case .Started:
                ActiveActivityView()
                    .environmentObject(workoutStateMachine)
            case .Failed:
                FailedActivityView() // TODO: one day .Failed will contain the error
            case .Stopped:
                PostActivityView()
                    .environmentObject(workoutStateMachine)
            }
        }
        .onAppear() {
            do {
                try speachManager.setup()
            } catch {
                print("Failed to setup speach: \(error)")
                return
            }

            workoutStateMachine.$currentState.sink { state in
                do {
                    switch state {
                    case .Started:
                        try speachManager.speak(text: "Go")
                    default:
                        break
                    }
                } catch {
                    print("Failed to speak: \(error)")
                }
            }.store(in: &cancellables)

        }
        .onDisappear() {
            for cancellable in cancellables {
                cancellable.cancel()
            }
            cancellables.removeAll()
        }
    }
}

struct RecordActivityView_Previews: PreviewProvider {
    static var previews: some View {
        RecordActivityView()
            .environmentObject(LocationModel())
    }
}
