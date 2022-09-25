//
//  RequestErrorView.swift
//  Trigtastic
//
//  Created by Michael Dales on 06/02/2022.
//

import SwiftUI

struct RequestLocationErrorView: View {
    var errorText: String

    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "xmark.octagon")
                .resizable()
                .frame(width: 100, height: 100, alignment: .center)
                .padding()
                .foregroundColor(.red)
            Text(errorText)
                .font(.caption)
                .padding()
                .frame(alignment: .leading)
            Spacer()
        }
    }
}

struct RequestLocationErrorView_Previews: PreviewProvider {
    static var previews: some View {
        RequestLocationErrorView(errorText: "Oh no")
    }
}
