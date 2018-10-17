//
//  ViewController.swift
//  beaconManager
//
//  Created by Danny Daniil on 8/27/18.
//  Copyright © 2018 Danny Daniil. All rights reserved.
//

import UIKit
import CoreBluetooth
import CoreLocation
import Firebase

//let currentId = "1"
//let otherId = "2"


class location: UIViewController, CLLocationManagerDelegate{

    var ref: DatabaseReference!

    //SET & GET
    var transformAngle: Double?
    var currentLocation: CLLocation?

    //IBOUTLETS
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var latitudeLabel: UILabel!
    @IBOutlet weak var longitudeLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    var locationManager: CLLocationManager!


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        setupLocationManager()
        setupFirebase()
    }

    func setupFirebase() {

        ref = Database.database().reference()

        ref.child("compass").child(otherId).observe(.value) { (snapshot) in
            if let values = snapshot.value as? [String: Double]{

                let toLocation = CLLocation(latitude: values["lat"]!, longitude: values["long"]!)
                if let fromLocation = self.currentLocation {
                    self.rotateCompass(from: fromLocation, to: toLocation)
                    self.updateDistance(from: fromLocation, to: toLocation)
                }
            }
        }
    }

    func setupLocationManager() {

        locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()

        let authorizationStatus = CLLocationManager.authorizationStatus()
        if authorizationStatus != .authorizedWhenInUse && authorizationStatus != .authorizedAlways {
            // User has not authorized access to location information.
            return
        }

        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        if let lastLocation = locations.last {
            self.currentLocation = lastLocation

            // UPDATE MY DATA
            self.ref.child("compass").child(currentId).setValue([
                "lat": lastLocation.coordinate.latitude,
                "long": lastLocation.coordinate.longitude
            ])

            showCoordinates(location: lastLocation)

            self.ref.child("compass").child(otherId).observeSingleEvent(of: .value) { (snapshot) in
                if let values = snapshot.value as? [String: Double]{

                    let toLocation = CLLocation(latitude: values["lat"]!, longitude: values["long"]!)
                    self.rotateCompass(from: lastLocation,to: toLocation)
                    self.updateDistance(from: lastLocation, to: toLocation)
                }
            }
        }
    }


    func showCoordinates(location: CLLocation) {

//        self.latitudeLabel.text = "\(location.coordinate.latitude)"
//        self.longitudeLabel.text = "\(location.coordinate.longitude)"
    }

    func rotateCompass(from: CLLocation, to: CLLocation) {
        transformAngle = from.bearingToLocationRadian(to)

        if (from.coordinate.latitude > to.coordinate.latitude) {
            self.latitudeLabel.text = "back"
        }

        if (from.coordinate.latitude < to.coordinate.latitude) {
            self.latitudeLabel.text = "front"
        }

        if (from.coordinate.longitude > to.coordinate.longitude) {
            self.longitudeLabel.text = "left"
        }

        if (from.coordinate.longitude < to.coordinate.longitude) {
            self.longitudeLabel.text = "right"
        }

    }

    func updateDistance(from: CLLocation, to: CLLocation) {

        let distance = from.distance(from: to)
        self.distanceLabel.text = "Distance: \(distance)"
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {

//        if let latestAngle = self.transformAngle {
//            let angle = newHeading.trueHeading.toRadians
//            self.imageView.transform = CGAffineTransform(rotationAngle: CGFloat(latestAngle - angle))
//        }

        let angle = newHeading.trueHeading.toRadians
        self.imageView.transform = CGAffineTransform(rotationAngle: CGFloat(angle))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}

extension Double {
    var toRadians: Double { return self * .pi / 180 }
    var toDegrees: Double { return self * 180 / .pi }
}

public extension CLLocation {
    func bearingToLocationRadian(_ destinationLocation: CLLocation) -> Double {

        let lat1 = self.coordinate.latitude.toRadians
        let lon1 = self.coordinate.longitude.toRadians

        let lat2 = destinationLocation.coordinate.latitude.toRadians
        let lon2 = destinationLocation.coordinate.longitude.toRadians

        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)

        return Double(radiansBearing)
    }

    func bearingToLocationDegrees(destinationLocation: CLLocation) -> Double {
        return bearingToLocationRadian(destinationLocation).toDegrees
    }
}

