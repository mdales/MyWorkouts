//
//  InfoCell.swift
//  MyWorkouts
//
//  Created by Michael Dales on 24/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import SwiftUI

struct InfoCell: View {
    var title: String
    var value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
        }.padding()
    }
}

struct InfoCell_Previews: PreviewProvider {
    static var previews: some View {
        InfoCell(title: "Distance", value: "42 miles")
    }
}
