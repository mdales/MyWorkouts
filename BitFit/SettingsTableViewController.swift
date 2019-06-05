//
//  SettingsTableViewController.swift
//  BitFit
//
//  Created by Michael Dales on 04/06/2019.
//  Copyright © 2019 Digital Flapjack Ltd. All rights reserved.
//

import UIKit

enum SettingsNames: String {
    case DistanceUnits
    case DistanceAnnoucement
    case TimeAnnouncement
    case PaceAnnouncement
}

func DefaultSettings() -> [String:Any] {
    return [
        SettingsNames.DistanceUnits.rawValue: DistanceUnit.Miles.rawValue,
        SettingsNames.DistanceAnnoucement.rawValue: true,
        SettingsNames.TimeAnnouncement.rawValue: true,
        SettingsNames.PaceAnnouncement.rawValue: true
    ]
}

class SettingsTableViewController: UITableViewController {
    
    @IBOutlet weak var distanceUnitsLabel: UILabel!
    @IBOutlet weak var distanceAnnouncementsSwitch: UISwitch!
    @IBOutlet weak var timeAnnouncementsSwitch: UISwitch!
    @IBOutlet weak var paceAnnouncementsSwitch: UISwitch!
    @IBOutlet weak var versionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let pink = UIColor(red: 255.0/255.0,
                           green: 45.0/255.0,
                           blue: 85.0/255.0,
                           alpha: 1.0)
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: pink]
        self.navigationController?.navigationBar.tintColor = pink
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        let defaults = UserDefaults.standard
        
        var distanceUnits = DistanceUnit.Miles
        if let distanceUnitsStr = defaults.string(forKey: SettingsNames.DistanceUnits.rawValue) {
            if let newUnits = DistanceUnit(rawValue: distanceUnitsStr) {
                distanceUnits = newUnits
            }
        }
        distanceUnitsLabel.text = distanceUnits.rawValue
        
        let distAnnounce = defaults.bool(forKey: SettingsNames.DistanceAnnoucement.rawValue)
        distanceAnnouncementsSwitch.isOn = distAnnounce
        
        let timeAnnounce =  defaults.bool(forKey: SettingsNames.DistanceAnnoucement.rawValue)
        timeAnnouncementsSwitch.isOn = timeAnnounce
        
        let paceAnnounce = defaults.bool(forKey: SettingsNames.DistanceAnnoucement.rawValue)
        paceAnnouncementsSwitch.isOn = paceAnnounce
    }

    @IBAction func distanceAnnouncementToggled(_ sender: Any) {
        let newVal = distanceAnnouncementsSwitch.isOn
        UserDefaults.standard.set(newVal, forKey: SettingsNames.DistanceAnnoucement.rawValue)
    }
    
    @IBAction func timeAnnouncementToggled(_ sender: Any) {
        let newVal = timeAnnouncementsSwitch.isOn
        UserDefaults.standard.set(newVal, forKey: SettingsNames.TimeAnnouncement.rawValue)
    }
    
    @IBAction func paceAnnouncementToggled(_ sender: Any) {
        let newVal = paceAnnouncementsSwitch.isOn
        UserDefaults.standard.set(newVal, forKey: SettingsNames.PaceAnnouncement.rawValue)
    }
    
    
    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label = UILabel()
        label.textAlignment = .center
        label.text = self.tableView(tableView, titleForHeaderInSection: section)
        label.textColor = UIColor(red: 255.0/255.0,
                                  green: 45.0/255.0,
                                  blue: 85.0/255.0,
                                  alpha: 1.0)
        return label
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 32.0
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 16.0
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
