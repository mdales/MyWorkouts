//
//  FailedActivityView.swift
//  MyWorkouts
//
//  Created by Michael Dales on 25/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import SwiftUI

struct FailedActivityView: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Text("Sorry, the workout failed.")
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Text("Dismiss")
            }
        }
    }
}

struct FailedActivityView_Previews: PreviewProvider {
    static var previews: some View {
        FailedActivityView()
    }
}
