//
//  ViewController.swift
//  BitFit
//x
//  Created by Michael Dales on 19/05/2019.
//  Copyright © 2019 Digital Flapjack Ltd. All rights reserved.
//

import UIKit
import HealthKit
import AVKit
import os.log

class RecordWorkoutViewController: UIViewController {

    @IBOutlet weak var toggleButton: UIButton!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var activityButton: UIButton!
    @IBOutlet weak var splitsTableView: UITableView!
    
    let synthesizer = AVSpeechSynthesizer()
    
    var updateTimer: Timer? = nil
    var workoutTracker: WorkoutTracker?
    
    var activityTypeIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        synthesizer.delegate = self
        
        activityTypeIndex = UserDefaults.standard.integer(forKey: "LastActivityIndex")
        
        let activityType = WorkoutTracker.supportedWorkouts[activityTypeIndex]
        activityButton.setImage(UIImage(named:activityType.String()), for: .normal)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.locationManager.requestAlwaysAuthorization()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        } catch {
            print("Failed to duck other sounds")
        }
    }
    
    @IBAction func changeActivity(_ sender: Any) {
        
        activityTypeIndex = (activityTypeIndex + 1) % WorkoutTracker.supportedWorkouts.count
        UserDefaults.standard.set(activityTypeIndex, forKey: "LastActivityIndex")
        
        let activityType = WorkoutTracker.supportedWorkouts[activityTypeIndex]
        activityButton.setImage(UIImage(named:activityType.String()), for: .normal)
    }
    
    @IBAction func toggleWorkout(_ sender: Any) {
        
        if workoutTracker == nil {
            let alert = UIAlertController(title: "Start workout",
                                          message: "Are you sure you wish to start a workout?",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                self.startWorkout()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            
        } else {
            let alert = UIAlertController(title: "Stop workout",
                                          message: "Are you sure you wish to stop the workout?",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                self.stopWorkout()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func startWorkout() {
        
        print("Starting workout")
        
        assert(workoutTracker == nil)
        assert(updateTimer == nil)
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        let activityType = WorkoutTracker.supportedWorkouts[activityTypeIndex]
        let splitDistance = WorkoutTracker.getDistanceUnitSetting() == .Miles ? 1609.34 : 1000.0
        let workout = WorkoutTracker(activityType: activityType,
                                     splitDistance: splitDistance,
                                     locationManager: appDelegate.locationManager)
        workoutTracker = workout
        
        do {
            try workout.startWorkout(healthStore: appDelegate.healthStore) { (error) in
                if let err = error {
                    print("Failed to start workout: \(err)")
                    return
                }
                
                DispatchQueue.main.async {
                    self.toggleButton.setTitle("Stop", for: .normal)
                    self.activityButton.isEnabled = false
                    
                    self.updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { _ in
                        
                        guard let workout = self.workoutTracker else {
                            return
                        }
                        
                        let now = Date()
                        
                        let miles = workout.estimatedDistance / splitDistance
                        let start = workout.startDate!
                        let duration = now.timeIntervalSince(start)
                        let minutes = Int(duration / 60.0)
                        let seconds = Int(duration) - (minutes * 60)
                        
                        DispatchQueue.main.async {
                            let distanceProse = String(format: "%.1f miles", miles)
                            let durationProse = String(format: "%d minutes and %d seconds", minutes, seconds)
                            
                            self.distanceLabel.text = distanceProse
                            self.durationLabel.text = durationProse
//
//                            if splitsUpdated {
//                                self.splitsTableView.reloadData()
//                                let part1 = AVSpeechUtterance(string: "\(distanceProse) \(durationProse)")
//                                self.synthesizer.speak(part1)
//                            }
                        }
                    })
                }
            }
        } catch {
            print("Failed to start workout: \(error)")
        }
    }
    
    func stopWorkout() {
        
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        
        print("Stopping workout")
        
        if let timer = updateTimer {
            timer.invalidate()
            updateTimer = nil
        }
        
        guard let workout = workoutTracker else {
            return
        }
        
        workout.stopWorkout { (error) in
            if let err = error {
                print("Error stopping workout: \(err)")
            }
            
//            let duration = endDate.timeIntervalSince(finishedWorkout.startDate)
//            let minutes = Int(duration / 60.0)
//            let seconds = Int(duration) - (minutes * 60)
//            var completionProse = "Workout completed. Time \(minutes) minutes and \(seconds) seconds. "
//
//            if let distanceQuantity = finishedWorkout.totalDistance {
//                let distance = distanceQuantity.doubleValue(for: .mile())
//                let distanceProse = String(format: " %.2f miles", distance)
//                completionProse += distanceProse
//            }
//
//            let completePhrase = AVSpeechUtterance(string: completionProse)
            
            DispatchQueue.main.async {
                self.workoutTracker = nil
                //self.synthesizer.speak(completePhrase)
                self.toggleButton.setTitle("Start", for: .normal)
                self.activityButton.isEnabled = true
            }
        }
    }
}

extension RecordWorkoutViewController: AVSpeechSynthesizerDelegate {

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard !synthesizer.isSpeaking else { return }

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false)
    }

}

extension RecordWorkoutViewController: UITableViewDelegate {
}

extension RecordWorkoutViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let workout = workoutTracker {
            return workout.splitTimes.count
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "splitsReuseIdentifier", for: indexPath)
        
        guard let workout = workoutTracker else {
            return cell
        }
        
        let splits = workout.splitTimes
        if indexPath.row >= splits.count {
            return cell
        }
        
        let split = splits[indexPath.row]
        var initialTime = workout.startDate!
        if indexPath.row > 0 {
            initialTime = splits[indexPath.row - 1]
        }
        let splitDuration = split.timeIntervalSince(initialTime)
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second, .nanosecond]
        formatter.unitsStyle = .abbreviated
        cell.textLabel?.text = formatter.string(from: splitDuration)
        
        return cell
    }
    
}
