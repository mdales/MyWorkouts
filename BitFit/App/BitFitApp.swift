//
//  BitFitApp.swift
//  MyWorkouts
//
//  Created by Michael Dales on 23/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import SwiftUI

@main
struct BitFitApp: App {
    let locationModel: AnyLocationModel = AnyLocationModel()
    let healthModel: AnyHealthModel

    init() {
        healthModel = AnyHealthModel(mocked: ProcessInfo.processInfo.arguments.contains(kUITestingFlag))
    }


    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(locationModel)
                .environmentObject(healthModel)
        }
    }
}
