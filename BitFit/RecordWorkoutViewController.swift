//
//  ViewController.swift
//  BitFit
//
//  Created by Michael Dales on 19/05/2019.
//  Copyright © 2019 Digital Flapjack Ltd. All rights reserved.
//

import UIKit
import HealthKit
import AVKit
import os.log
import UPCarouselFlowLayout

extension HKWorkoutActivityType {
    func DisplayString() -> String {
        switch self {
        case .running:
            return "Running"
        case .walking:
            return "Walking"
        case .cycling:
            return "Cycling"
        case .wheelchairRunPace:
            return "Wheelchair, fast pace"
        case .wheelchairWalkPace:
            return "Wheelchair, medium pace"
        default:
            return "Unknown activity"
        }
    }
}

class RecordWorkoutViewController: UIViewController {

    @IBOutlet weak var activityCollectionView: UICollectionView!
    @IBOutlet weak var lockedActivityImageView: UIImageView!
    @IBOutlet weak var activityLabel: UILabel!
    @IBOutlet weak var toggleButton: UIButton!
    @IBOutlet weak var splitsTableView: UITableView!
    @IBOutlet weak var gpsAccuracyImage: UIImageView!
    
    let synthesizer = AVSpeechSynthesizer()
    
    var updateTimer: Timer? = nil
    var workoutTracker: WorkoutTracker?
    
    var activityTypeIndex = 0
    
    var latestSplits = [WorkoutSplit]()
    
    fileprivate var currentPage: Int = 0 {
        didSet {
            let activityType = WorkoutTracker.supportedWorkouts[self.currentPage]
            self.activityLabel.text = "Activity: \(activityType.DisplayString())"
        }
    }
    
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
        currentPage = activityTypeIndex
        
        
        let indexPath = IndexPath(item: currentPage, section: 0)
        let scrollPosition: UICollectionView.ScrollPosition = .centeredHorizontally
        self.activityCollectionView.scrollToItem(at: indexPath, at: scrollPosition, animated: false)
        lockedActivityImageView.image = UIImage(named: WorkoutTracker.supportedWorkouts[activityTypeIndex].String())
        
        
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
    
//    @IBAction func changeActivity(_ sender: Any) {
//
//        activityTypeIndex = (activityTypeIndex + 1) % WorkoutTracker.supportedWorkouts.count
//        UserDefaults.standard.set(activityTypeIndex, forKey: "LastActivityIndex")
//
//        let activityType = WorkoutTracker.supportedWorkouts[activityTypeIndex]
//        activityButton.setImage(UIImage(named:activityType.String()), for: .normal)
//    }
    
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
            
//            self.activityButton.isEnabled = false
            self.lockedActivityImageView.isHidden = false
            self.activityCollectionView.isHidden = true
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
                self.toggleButton.setTitle("Start", for: .normal)
//                self.activityButton.isEnabled = true
                self.activityCollectionView.isHidden = false
                self.lockedActivityImageView.isHidden = true
                self.splitsTableView.reloadData()
            }
        }
    }
}

extension RecordWorkoutViewController: WorkoutTrackerDelegate {
    
    func stateUpdated(newState: WorkoutState) {
        
        DispatchQueue.main.async {
            switch newState {
            case .WaitingForGPS, .WaitingForLocationStream:
                self.gpsAccuracyImage.isHidden = false
                self.activityLabel.text = "Waiting for GPS..."
                self.toggleButton.setTitle("Cancel", for: .normal)
            case .Started:
                self.gpsAccuracyImage.isHidden = true
                let activityType = WorkoutTracker.supportedWorkouts[self.activityTypeIndex]
                self.activityLabel.text = "Activity: \(activityType.DisplayString())"
                self.toggleButton.setTitle("Stop", for: .normal)
                
                let spokenPhrase = AVSpeechUtterance(string: "Go!")
                let audioSession = AVAudioSession.sharedInstance()
                try? audioSession.setActive(true)
                self.synthesizer.speak(spokenPhrase)
            case .Failed:
                self.workoutTracker = nil
                self.toggleButton.setTitle("Start", for: .normal)
//                self.activityButton.isEnabled = true
                self.activityCollectionView.isHidden = false
                self.lockedActivityImageView.isHidden = true
                self.splitsTableView.reloadData()
                
                let spokenPhrase = AVSpeechUtterance(string: "Sorry, workout failed.")
                let audioSession = AVAudioSession.sharedInstance()
                try? audioSession.setActive(true)
                self.synthesizer.speak(spokenPhrase)
            default:
                self.gpsAccuracyImage.isHidden = true
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
            let announceDistance = UserDefaults.standard.bool(forKey: SettingsNames.DistanceAnnoucement.rawValue)
            let announceTime = UserDefaults.standard.bool(forKey: SettingsNames.TimeAnnouncement.rawValue)
            let announcePace = UserDefaults.standard.bool(forKey: SettingsNames.PaceAnnouncement.rawValue)
            
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
                    phrase = String(format: "%@ Distance %@ miles. --", phrase, numFormatter.string(from: NSNumber(floatLiteral: distance))!)
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
                    phrase = String(format: "%@ Distance %@ miles. --", phrase, numFormatter.string(from: NSNumber(floatLiteral: distance))!)
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
                cell.detailTextLabel?.text = String(format: "%.2f miles", distance)
            case .Kilometers:
                let distance = split.distance / 1000.0
                cell.detailTextLabel?.text = String(format: "%.2f km", distance)
            }
            
            return cell
        }
    }
}

//extension RecordWorkoutViewController: UICollectionViewDelegate {
//
//    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        let activityType = WorkoutTracker.supportedWorkouts[indexPath.row]
//
//        let alert = UIAlertController(title: activityType.String(), message: nil, preferredStyle: .alert)
//        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
//        present(alert, animated: true, completion: nil)
//    }
//
//}

extension RecordWorkoutViewController: UIScrollViewDelegate {
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let layout = self.activityCollectionView.collectionViewLayout as! UPCarouselFlowLayout
        let pageSide = (layout.scrollDirection == .horizontal) ? self.pageSize.width : self.pageSize.height
        let offset = (layout.scrollDirection == .horizontal) ? scrollView.contentOffset.x : scrollView.contentOffset.y
        currentPage = Int(floor((offset - pageSide / 2) / pageSide) + 1)
        
        activityTypeIndex = currentPage
        UserDefaults.standard.set(activityTypeIndex, forKey: "LastActivityIndex")
        let activityType = WorkoutTracker.supportedWorkouts[activityTypeIndex]
        lockedActivityImageView.image = UIImage(named: activityType.String())
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
