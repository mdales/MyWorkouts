//
//  LocationRequiredWrapper.swift
//  Trigpoints
//
//  Created by Michael Dales on 26/02/2022.
//

import SwiftUI

struct LocationRequiredWrapper: View {
    @EnvironmentObject private var locationModel: AnyLocationModel

    var body: some View {
        switch locationModel.authorizationStatus {
        case .notDetermined:
            Spacer()
            AnyView(RequestLocationView())
            Spacer()
        case .restricted:
            RequestLocationErrorView(errorText: "Location use is restricted.")
        case .denied:
            RequestLocationErrorView(errorText: "The app does not have location permissions, so can't show nearby trig points. Please enable them in settings.")
        case .authorizedAlways, .authorizedWhenInUse:
            RecordActivityView()
        default:
            Text("Unexpected status")
        }
    }
}

struct LocationRequiredWrapper_Previews: PreviewProvider {
    static var previews: some View {
        LocationRequiredWrapper()
            .environmentObject(LocationModel())
    }
}
