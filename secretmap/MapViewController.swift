//
//  MapViewController.swift
//  kubecoin
//
//  Created by Joe Anthony Peter Amanse on 5/3/18.
//  Copyright © 2018 Anton McConville. All rights reserved.
//

import Foundation
import MapKit

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
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
        
        let initialLocation = CLLocation(latitude: 33.918783, longitude: -118.216600)
        centerMapOnLocation(location: initialLocation)
        
        // remove previous monitored region
        for monitoredRegion in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: monitoredRegion)
        }
        
        // array of regions
        let sampleRegions: [CLCircularRegion] = [
            region(center: CLLocationCoordinate2D.init(latitude: 33.918783, longitude: -118.216600), radius: CLLocationDistance.init(1000.00), identifier: "Lynwood"),
            region(center: CLLocationCoordinate2D.init(latitude: 33.922926, longitude: -118.113632), radius: CLLocationDistance.init(1000.00), identifier: "Downey"),
            region(center: CLLocationCoordinate2D.init(latitude: 33.991037, longitude: -117.720895), radius: CLLocationDistance.init(1000.00), identifier: "Chino Hills"),
            region(center: CLLocationCoordinate2D.init(latitude: 33.982299, longitude: -117.703610), radius: CLLocationDistance.init(1000.00), identifier: "Lucille's")
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
    
    // handle geofence error
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Monitoring failed for region with identifier: \(region!.identifier)")
    }
    
    // handle geofence error
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager failed with the following error: \(error)")
    }
    
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 1000, 1000)
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
            // Enable any of your app's location features
//            enableMyAlwaysFeatures()
            break
        }
    }
}
