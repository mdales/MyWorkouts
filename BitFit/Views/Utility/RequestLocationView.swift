//
//  RequestLocationView.swift
//  Trigtastic
//
//  Created by Michael Dales on 06/02/2022.
//

import SwiftUI

struct RequestLocationView: View {
    @EnvironmentObject var locationModel: AnyLocationModel

    var body: some View {
        VStack {
            Image(systemName: "location.circle")
                .resizable()
                .frame(width: 100, height: 100, alignment: .center)

            Text("We need your permission to see where you are in order to find nearby trig points.")
                .foregroundColor(.gray)
                .font(.caption)
                .padding()
                .frame(alignment: .leading)

            Button(action: {
                locationModel.requestPermission()
            }, label: {
                Text("Allow location access")
            })
            .padding(10)
            .foregroundColor(.white)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct RequestLocationView_Previews: PreviewProvider {
    static var previews: some View {
        RequestLocationView()
            .environmentObject(AnyLocationModel())
    }
}
