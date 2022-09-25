//
//  ViewController.swift
//  BitFit
//
//  Created by Michael Dales on 19/05/2019.
//  Copyright © 2019 Digital Flapjack Ltd. All rights reserved.
//

import UIKit
import HealthKit
import CoreLocation
import AVKit
import os.log
import UPCarouselFlowLayout

class RecordWorkoutViewController: UIViewController {

    @IBOutlet weak var activityCollectionView: UICollectionView!
    @IBOutlet weak var lockedActivityImageView: UIImageView!
    @IBOutlet weak var activityLabel: UILabel!
    @IBOutlet weak var toggleButton: UIButton!
    @IBOutlet weak var splitsTableView: UITableView!
    
    let synthesizer = AVSpeechSynthesizer()
    
    var updateTimer: Timer? = nil
    var workoutTracker: WorkoutTracker?
    
    var activityTypeIndex = 0 {
        didSet {
             UserDefaults.standard.set(activityTypeIndex, forKey: "LastActivityIndex")
        }
    }
    
    var latestSplits = [WorkoutSplit]()
    
    
    fileprivate var pageSize: CGSize {
        let layout = self.activityCollectionView.collectionViewLayout as! UPCarouselFlowLayout
        var pageSize = layout.itemSize
        if layout.scrollDirection == .horizontal {
            pageSize.width += layout.minimumLineSpacing
        } else {
            pageSize.height += layout.minimumLineSpacing
        }
        return pageSize
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        synthesizer.delegate = self
        
        splitsTableView.separatorStyle = .none
        
        let layout = self.activityCollectionView.collectionViewLayout as! UPCarouselFlowLayout
        layout.spacingMode = .fixed(spacing: 10.0)
        
        activityTypeIndex = UserDefaults.standard.integer(forKey: "LastActivityIndex")
        
        let indexPath = IndexPath(item: activityTypeIndex, section: 0)
        let scrollPosition: UICollectionView.ScrollPosition = .centeredHorizontally
        self.activityCollectionView.scrollToItem(at: indexPath, at: scrollPosition, animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
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
        
        // warm up the GPS here
        if workoutTracker == nil {
            appDelegate.locationManager.delegate = self
            appDelegate.locationManager.startUpdatingLocation()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if workoutTracker == nil {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.locationManager.stopUpdatingLocation()
        }
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
        
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        
        print("Starting workout")
        
        assert(workoutTracker == nil)
        assert(updateTimer == nil)
        
        latestSplits = [WorkoutSplit]()
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        let activityType = WorkoutTracker.supportedWorkouts[activityTypeIndex]
        let splitDistance = WorkoutTracker.getDistanceUnitSetting() == .Miles ? 1609.34 : 1000.0
        let workout = WorkoutTracker(activityType: activityType,
                                     splitDistance: splitDistance,
                                     locationManager: appDelegate.locationManager,
                                     delegate: self)
        workoutTracker = workout
        
        do {
            try workout.startWorkout(healthStore: appDelegate.healthStore)
            
            self.updateUI()
            self.splitsTableView.reloadData()
            
            self.updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { _ in
                
                DispatchQueue.main.async {
                    let set = IndexSet([0])
                    self.splitsTableView.reloadSections(set, with: .none)
                }
                
            })
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
            
            DispatchQueue.main.async {
                self.workoutTracker = nil
                self.splitsTableView.reloadData()
                self.updateUI()
            }
        }
    }
    
    func animateGPS() {
        
        var workoutState = WorkoutState.Before
        if let workoutTracker = self.workoutTracker {
            workoutState = workoutTracker.state
        }
        if ![WorkoutState.WaitingForGPSAccuracy, WorkoutState.WaitingForGPSToStart].contains(workoutState) {
            return
        }
        
        let starting = lockedActivityImageView.alpha == 1.0
        
        UIView.animate(withDuration: 1.5, delay: 0.0, options: UIView.AnimationOptions.curveEaseInOut, animations: {
            self.lockedActivityImageView.alpha = starting ? 0.5 : 1.0
        }, completion: { (finished: Bool) in
            if finished {
                self.animateGPS()
            }
        });
    }
    
    func updateUI() {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        
        // Get all the info we need
        let activityType = WorkoutTracker.supportedWorkouts[self.activityTypeIndex]
        var workoutState = WorkoutState.Before
        if let workoutTracker = self.workoutTracker {
            workoutState = workoutTracker.state
        }
        
        // set the active activity image
        switch workoutState {
        case .WaitingForGPSToStart, .WaitingForGPSAccuracy:
            lockedActivityImageView.image = UIImage(named: "noGPS")
            animateGPS()
        default:
            lockedActivityImageView.image = UIImage(named: activityType.String())
            lockedActivityImageView.layer.removeAllAnimations()
            lockedActivityImageView.alpha = 1.0
        }
        
        // Set button title
        switch workoutState {
        case .Before, .Stopped, .Failed:
            self.toggleButton.setTitle("Start", for: .normal)
        case .WaitingForGPSAccuracy, .WaitingForGPSToStart:
            self.toggleButton.setTitle("Cancel", for: .normal)
        default:
            self.toggleButton.setTitle("Stop", for: .normal)
        }
        
        // set activity view
        switch workoutState {
        case .Before, .Stopped, .Failed:
            self.activityCollectionView.isHidden = false
            self.lockedActivityImageView.isHidden = true
        default:
            self.activityCollectionView.isHidden = true
            self.lockedActivityImageView.isHidden = false
        }
        
        // set activity text
        switch workoutState {
        case .WaitingForGPSAccuracy, .WaitingForGPSToStart:
            self.activityLabel.text = "Waiting for GPS..."
        default:
            self.activityLabel.text = "Activity: \(activityType.DisplayString())"
        }
    }
}

extension RecordWorkoutViewController: WorkoutTrackerDelegate {
    
