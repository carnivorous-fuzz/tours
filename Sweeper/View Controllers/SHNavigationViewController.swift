//
//  SHNavigationViewController.swift
//  Sweeper
//
//  Created by Raina Wang on 10/21/17.
//  Copyright © 2017 team11. All rights reserved.
//

import UIKit
import MapboxDirections
import MapboxNavigation

class SHNavigationViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!

    @IBAction func onCancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func onStart(_ sender: Any) {
        let routeOptions = determineRoute()
        if routeOptions != nil {
            startNav(routeOpt: routeOptions!)
        }
    }

    fileprivate var currentLocation: CLLocation?
    fileprivate var locationManager: CLLocationManager!
    var scavengerHunt: ScavengerHunt!
    var currentPinIndex: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.navigationBar.barTintColor = UIColor.white
        navigationController?.navigationBar.tintColor = UIConstants.Theme.green
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.gray]

        getLocation()

        tableView.tableFooterView = UIView(frame: CGRect.zero)
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 120
    }

    fileprivate func determineRoute() -> RouteOptions? {
        if (currentLocation != nil) &&
            (scavengerHunt.pins != nil) &&
            (currentPinIndex <= scavengerHunt.pins!.count)
        {
            let origin = Waypoint(coordinate: currentLocation!.coordinate, name: "Your location")
            let currentPin = scavengerHunt.pins?[currentPinIndex]
            if let currentPin = currentPin {
                let pinLatitude = currentPin.location?.latitude
                let pinLongitude = currentPin.location?.longitude
                let destination = Waypoint(coordinate: CLLocationCoordinate2D(latitude: pinLatitude!, longitude: pinLongitude!), name: currentPin.blurb)
                return RouteOptions(waypoints: [origin, destination])
            }
            return nil
        }
        return nil
    }

    fileprivate func startNav(routeOpt: RouteOptions) {
        routeOpt.routeShapeResolution = .full
        routeOpt.includesSteps = true
        // TODO: let user input identifier
        routeOpt.profileIdentifier = MBDirectionsProfileIdentifier.walking

        Directions.shared.calculate(routeOpt) { (waypoints, routes, error) in
            guard let route = routes?.first else { return }

            let viewController = NavigationViewController(for: route)
            viewController.navigationDelegate = self
            self.present(viewController, animated: true, completion: nil)
        }
    }

    fileprivate func fetchPins() {
        if self.currentLocation != nil {
            PinService.sharedInstance.fetchPins(with: scavengerHunt.selectedTags!, in: scavengerHunt.radius!.doubleValue, for: self.currentLocation!) {
                (pins: [Pin]?, error: Error?) in
                if (pins != nil) && (pins!.count > 0) {
                    self.scavengerHunt.pins = pins
                    self.scavengerHunt.saveInBackground()
                    self.tableView.reloadData()
                } else {
                    print("Sorry, there's no match within your location")
                }
            }
        } else {
            print("Can't get your current location")
        }
    }

    fileprivate func getLocation() {
        locationManager = CLLocationManager()

        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.requestWhenInUseAuthorization()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 200
        locationManager.startUpdatingLocation()
    }
}

extension SHNavigationViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.scavengerHunt.pinCount?.intValue ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "PinOverviewCell") as? PinOverviewCell {
            if self.scavengerHunt.pins != nil {
                cell.rowNumberLabel.text = "\(indexPath.row + 1)"
                cell.pin = self.scavengerHunt.pins![indexPath.row]
                return cell
            }
        }
        return PinOverviewCell()
    }
}

// MARK: Location manager delegate
extension SHNavigationViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            self.currentLocation = location
            fetchPins()
        }
    }
}

extension SHNavigationViewController: NavigationViewControllerDelegate {
    func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) {
        navigationViewController.dismiss(animated: true) {
            let justVisitedPin = self.scavengerHunt.pins![self.currentPinIndex]

            PinService.sharedInstance.markAsViewed(by: User.current()!, with: justVisitedPin)

            let pinDetailsNC = UIStoryboard.pinDetailsNC
            let pinDetailsVC = pinDetailsNC.topViewController as! PinDetailsViewController

            self.currentPinIndex += 1

            pinDetailsVC.pin = justVisitedPin
            pinDetailsVC.delegate = self

            let hasNext = self.currentPinIndex <= self.scavengerHunt.pins!.count - 1
            pinDetailsVC.hasNext = hasNext
            self.present(pinDetailsNC, animated: true, completion: nil)
        }
    }
}

extension SHNavigationViewController: PinDetailsViewControllerDelegate {
    func onNextPin(pinDetailsViewController: PinDetailsViewController) {
        onStart(self)
    }
    func onEndTour(pinDetailsViewController: PinDetailsViewController) {
        dismiss(animated: true, completion: nil)
    }
}
