//
//  WorkoutHistoryViewController.swift
//  BitFit
//
//  Created by Michael Dales on 23/05/2019.
//  Copyright © 2019 Digital Flapjack Ltd. All rights reserved.
//

import UIKit
import HealthKit

class WorkoutHistoryViewController: UITableViewController {

    var runningWorkoutList = [HKSample]()
    var cyclingWorkoutList = [HKSample]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

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
                                    
                                    self.runningWorkoutList = samples
                                    
                                    DispatchQueue.main.async {                                        
                                        self.tableView.reloadData()
                                    }
        }
        
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.healthStore.execute(query)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        
        
        return runningWorkoutList.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)

        let workoutSample = runningWorkoutList[indexPath.row]
        guard let workout = workoutSample as? HKWorkout else {
            return cell
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .medium
        let formattedDate = formatter.string(from: workout.startDate)
        cell.detailTextLabel?.text = formattedDate
        
        let activityType = workout.workoutActivityType
        cell.imageView?.image = UIImage(named: activityType.String())
        
        var headline = ""
        
        if let distanceQuantity = workout.totalDistance {
            let distance = distanceQuantity.doubleValue(for: .mile())
            headline += String(format:"%.2f miles", distance)
        } else {
            headline += "No distance recorded"
        }
        
        if let energyQuantity = workout.totalEnergyBurned {
            let energy = energyQuantity.doubleValue(for: .kilocalorie())
            headline += String(format: ", \(energy) kcal")
        }
        
        cell.textLabel?.text = headline
        
        return cell
    }
    
//    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        let workoutSample = runningWorkoutList[indexPath.row]
//        guard let workout = workoutSample as? HKWorkout else {
//            return
//        }
//        
//        
//    }
//    

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let destination = segue.destination as? WorkoutDetailViewController else {
            return
        }
        guard let indexPath = tableView.indexPathForSelectedRow else {
            return
        }
        
        let workoutSample = runningWorkoutList[indexPath.row]
        guard let workout = workoutSample as? HKWorkout else {
            return
        }
        
        destination.workout = workout
        
    }
    

}