    func stateUpdated(newState: WorkoutState) {
        DispatchQueue.main.async {
            self.updateUI()
            self.splitsTableView.reloadData()
            
            // Do any announcements
            switch newState {
            case .Started:
                let spokenPhrase = AVSpeechUtterance(string: "Go!")
                let audioSession = AVAudioSession.sharedInstance()
                try? audioSession.setActive(true)
                self.synthesizer.speak(spokenPhrase)
                
            case .Failed:
                let spokenPhrase = AVSpeechUtterance(string: "Workout failed.")
                let audioSession = AVAudioSession.sharedInstance()
                try? audioSession.setActive(true)
                self.synthesizer.speak(spokenPhrase)
                
            default:
                break
            }
        }
    }
    
    func splitsUpdated(latestSplits: [WorkoutSplit], finalUpdate: Bool) {
        DispatchQueue.main.async {
            self.latestSplits = latestSplits
            if self.latestSplits.count > 1 {
                self.splitsTableView.insertRows(at: [IndexPath(row: 0, section: 1)], with: .top)
            } else {
                self.splitsTableView.reloadData()
            }
            
            if latestSplits.count < 2 {
                return
            }
            
            var phrase = ""
            let announceDistance = UserDefaults.standard.bool(forKey: SettingsNames.AnnounceDistance.rawValue)
            let announceTime = UserDefaults.standard.bool(forKey: SettingsNames.AnnounceTime.rawValue)
            let announcePace = UserDefaults.standard.bool(forKey: SettingsNames.AnnouncePace.rawValue)
            
            let latestSplit = latestSplits[latestSplits.count - 1]
            let priorSplit = latestSplits[finalUpdate ? 0 : latestSplits.count - 2]
            let firstSplit = latestSplits[0]
            
            let splitDuration = latestSplit.time.timeIntervalSince(priorSplit.time)
            let splitDistance = latestSplit.distance - firstSplit.distance

            let pace = (latestSplit.distance - priorSplit.distance) / splitDuration
            
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .full
            let durationPhrase = formatter.string(from: splitDuration)!
            
            let numFormatter = NumberFormatter()
            numFormatter.minimumFractionDigits = 0
            numFormatter.maximumFractionDigits = 2
            
            let units = WorkoutTracker.getDistanceUnitSetting()
            switch units {
            case .Miles:
                let distance = splitDistance / 1609.34
                
                if announceDistance {
                    var unit = "s"
                    if Int(distance * 100) == 100 {
                        unit = ""
                    }
                    
                    phrase = String(format: "%@ Distance %@ mile%@. --", phrase, numFormatter.string(from: NSNumber(floatLiteral: distance))!, unit)
                }
                if announceTime {
                    phrase = String(format: "%@ %@ time %@. --", phrase, finalUpdate ? "Total" : "", durationPhrase)
                }
                if announcePace {
                    phrase = String(format: "%@ Pace %@ miles per hour. ", phrase, numFormatter.string(from: NSNumber(floatLiteral: pace * 2.236936))!)
                }
                
            case .Kilometers:
                let distance = splitDistance / 1000.0
                
                if announceDistance {
                    var unit = "s"
                    if Int(distance * 100) == 100 {
                        unit = ""
                    }
                    
                    phrase = String(format: "%@ Distance %@ kilometer%@. --", phrase, numFormatter.string(from: NSNumber(floatLiteral: distance))!, unit)
                }
                if announceTime {
                    phrase = String(format: "%@ %@ time %@. --", phrase, finalUpdate ? "Total" : "", durationPhrase)
                }
                if announcePace {
                    phrase = String(format: "%@ Pace %@ kilometers per hour. ", phrase, numFormatter.string(from: NSNumber(floatLiteral: pace * 3.6))!)
                }
            }
            
            // nothing to say
            if phrase.count == 0 {
                return
            }
            
            let spokenPhrase = AVSpeechUtterance(string: phrase)
            
            let audioSession = AVAudioSession.sharedInstance()
            try? audioSession.setActive(true)
            self.synthesizer.speak(spokenPhrase)
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
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label = UILabel()
        label.textAlignment = .center
        label.text = self.tableView(tableView, titleForHeaderInSection: section)
        label.textColor = UIColor(red: 255.0/255.0,
                                  green: 45.0/255.0,
                                  blue: 85.0/255.0,
                                  alpha: 1.0)
        return label
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 22.0
    }
    
}

extension RecordWorkoutViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if let workout = workoutTracker {
            if workout.isRunning {
                return 2
            }
        }
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        var currentSection = false
        if let workout = workoutTracker {
            if workout.isRunning {
                if section == 0 {
                    currentSection = true
                }
            }
        }
        
