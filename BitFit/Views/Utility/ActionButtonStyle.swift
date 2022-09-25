//
//  ActionButtonStyle.swift
//  MyWorkouts
//
//  Created by Michael Dales on 25/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import SwiftUI

struct ActionButtonStyle: ButtonStyle {
    let bgColor: Color = Color(red: 1.0, green: 45.0/255.0, blue: 85.0/255.0)

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding(20)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .shadow(color: .white, radius: configuration.isPressed ? 7: 10, x: configuration.isPressed ? -5: -15, y: configuration.isPressed ? -5: -15)
                        .shadow(color: .black, radius: configuration.isPressed ? 7: 10, x: configuration.isPressed ? 5: 15, y: configuration.isPressed ? 5: 15)
                        .blendMode(.overlay)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(bgColor)
                }
            )
            .scaleEffect(configuration.isPressed ? 0.95: 1)
            .foregroundColor(Color(UIColor.systemBackground))
    }

}

struct ActionButtonStyle_Previews: PreviewProvider {
    static var previews: some View {
        Button {

        } label: {
            Text("Hello")
        }.buttonStyle(ActionButtonStyle())
    }
}
