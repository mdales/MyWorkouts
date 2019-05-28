//
//  ViewController.swift
//  BitFit
//x
//  Created by Michael Dales on 19/05/2019.
//  Copyright © 2019 Digital Flapjack Ltd. All rights reserved.
//

import UIKit
import HealthKit
import CoreLocation
import AVKit

extension HKWorkoutActivityType {
    func String() -> String {
        switch self {
        case .running:
            return "running"
        case .walking:
            return "walking"
        case .cycling:
            return "cycling"
        case .wheelchairRunPace:
            return "wheelchairRunPace"
        case .wheelchairWalkPace:
            return "wheelchairWalkPace"
        default:
            return "unknownWorkoutActivityType"
        }
    }
    
    func DistanceType() -> HKQuantityType {
        switch self {
        case .downhillSkiing:
            return HKObjectType.quantityType(forIdentifier: .distanceDownhillSnowSports)!
        case .cycling:
            return HKObjectType.quantityType(forIdentifier: .distanceCycling)!
        case .running, .walking, .crossCountrySkiing, .golf:
            return HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        case .wheelchairWalkPace, .wheelchairRunPace:
            return HKObjectType.quantityType(forIdentifier: .distanceWheelchair)!
        default:
            fatalError()
        }
    }
}

class RecordWorkoutViewController: UIViewController {

    @IBOutlet weak var toggleButton: UIButton!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var activityButton: UIButton!
    @IBOutlet weak var splitsTableView: UITableView!
    
    let supportedWorkouts: [HKWorkoutActivityType] = [.walking,
                                                      .running,
                                                      .cycling,
                                                      .wheelchairWalkPace,
                                                      .wheelchairRunPace]
    
    let splitDistance = 1609.34
    var splits = [Date]()
    
    let syncQ = DispatchQueue(label: "workout")
    
    let synthesizer = AVSpeechSynthesizer()
    
    var updateTimer: Timer? = nil
    
    let locationManager = CLLocationManager()
    var workoutBuilder: HKWorkoutBuilder?
    var routeBuilder: HKWorkoutRouteBuilder?
    
    var lastLocation: CLLocation?
    var distance: CLLocationDistance = 0.0
    
    var activityTypeIndex = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        synthesizer.delegate = self
        
        locationManager.delegate = self
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        activityTypeIndex = UserDefaults.standard.integer(forKey: "LastActivityIndex")
        