        if currentSection {
            return 1
        } else {
            return latestSplits.count > 0 ? latestSplits.count - 1 : 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        var currentSection = false
        if let workout = workoutTracker {
            if workout.isRunning {
                if section == 0 {
                    currentSection = true
                }
            }
        }
        
        if currentSection {
            switch section {
            case 0:
                return "Current"
            case 1:
                return "Splits"
            default:
                return ""
            }
        } else {
            return latestSplits.count > 1 ? "Splits" : ""
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "splitsReuseIdentifier", for: indexPath)
        
        if latestSplits.count == 0 {
            cell.textLabel?.text = ""
            cell.detailTextLabel?.text = ""
            return cell
        }
        
        var currentSection = false
        if let workout = workoutTracker {
            if workout.isRunning {
                if indexPath.section == 0 {
                    currentSection = true
                }
            }
        }
        
        if currentSection {
            
            guard let workout = workoutTracker else {
                return cell
            }
            
            let firstSplit = latestSplits[0]
            
            let splitDuration = Date().timeIntervalSince(firstSplit.time)
            
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second, .nanosecond]
            formatter.unitsStyle = .abbreviated
            cell.textLabel?.text = formatter.string(from: splitDuration)
            
            let units = WorkoutTracker.getDistanceUnitSetting()
            switch units {
            case .Miles:
                let distance = workout.estimatedDistance / 1609.34
                cell.detailTextLabel?.text = String(format: "%.2f miles", distance)
            case .Kilometers:
                let distance = workout.estimatedDistance / 1000.0
                cell.detailTextLabel?.text = String(format: "%.2f km", distance)
            }
            
            return cell
        } else {
            
            let index = (latestSplits.count - 1) - indexPath.row
        
            let split = latestSplits[index]
            let firstSplit = latestSplits[0]
            
            let splitDuration = split.time.timeIntervalSince(firstSplit.time)
            
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second, .nanosecond]
            formatter.unitsStyle = .abbreviated
            cell.textLabel?.text = formatter.string(from: splitDuration)
            
            let units = WorkoutTracker.getDistanceUnitSetting()
            switch units {
            case .Miles:
                let distance = split.distance / 1609.34
                
                var unit = "s"
                if Int(distance * 100) == 100 {
                    unit = ""
                }
                
                cell.detailTextLabel?.text = String(format: "%.2f mile%@", distance, unit)
            case .Kilometers:
                let distance = split.distance / 1000.0
                cell.detailTextLabel?.text = String(format: "%.2f km", distance)
            }
            
            return cell
        }
    }
}

extension RecordWorkoutViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        let targetActivityIndex = indexPath.row
        
        let indexPath = IndexPath(item: targetActivityIndex, section: 0)
        let scrollPosition: UICollectionView.ScrollPosition = .centeredHorizontally
        self.activityCollectionView.scrollToItem(at: indexPath, at: scrollPosition, animated: true)
        
        activityTypeIndex = targetActivityIndex
        updateUI()
    }

}

extension RecordWorkoutViewController: UIScrollViewDelegate {
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {

        guard ((scrollView as? UICollectionView) != nil) else {
            return
        }
        
        let layout = self.activityCollectionView.collectionViewLayout as! UPCarouselFlowLayout
        let pageSide = (layout.scrollDirection == .horizontal) ? self.pageSize.width : self.pageSize.height
        let offset = (layout.scrollDirection == .horizontal) ? scrollView.contentOffset.x : scrollView.contentOffset.y
        activityTypeIndex = Int(floor((offset - pageSide / 2) / pageSide) + 1)
        
        self.updateUI()
    }
}

extension RecordWorkoutViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return WorkoutTracker.supportedWorkouts.count;
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "activitySelectorCell", for: indexPath) as! WorkoutSelectionViewCell
        let activityType = WorkoutTracker.supportedWorkouts[indexPath.row]
        cell.imageView.image = UIImage(named: activityType.String())
        return cell
    }
    
}

extension RecordWorkoutViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            print("Warming GPS accuracy to \(location.horizontalAccuracy)")
        }
    }
}
