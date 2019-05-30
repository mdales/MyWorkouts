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

    func setWorkout(_ workout: HKWorkout) {
        
        routeMapView.delegate = self
        
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
        
        let query = HKWorkoutRouteQuery(route: route) { (query, locationsOrNil, done, errorOrNil) in
            
            // This block may be called multiple times.
            
            if let error = errorOrNil {
                print("Failed to get route data: \(error)")
                return
            }
            
            guard let locations = locationsOrNil else {
                fatalError("*** Invalid State: This can only fail if there was an error. ***")
            }
            
            DispatchQueue.main.async {
                let locations2D = locations.map { return $0.coordinate }
                let polyline = MKPolyline(coordinates: locations2D, count: locations.count)
                self.routeMapView.addOverlay(polyline)
                self.routeMapView.centerCoordinate = polyline.coordinate
                self.routeMapView.setVisibleMapRect(polyline.boundingMapRect, animated: true)
            }
            
            if done {
                // The query returned all the location data associated with the route.
                // Do something with the complete data set.
            }
            
            // You can stop the query by calling:
            // store.stop(query)
            
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
            return workout.totalEnergyBurned != nil ? 4 : 3
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
