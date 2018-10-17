//
//  LocationDelegate.swift
//  beaconManager
//
//  Created by Danny Daniil on 9/2/18.
//  Copyright © 2018 Danny Daniil. All rights reserved.
//

import Foundation
import CoreLocation


class LocationDelegate: NSObject, CLLocationManagerDelegate {
    
    //MARK: - Callbacks
    
    var didEnterRegionCallback: ((CLRegion) -> ())? = nil
    var didRangeBeaconsCallback: (([CLBeacon], CLBeaconRegion) -> ())? = nil
    
    //MARK: - Delegate Functions
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        var authStatus = String()
        
        switch  status {
        case .authorizedAlways:
            authStatus = "Always"
            break
        case .authorizedWhenInUse:
            authStatus = "When in Use"
            break
        case .denied:
            authStatus = "Denied"
            break
        case .restricted:
            authStatus = "Restricted"
            break
        default:
            authStatus = "Unknown Auth Status"
        }
        print(authStatus)
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        
        if region is CLBeaconRegion {
            print("didExitRegion")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        didEnterRegionCallback?(region)
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        
        if region is CLBeaconRegion {
            print("monitoringFail")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        didRangeBeaconsCallback?(beacons,region)
    }
}
