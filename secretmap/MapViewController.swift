//
//  MapViewController.swift
//  kubecoin
//
//  Created by Joe Anthony Peter Amanse on 5/3/18.
//  Copyright © 2018 Anton McConville. All rights reserved.
//

import Foundation
import MapKit

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UIPopoverPresentationControllerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    
    var locationManager: CLLocationManager!
    
    var regionsVisited: [String]?
    
    var regions: [CLCircularRegion]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let themeColor = UIColor(red:0.76, green:0.86, blue:0.83, alpha:1.0)
        let statusBar = UIView(frame: CGRect(x:0, y:0, width:view.frame.width, height:UIApplication.shared.statusBarFrame.height))
        statusBar.backgroundColor = themeColor
        statusBar.tintColor = themeColor
        view.addSubview(statusBar)
        
        getRegionsVisited()
        
        locationManager = CLLocationManager()
        enableLocationServices()
        
        mapView.delegate = self
        
        let initialLocation = CLLocation(latitude: 40.748591, longitude: -73.985630)
        
        // remove previous monitored region
        for monitoredRegion in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: monitoredRegion)
        }
        
        // array of regions
        let sampleRegions: [CLCircularRegion] = [
            region(center: CLLocationCoordinate2D.init(latitude: 40.748591, longitude: -73.985630), radius: CLLocationDistance.init(1000.00), identifier: "Empire State Building"),
            region(center: CLLocationCoordinate2D.init(latitude: 40.769206, longitude: -73.971940), radius: CLLocationDistance.init(1000.00), identifier: "Central Park Zoo"),
            region(center: CLLocationCoordinate2D.init(latitude: 40.758980, longitude: -73.984427), radius: CLLocationDistance.init(1000.00), identifier: "Town Square"),
            region(center: CLLocationCoordinate2D.init(latitude: 40.689249, longitude: -74.044468), radius: CLLocationDistance.init(1000.00), identifier: "Statue of Liberty"),
            region(center: CLLocationCoordinate2D.init(latitude: 40.710192, longitude: -74.056352), radius: CLLocationDistance.init(1000.00), identifier: "Liberty State Park Station")
        ]
        
        regions = sampleRegions
        
        // start monitoring regions
        for sampleRegion in sampleRegions {
            locationManager.startMonitoring(for: sampleRegion)
        }
        
        if !CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
            print("Geofencing is not supported on this device!")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        getRegionsVisited()
        
        // center on location
        if (CLLocationManager.authorizationStatus() == .authorizedAlways || CLLocationManager.authorizationStatus() == .authorizedWhenInUse) {
            centerMapOnLocation(location: locationManager.location!)
        }
        
        // remove overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        // add the overlays and annotations
        addRegionsMarkers(regions!)
    }
    
    func getRegionsVisited() {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        
        var currentPerson:Person
        
        var people: [Person] = []
        
        do {
            people = try context.fetch(Person.fetchRequest())
            
            if( people.count > 0 ){
                currentPerson = people[0]
                
                regionsVisited = currentPerson.regions
            }
        }catch{
            print("problem getting regions visited")
        }
    }
    
    func addRegionsMarkers(_ regions: [CLCircularRegion]) {
        for region in regions {
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D.init(latitude: region.center.latitude, longitude: region.center.longitude)
            annotation.subtitle = region.identifier
            let circle = MKCircle(center: region.center, radius: 1000.00)
            circle.title = region.identifier
            mapView.addAnnotation(annotation)
            mapView.add(circle)
        }
    }
    
    // this makes a region on coordinates of CENTER with a radius of RADIUS
    func region(center: CLLocationCoordinate2D, radius: CLLocationDistance, identifier: String) -> CLCircularRegion {
        let region = CLCircularRegion(center: center, radius: radius, identifier: identifier);
        region.notifyOnEntry = true
        region.notifyOnExit = false
        return region
    }
    
    // overlay
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKCircle {
            let circle = MKCircleRenderer(overlay: overlay)
            
            var strokeColor = UIColor.red
            var fillColor = UIColor(red: 255, green: 0, blue: 0, alpha: 0.1)
            
            if (regionsVisited?.contains(overlay.title!!) == true) {
                strokeColor = UIColor.gray
                fillColor = UIColor.gray.withAlphaComponent(0.3)
            }
            
            circle.strokeColor = strokeColor
            circle.fillColor = fillColor
            circle.lineWidth = 1
            return circle
        } else {
            return MKOverlayRenderer()
        }
    }
    
    // annotation
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let subtitle = annotation.subtitle, let regionVisited = subtitle {
            if (regionsVisited?.contains(regionVisited) == true) {
                let pin = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "test")
                pin.pinTintColor = UIColor.gray
                pin.canShowCallout = true
                return pin
            }
        }
        return nil
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        // center to user's location when authorized
        if (status == .authorizedAlways || status == .authorizedWhenInUse) {
            centerMapOnLocation(location: manager.location!)
        }
    }
    
    // handle geofence error
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Monitoring failed for region with identifier: \(region!.identifier)")
    }
    
    // handle geofence error
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager failed with the following error: \(error)")
    }
    
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 5000, 5000)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    func enableLocationServices() {
        locationManager.delegate = self
        
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined, .restricted, .denied:
            // Request when-in-use authorization initially and if restricted and denied
            locationManager.requestAlwaysAuthorization()
            break
            
        case .authorizedWhenInUse:
            break
            
        case .authorizedAlways:
            centerMapOnLocation(location: locationManager.location!)
            break
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "popoverSegue" {
            let popoverViewController = segue.destination
            popoverViewController.modalPresentationStyle = UIModalPresentationStyle.popover
            popoverViewController.popoverPresentationController!.delegate = self
            popoverViewController.view.backgroundColor = UIColor.clear
        }
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
}
