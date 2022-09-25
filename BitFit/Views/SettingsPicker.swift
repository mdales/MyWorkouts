//
//  SettingsPicker.swift
//  MyWorkouts
//
//  Created by Michael Dales on 23/09/2022.
//  Copyright © 2022 Digital Flapjack Ltd. All rights reserved.
//

import SwiftUI

enum SettingsNames: String {
    case DistanceUnits
    case AnnounceDistance
    case AnnounceTime
    case AnnouncePace
}

struct SettingsPicker: View {
    @AppStorage(SettingsNames.DistanceUnits.rawValue) private var distanceUnits: String = DistanceUnit.Miles.rawValue
    @AppStorage(SettingsNames.AnnounceDistance.rawValue) private var distanceAnnouncement: Bool = true
    @AppStorage(SettingsNames.AnnounceTime.rawValue) private var AnnounceTime: Bool = true
    @AppStorage(SettingsNames.AnnouncePace.rawValue) private var AnnouncePace: Bool = true

    @Binding var showAboutSheet: Bool

    var body: some View {
        Menu {
            Picker(selection: $distanceUnits, label: Text("Distance units")) {
                ForEach(DistanceUnit.allCases, id: \.rawValue) { item in
                    Text(item.rawValue).tag(item.rawValue)
                }
            }

            Section {
                Toggle(isOn: $distanceAnnouncement) {
                    Text("Announce distance")
                }
                Toggle(isOn: $AnnounceTime) {
                    Text("Announce time")
                }
                Toggle(isOn: $AnnouncePace) {
                    Text("Announce pace")
                }
            }

            Section {
                Button {
                    showAboutSheet.toggle()
                } label: {
                    Text("About…")
                }
            }
        } label: {
            Image(systemName:  "ellipsis.circle")
                .accessibilityLabel(Text("Settings"))
        }
    }
}

struct SettingsPicker_Previews: PreviewProvider {
    @State static var showAboutSheet: Bool = false
    static var previews: some View {
        SettingsPicker(showAboutSheet: $showAboutSheet)
    }
}
