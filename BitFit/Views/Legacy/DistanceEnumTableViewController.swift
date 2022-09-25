//
//  DistanceEnumTableViewController.swift
//  BitFit
//
//  Created by Michael Dales on 04/06/2019.
//  Copyright © 2019 Digital Flapjack Ltd. All rights reserved.
//

import UIKit

class DistanceEnumTableViewController: UITableViewController {

    var selectedRow = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return DistanceUnit.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "distanceUnitReuseIdentifier", for: indexPath)
        
        let unit = DistanceUnit.allCases[indexPath.row]
        cell.textLabel?.text = unit.rawValue
        
        var distanceUnits = DistanceUnit.Miles // default is miles
        if let distanceUnitsStr = UserDefaults.standard.string(forKey: SettingsNames.DistanceUnits.rawValue) {
            if let newUnits = DistanceUnit(rawValue: distanceUnitsStr) {
                distanceUnits = newUnits
            }
        }
        
        if unit == distanceUnits {
            cell.accessoryType = .checkmark
            selectedRow = indexPath.row
        } else {
            cell.accessoryType = .none
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedUnit = DistanceUnit.allCases[indexPath.row]
        
        var distanceUnits = DistanceUnit.Miles // default is miles
        if let distanceUnitsStr = UserDefaults.standard.string(forKey: SettingsNames.DistanceUnits.rawValue) {
            if let newUnits = DistanceUnit(rawValue: distanceUnitsStr) {
                distanceUnits = newUnits
            }
        }
        
        if selectedUnit != distanceUnits {            
            UserDefaults.standard.set(selectedUnit.rawValue, forKey: SettingsNames.DistanceUnits.rawValue)
        }
        
        if let cell = tableView.cellForRow(at: IndexPath(row: selectedRow, section: 0)) {
            cell.accessoryType = .none
        }
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.accessoryType = .checkmark
            selectedRow = indexPath.row
        }
    }
}
