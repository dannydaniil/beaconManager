//
//  beaconReceiverDelegate.swift
//  beaconManager
//
//  Created by Danny Daniil on 8/30/18.
//  Copyright © 2018 Danny Daniil. All rights reserved.
//

import Foundation
import CoreLocation
import CoreBluetooth


class BeaconDelegate: NSObject, CBPeripheralManagerDelegate {
    
    //MARK: - Callbacks
    
    var didUpdateStateCallback: ((CBPeripheralManager) -> ())? = nil
    
    //MARK: - Delegate Functions

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        didUpdateStateCallback?(peripheral)
    }
}
