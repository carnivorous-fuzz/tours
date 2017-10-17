//
//  PinViewsViewController.swift
//  Sweeper
//
//  Created by Wuming Xie on 10/13/17.
//  Copyright © 2017 team11. All rights reserved.
//

import UIKit
import Mapbox

class PinViewsViewController: UIViewController {
    
    let defaultLocation = CLLocation(latitude: 37.787353, longitude: -122.421561)
    var locationManager: CLLocationManager!
    var currentLocation: CLLocation?
    var mapView: MGLMapView!
    var zoomLevel = 15.0
    var pins: [Pin]!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Request location
        requestLocationPermission()

        // Create map
        mapView = MGLMapView(frame: view.bounds, styleURL: MGLStyle.darkStyleURL(withVersion: 9))
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.setCenter(defaultLocation.coordinate, zoomLevel: zoomLevel, animated: false)
        mapView.showsUserLocation = true
        mapView.delegate = self
        mapView.isHidden = true
        view.addSubview(mapView)
        
        var annotations: [PinAnnotation] = []
        PinService.sharedInstance.fetchPins { (pins, error) in
            if let pins = pins {
                self.pins = pins
                self.pins.forEach({ (pin) in
                    if pin.location != nil {
                        let point = PinAnnotation(fromPin: pin)
                        annotations.append(point)
                    }
                })
                self.mapView.addAnnotations(annotations)
            } else {
                print(error.debugDescription)
            }
        }
    }
    
    @IBAction func onPost(_ sender: UIBarButtonItem) {
        let storyboard = UIStoryboard(name: "CreatePin", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "CreatePinNavViewController")

        present(vc, animated: true, completion: nil)
    }
    
    @IBAction func onLogout(_ sender: UIBarButtonItem) {
        UserService.sharedInstance.logout()
    }
    
    private func requestLocationPermission() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 200
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
}

// MARK:- Location manager delegate
extension PinViewsViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            mapView?.setCenter(location.coordinate, zoomLevel: mapView?.zoomLevel ?? zoomLevel, animated: !mapView.isHidden)
            if mapView.isHidden {
                mapView.isHidden = false
            }
        }
    }
    
    // TODO: Handle authorization for the location manager.
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .restricted:
            print("Location access was restricted.")
        case .denied:
            print("User denied access to location.")
            // Display the map using the default location.
            mapView.isHidden = false
        case .notDetermined:
            print("Location status not determined.")
        case .authorizedAlways: fallthrough
        case .authorizedWhenInUse:
            print("Location status is OK.")
        }
    }
}

// MARK:- Mapbox map view delegate
extension PinViewsViewController: MGLMapViewDelegate {
    
    func mapView(_ mapView: MGLMapView, viewFor annotation: MGLAnnotation) -> MGLAnnotationView? {
        guard annotation is MGLPointAnnotation else {
            return nil
        }
        
        let reuseIdentifier = "\(annotation.coordinate.longitude)"
        
        // For better performance, always try to reuse existing annotations.
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)
        
        // If there’s no reusable annotation view available, initialize a new one.
        if annotationView == nil {
            annotationView = CustomAnnotationView(reuseIdentifier: reuseIdentifier)
            annotationView!.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
            
            // Set the annotation view’s background color to a value determined by its longitude.
            let hue = CGFloat(annotation.coordinate.longitude) / 100
            annotationView!.backgroundColor = UIColor(hue: hue, saturation: 0.5, brightness: 1, alpha: 1)
        }
        
        return annotationView
    }
    
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        // TODO: We can restrict access here
        return true
    }
    
    func mapView(_ mapView: MGLMapView, tapOnCalloutFor annotation: MGLAnnotation) {
        let vc = StoryboardUtils.initVC(storyboard: "ViewPin", identifier: "PinDetailsViewController") as! PinDetailsViewController
        vc.pinAnnotation = annotation as! PinAnnotation
        show(vc, sender: nil)
    }
}
