//
//  WorkoutDetailViewController.swift
//  BitFit
//
//  Created by Michael Dales on 29/05/2019.
//  Copyright © 2019 Digital Flapjack Ltd. All rights reserved.
//

import UIKit
import HealthKit

class WorkoutDetailViewController: UIViewController {

    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var energyLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
    var workout: HKWorkout?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        guard let workout = self.workout else {
            dateLabel.text = ""
            distanceLabel.text = ""
            energyLabel.text = ""
            return
        }
        
        let formater = DateFormatter()
        formater.dateStyle = .medium
        formater.timeStyle = .short
        dateLabel.text = formater.string(from: workout.startDate)
        
        let duration = workout.duration
        let minutes = Int(duration / 60.0)
        let seconds = Int(duration) - (minutes * 60)
        durationLabel.text = "\(minutes) minutes and \(seconds) seconds"
        
        if let distanceQuantity = workout.totalDistance {
            let distance = distanceQuantity.doubleValue(for: .mile())
            distanceLabel.text = String(format: "%.2f miles", distance)
        } else {
            distanceLabel.text = "No distance recorded"
        }
        
        if let energyQuantity = workout.totalEnergyBurned {
            let energy = energyQuantity.doubleValue(for: .kilocalorie())
            energyLabel.text = String(format: "%.2f kcal", energy)
        } else {
            energyLabel.text = "No energy recorded"
        }
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
