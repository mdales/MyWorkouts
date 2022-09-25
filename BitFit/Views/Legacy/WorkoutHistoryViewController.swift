//
//  WorkoutHistoryViewController.swift
//  BitFit
//
//  Created by Michael Dales on 23/05/2019.
//  Copyright © 2019 Digital Flapjack Ltd. All rights reserved.
//

import UIKit
import HealthKit


class WorkoutHistoryCell: UITableViewCell {
    
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    func setWorkout(_ workout: HKWorkout) {
        
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .medium
        let formattedDate = formatter.string(from: workout.startDate)
        dateLabel.text = formattedDate
        
        let activityType = workout.workoutActivityType
        iconView.image = UIImage(named: activityType.String())
        
        if let distanceQuantity = workout.totalDistance {
            let units = WorkoutTracker.getDistanceUnitSetting()
            switch units {
            case .Miles:
                let distance = distanceQuantity.doubleValue(for: .mile())
                distanceLabel.text = String(format:"%.2f miles", distance)
            case .Kilometers:
                let distance = distanceQuantity.doubleValue(for: .meter())
                distanceLabel.text = String(format:"%.2f km", distance / 1000.0)
            }
        } else {
            distanceLabel.text = "No distance recorded"
        }
        
        let durationFormatter = DateComponentsFormatter()
        durationFormatter.allowedUnits = [.hour, .minute, .second, .nanosecond]
        durationFormatter.unitsStyle = .abbreviated
        durationLabel.text = durationFormatter.string(from: workout.duration)
    }
}

class WorkoutHistoryViewController: UITableViewController {

    var workoutList = [HKSample]()
    
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
        super.viewWillAppear(animated)
        loadWorkoutHistory()
    }
    
    func loadWorkoutHistory() {
        let sourcePredicate = HKQuery.predicateForObjects(from: HKSource.default())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: HKWorkoutType.workoutType(),
                                  predicate: sourcePredicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sort]) { (query, result, error) in
                                    
                                    if let err = error {
                                        print("Failed query: \(err)")
                                        return
                                    }
                                    
                                    guard let samples = result else {
                                        print("We got no samples!")
                                        return
                                    }
                                    
                                    self.workoutList = samples
                                    
                                    DispatchQueue.main.async {
                                        self.tableView.reloadData()
                                    }
        }
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.healthStore.execute(query)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return workoutList.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath) as! WorkoutHistoryCell

        let workoutSample = workoutList[indexPath.row]
        if let workout = workoutSample as? HKWorkout  {
            cell.setWorkout(workout)
        }
        
        return cell
    }
    
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            
            let workout = workoutList[indexPath.row]
            
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            let healthStore = appDelegate.healthStore
           
            healthStore.delete(workout) { (success, error) in
                if let err = error {
                    print("Failed to delete things: \(err)")
                    self.loadWorkoutHistory()
                    return
                }
                
                if !success {
                    print("Failed to delete things but no error")
                    self.loadWorkoutHistory()
                    return
                }
            }
            
            // deleting is async, but the UI needs to do something now, so we remove the data from
            // our model for now, and we'll fix consistency later
            workoutList.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 114.0
    }

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let destination = segue.destination as? WorkoutDetailViewController else {
            return
        }
        guard let indexPath = tableView.indexPathForSelectedRow else {
            return
        }
        
        let workoutSample = workoutList[indexPath.row]
        guard let workout = workoutSample as? HKWorkout else {
            return
        }
        
        destination.workout = workout
        
    }
    

}
