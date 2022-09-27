//
//  AboutView.swift
//  MyWorkouts
//
//  Created by Michael Dales on 25/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import SwiftUI

import Diligence

struct AboutView: View {
    var body: some View {
        NavigationView {
            Form {
                HeaderSection {
                    Icon("Icon")
                    ApplicationNameTitle()
                }
                Section {
                    Link("Digital Flapjack Ltd", url: URL(string: "https://digitalflapjack.com/")!)
                    Link("GitHub", url: URL(string: "https://github.com/mdales/myworkouts")!)
                }
                CreditSection("Developers", [
                    Credit("Michael Dales", url: URL(string: "https://mynameismwd.org/")),
                ])
                CreditSection("Thanks", [
                    "Laura James",
                    "Jason Morley",
                ])
                LicenseSection("Licenses", [
                    License(
                        name: "Diligence",
                        author: "InSeven Limited",
                        filename: "Diligence.txt"
                    ),
                    License(
                        name: "Map",
                        author: "Paul Kraft",
                        filename: "Map.txt"
                    ),
                    License(
                        name: "MyWorkouts",
                        author: "Digital Flapjack Ltd",
                        filename:  "LICENSE.txt"
                    )
                ])
            }
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
       AboutView()
    }
}
