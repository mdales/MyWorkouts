//
//  RootView.swift
//  BitFit
//
//  Created by Michael Dales on 23/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import SwiftUI

struct RootView: View {
    @State private var recordActivity = false

    var body: some View {
        NavigationStack {
            VStack {
                WorkoutHistoryView()
                Button {
                    recordActivity = true
                } label:  {
                    Text("New workout")
                }
                .buttonStyle(ActionButtonStyle())
                .fullScreenCover(isPresented: $recordActivity) {
                    LocationRequiredWrapper()
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    SettingsPicker()
                }
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(AnyHealthModel(mocked: true))
    }
}
