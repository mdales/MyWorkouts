//
//  WorkoutDetailViewController.swift
//  BitFit
//
//  Created by Michael Dales on 29/05/2019.
//  Copyright © 2019 Digital Flapjack Ltd. All rights reserved.
//

import UIKit
import HealthKit

class WorkoutDetailViewController: UITableViewController {
    
    var workout: HKWorkout?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        tableView.reloadData()
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let workout = self.workout else {
            return 0
        }
        
        return workout.totalEnergyBurned != nil ? 4 : 3
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "detailReuseIdentifier", for: indexPath)
        
        guard let workout = self.workout else {
            cell.textLabel?.text = ""
            cell.detailTextLabel?.text = ""
            return cell
        }
        
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "Date"
            
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            cell.detailTextLabel?.text = formatter.string(from: workout.startDate)
            
        case 1:
            cell.textLabel?.text = "Duration"
            
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second, .nanosecond]
            formatter.unitsStyle = .abbreviated
            cell.detailTextLabel?.text = formatter.string(from: workout.duration)
            
        case 2:
            cell.textLabel?.text = "Distance"
            
            if let distanceQuantity = workout.totalDistance {                
                
                switch WorkoutTracker.getDistanceUnitSetting() {
                case .Kilometers:
                    let distance = distanceQuantity.doubleValue(for: .meter())
                    cell.detailTextLabel?.text = String(format: "%.2f km", distance / 1000.0)
                case .Miles:
                    let distance = distanceQuantity.doubleValue(for: .mile())
                    cell.detailTextLabel?.text = String(format: "%.2f miles", distance)
                }
            } else {
                cell.detailTextLabel?.text = "No distance recorded"
            }
        case 3:
            cell.textLabel?.text = "Energy burned"
            
            if let energyQuantity = workout.totalEnergyBurned {
                let energy = energyQuantity.doubleValue(for: .kilocalorie())
                cell.detailTextLabel?.text = String(format: "%.2f kcal", energy)
            } else {
                cell.detailTextLabel?.text = "No energy recorded"
            }
            
        default:
            cell.textLabel?.text = ""
            cell.detailTextLabel?.text = ""
        }
        
        
        return cell
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "General"
        default:
            return nil
        }
    }
}