        let activityType = supportedWorkouts[activityTypeIndex]
        activityButton.setImage(UIImage(named:activityType.String()), for: .normal)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        locationManager.requestAlwaysAuthorization()
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            //                        try audioSession.setActive(true)
        } catch {
            print("Failed to duck other sounds")
        }

    }
    
    @IBAction func changeActivity(_ sender: Any) {
        
        activityTypeIndex = (activityTypeIndex + 1) % supportedWorkouts.count
        UserDefaults.standard.set(activityTypeIndex, forKey: "LastActivityIndex")
        
        let activityType = supportedWorkouts[activityTypeIndex]
        activityButton.setImage(UIImage(named:activityType.String()), for: .normal)
    }
    
    @IBAction func toggleWorkout(_ sender: Any) {
        
        if workoutBuilder == nil {
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
        
        assert(routeBuilder == nil)
        assert(updateTimer == nil)
        
        let config = HKWorkoutConfiguration()
        
        let activityType = supportedWorkouts[activityTypeIndex]
        config.activityType = activityType
        config.locationType = .outdoor
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        workoutBuilder = HKWorkoutBuilder(healthStore: appDelegate.healthStore,
                                          configuration: config,
                                          device: nil)
        
        workoutBuilder?.beginCollection(withStart: Date(), completion: { (success, error) in
            
            if let err = error {
                print("Failed to begin workout: \(err)")
                return
            }
            
            if !success {
                print("Beginning wasn't a success")
                return
            }
            
            HKSeriesType.workoutRoute()
            self.routeBuilder = HKWorkoutRouteBuilder(healthStore: appDelegate.healthStore, device: nil)
            
            self.lastLocation = nil
            self.distance = 0.0
            self.splits.removeAll()
            self.locationManager.startUpdatingLocation()
                                        
        })
        
        
        toggleButton.setTitle("Stop", for: .normal)
        activityButton.isEnabled = false
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { _ in
            
            let now = Date()
            
            let splitsUpdated = self.distance > (self.splitDistance * Double(self.splits.count + 1))
            if splitsUpdated {
                self.splits.append(now)
            }
            
            let miles = self.distance / self.splitDistance
            let start = self.workoutBuilder!.startDate!
            let duration = now.timeIntervalSince(start)
            let minutes = Int(duration / 60.0)
            let seconds = Int(duration) - (minutes * 60)
            
            DispatchQueue.main.async {
                self.distanceLabel.text = String(format: "%.1f miles", miles)
                self.durationLabel.text = String(format: "%d minutes and %d seconds", minutes, seconds)
                
                if splitsUpdated {
                    self.splitsTableView.reloadData()
                    
                    let part1 = AVSpeechUtterance(string: self.distanceLabel.text! + " " + self.durationLabel.text!)
                    self.synthesizer.speak(part1)
                }
            }
            
            
        })
    }
    
    func stopWorkout() {
        
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        
        print("Stopping workout")
        
        if let timer = updateTimer {
            timer.invalidate()
            updateTimer = nil
        }
        
        let completePhrase = AVSpeechUtterance(string: "Workout completed")
        synthesizer.speak(completePhrase)
        
        
        
        guard let workoutBuilder = self.workoutBuilder else {
            return
        }
        
        locationManager.stopUpdatingLocation()
        
        let endDate = Date()
        
        let distanceQuantity = HKQuantity(unit: HKUnit.meter(), doubleValue: distance)
        
        let activityType = supportedWorkouts[activityTypeIndex]
        let distanceSample = HKQuantitySample(type: activityType.DistanceType(), quantity: distanceQuantity,
                                              start: workoutBuilder.startDate!, end: endDate)
        
        workoutBuilder.add([distanceSample]) { (success, error) in
            
            if let err = error {
                print("Failed to add sample: \(err)")
                return
            }
            
            if !success {
                print("adding sample wasn't a success")
                return
            }
        }
        
        workoutBuilder.endCollection(withEnd: endDate) { (success, error) in
            
            if let err = error {
                print("Failed to end workout: \(err)")
                return
            }
            
            if !success {
                print("Ending wasn't a success")
                return
            }
            
            workoutBuilder.finishWorkout { (workout, error) in
                
                if let err = error {
                    print("Failed to finish workout: \(err)")
                    return
                }
                
                guard let finishedWorkout = workout else {
                    print("Failde to get workout")
                    return
                }
                
                guard let routeBuilder = self.routeBuilder else {
                    print("Failed to get route builder")
                    return
                }
                
                routeBuilder.finishRoute(with: finishedWorkout, metadata: nil, completion: { (route, error) in
                    if let err = error {
                        print("Failed to finish route: \(err)")
                    }
                })
                
                self.workoutBuilder = nil
                self.routeBuilder = nil
            }
        }
        toggleButton.setTitle("Start", for: .normal)
        activityButton.isEnabled = true
    }
}


extension RecordWorkoutViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        guard let builder = routeBuilder else {
            return
        }
        
        print("Inserting location data")
        
        for location in locations {
            if let last = lastLocation {
                distance += location.distance(from: last)
            }
            lastLocation = location
        }
        
        builder.insertRouteData(locations) { (success, error) in
            if let err = error {
                print("Failed to insert data! \(err)")
            } else if !success {
                print("Failed to insert data")
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
        return splits.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "splitsReuseIdentifier", for: indexPath)
        
        let split = splits[indexPath.row]
        
        cell.textLabel?.text = "\(split)"
        
        return cell
    }
    
}
