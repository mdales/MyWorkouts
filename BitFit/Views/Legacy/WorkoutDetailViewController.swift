//
//  WorkoutDetailViewController.swift
//  BitFit
//
//  Created by Michael Dales on 29/05/2019.
//  Copyright © 2019 Digital Flapjack Ltd. All rights reserved.
//

import UIKit
import HealthKit
import MapKit

class RouteCell: UITableViewCell {
    
    @IBOutlet weak var routeMapView: MKMapView!
    
    var points = [CLLocationCoordinate2D]()

    func setWorkout(_ workout: HKWorkout) {
        
        routeMapView.delegate = self
        routeMapView.removeAnnotations(routeMapView.annotations)
        routeMapView.removeOverlays(routeMapView.overlays)
        
        points = [CLLocationCoordinate2D]()
        
        let runningObjectQuery = HKQuery.predicateForObjects(from: workout)
        
        let routeQuery = HKAnchoredObjectQuery(type: HKSeriesType.workoutRoute(), predicate: runningObjectQuery, anchor: nil, limit: HKObjectQueryNoLimit) { (query, samples, deletedObjects, anchor, error) in
            
            if let err = error {
                print("Failed to load route data: \(err)")
                return
            }
            
            if let sampleList = samples {
                for sample in sampleList {
                    self.getRouteForSample(sample: sample)
                }
            }
        }
        
        routeQuery.updateHandler = { (query, samples, deleted, anchor, error) in
            
            guard error == nil else {
                // Handle any errors here.
                fatalError("The update failed.")
            }
            
            if let sampleList = samples {
                for sample in sampleList {
                    self.getRouteForSample(sample: sample)
                }
            }
        }
        
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.healthStore.execute(routeQuery)
    }
    
    func getRouteForSample(sample: HKSample) {
        
        guard let route = sample as? HKWorkoutRoute else {
            print("This wasn't a workout route")
            return
        }
        
        var distance = 0.0
        var last_loc: CLLocation? = nil
        
        let query = HKWorkoutRouteQuery(route: route) { (query, locationsOrNil, done, errorOrNil) in
            
            // This block may be called multiple times.
            
            if let error = errorOrNil {
                print("Failed to get route data: \(error)")
                return
            }
            
            guard let locations = locationsOrNil else {
                fatalError("*** Invalid State: This can only fail if there was an error. ***")
            }
            
            // is this the first point?
            if self.points.count == 0 && locations.count > 0 {
                let annotation = MKPointAnnotation()
                annotation.title = "Start"
                annotation.coordinate = locations[0].coordinate
                self.routeMapView.addAnnotation(annotation)
            }
            
            let splitDistance = WorkoutTracker.getDistanceUnitSetting() == .Miles ? 1609.34 : 1000.0
            let units = WorkoutTracker.getDistanceUnitSetting() == .Miles ? "m" : "km"
            for loc in locations {
                if let last = last_loc {
                    let delta = loc.distance(from: last)
                    let last_disance = distance
                    distance += delta
                    if Int(distance / splitDistance) != Int(last_disance / splitDistance) {
                        let annotation = MKPointAnnotation()
                        annotation.title = "\(Int(distance/splitDistance)) \(units)"
                        annotation.coordinate = loc.coordinate
                        self.routeMapView.addAnnotation(annotation)
                    }
                }
                last_loc = loc
            }
            
            let locations2D = locations.map { return $0.coordinate }
            self.points += locations2D
            
            if done {
                
                if self.points.count > 0 {
                    let annotation = MKPointAnnotation()
                    annotation.title = "End"
                    annotation.coordinate = self.points[self.points.count - 1]
                    self.routeMapView.addAnnotation(annotation)
                }
                
                let polyline = MKPolyline(coordinates: self.points, count: self.points.count)
                DispatchQueue.main.async {
                    self.routeMapView.addOverlay(polyline)
                    self.routeMapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 20.0, left: 20.0, bottom: 10.0, right: 20.0), animated: false)
                }
                
            }
        }
        
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.healthStore.execute(query)
        }
    }
}

extension RouteCell: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let testlineRenderer = MKPolylineRenderer(polyline: polyline)
            testlineRenderer.strokeColor = UIColor(red: 1.0, green: 45.0/255.0, blue: 85.0/255.0, alpha: 1.0)
            testlineRenderer.lineWidth = 2.0
            return testlineRenderer
        }
        fatalError()
    }
    
}

class WorkoutDetailViewController: UITableViewController {
    
    var workout: HKWorkout?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.separatorStyle = .none
    }
    
    override func viewWillAppear(_ animated: Bool) {
        tableView.reloadData()
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let workout = self.workout else {
            return 0
        }
        
        switch section {
        case 0:
            return workout.totalEnergyBurned != nil ? 6 : 5
        case 1:
            return 1
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let workout = self.workout else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "detailReuseIdentifier", for: indexPath)
            cell.textLabel?.text = ""
            cell.detailTextLabel?.text = ""
            return cell
        }
        
        if indexPath.section == 0 {
        
            let cell = tableView.dequeueReusableCell(withIdentifier: "detailReuseIdentifier", for: indexPath)
            
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
                cell.textLabel?.text = "Average speed"
                
                if let averageSpeedQuantity = workout.metadata?[HKMetadataKeyAverageSpeed] as? HKQuantity {
                    
                    let avgSpeed = averageSpeedQuantity.doubleValue(for: HKUnit.meter().unitDivided(by: HKUnit.second()))
                    switch WorkoutTracker.getDistanceUnitSetting() {
                    case .Kilometers:
                        cell.detailTextLabel?.text = String(format: "%.2f km/h", avgSpeed * 3.6)
                    case .Miles:
                        cell.detailTextLabel?.text = String(format: "%.2f mph", avgSpeed * 2.236936)
                    }
                } else {
                    cell.detailTextLabel?.text = "No average speed"
                }
            case 4:
                cell.textLabel?.text = "Peak speed"
                
                if let peakSpeedQuantity = workout.metadata?[HKMetadataKeyMaximumSpeed] as? HKQuantity {
                    
                    let peakSpeed = peakSpeedQuantity.doubleValue(for: HKUnit.meter().unitDivided(by: HKUnit.second()))
                    switch WorkoutTracker.getDistanceUnitSetting() {
                    case .Kilometers:
                        cell.detailTextLabel?.text = String(format: "%.2f km/h", peakSpeed * 3.6)
                    case .Miles:
                        cell.detailTextLabel?.text = String(format: "%.2f mph", peakSpeed * 2.236936)
                    }
                } else {
                    cell.detailTextLabel?.text = "No peak speed"
                }
            case 5:
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
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "routeReuseIdentifier", for: indexPath) as! RouteCell
            cell.setWorkout(workout)
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "General"
        case 1:
            return "Route"
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 1:
            return 348
        default:
            return 43
        }
    }
    
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
    
}
