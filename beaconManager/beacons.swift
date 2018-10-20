//
//  ViewController.swift
//  beacon-test
//
//  Created by Anmol Jain on 8/3/18.
//  Copyright © 2018 Sling. All rights reserved.
//

import UIKit
import CoreLocation
import CoreBluetooth
import Firebase
import CoreMotion
import AudioToolbox


let currentId = "1"
let otherId   = "2"
let minor: CLBeaconMinorValue = UInt16(currentId)!

let maxSameLevelCounter = 3

enum motionType: Int {
    case stationary = 0
    case walking    = 1
    case spinning   = 2
    case shaking    = 3
}

enum proximityLevel: Int {
    case unknown   = 0
    case far       = 1
    case near      = 2
    case immediate = 3
}

enum motionIntention: Int {
    case approaching = 0
    case away        = 1
    case none        = 2
}


class beacons: UIViewController {

    var ref: DatabaseReference!

    let locationDelegate = LocationDelegate()
    let locationManager: CLLocationManager = {
        $0.requestWhenInUseAuthorization()
        return $0
    }(CLLocationManager())

    let beaconDelegate = BeaconDelegate()
    let beaconManager: CBPeripheralManager = {
        return $0
    }(CBPeripheralManager())
    
    let motionManager: CMMotionManager = {
        if $0.isAccelerometerAvailable {
            $0.accelerometerUpdateInterval = 0.1
        }
        return $0
    }(CMMotionManager())
    

    //Self IBOutlets
    @IBOutlet weak var advertisingStatusLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var activityLabel: UILabel!
    @IBOutlet weak var directionLabel: UILabel!
    
    
    //Other IBOUtlets
    @IBOutlet weak var otherDistanceLabel: UILabel!
    @IBOutlet weak var otherDirectionLabel: UILabel!
    @IBOutlet weak var otherActivityLabel: UILabel!
    
    //distance
    var distance: Double?
    
    // Beacon variables
    var beaconRegion: CLBeaconRegion!
    var beaconsToRange: [CLBeaconRegion]!
    var lastFoundBeacon: CLBeacon?
    var lastProximity: CLProximity!
    var emitterBeaconID: String!
    var emitterProfile: String!
    
    // CoreMotion Variables
    var yMotionCounter: Int!
    var yMotionFlag: Bool!
    var xMotionCounter: Int!
    var xMotionFlag: Bool!
    var zMotionCounter: Int!
    var zMotionFlag: Bool!
    
    var currentMotion: motionType = {
        var motion = motionType.stationary
        return motion
    }()
    
    // BeaconMotion
    var currentRate: Double!
    var currentDistance: Double!
    
    var levelCounter: Int = {
        let counter: Int = 1
        return counter
    }()
    
    var sameLevelCounter: Int = {
        let counter: Int = 0
        return counter
    }()
    
    var currentLevel: proximityLevel = {
        var level = proximityLevel.unknown
        return level
    }()
    
    var currentIntention: motionIntention = {
        var intention = motionIntention.none
        return intention
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        ref = Database.database().reference()
        
        setupObserver()
        setupLocationDelegate()
        setupEmitterBeacon()
        setupReceiverBeacon()
        setupAccelerometer()
    }
    
    func startVibration() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    // MARK: - DELEGATES
    
    func setupLocationDelegate() {
        locationManager.delegate = locationDelegate
        
        locationDelegate.didEnterRegionCallback = { region in
            if region is CLBeaconRegion {
                print("didEnterRegion")
                self.startRangingForBeacons(beaconRegion: region as! CLBeaconRegion)
            }
        }
        
        locationDelegate.didRangeBeaconsCallback = { (beacons, region) in
            let foundBeacons = beacons.self
                if foundBeacons.count > 0 {
                    let closestBeacon = foundBeacons[0]
                    if closestBeacon != self.lastFoundBeacon || self.lastProximity != closestBeacon.proximity  {
                        self.lastFoundBeacon = closestBeacon
                        self.lastProximity = closestBeacon.proximity
                        var proximityMessage: String!
                        
                        var previousLevel = proximityLevel(rawValue: 0)
                        previousLevel = self.currentLevel
                        
                        switch closestBeacon.proximity {
                            
                        case CLProximity.immediate:
                            proximityMessage = "Immediate"
                            self.currentLevel = proximityLevel.immediate
                        case CLProximity.near:
                            proximityMessage = "Near"
                            self.currentLevel = proximityLevel.near
                        case CLProximity.far:
                            proximityMessage = "Far"
                            self.currentLevel = proximityLevel.far
                        default:
                            proximityMessage = "Where's the beacon?"
                            self.currentLevel = proximityLevel.unknown
                        }
                        
                        self.updateBeaconROC(withAccuracy: closestBeacon.accuracy)

                        self.ref.child(currentId).child("distance").setValue(proximityMessage)
                        self.distanceLabel.text = proximityMessage
                }
            }
        }
    }
    
    func updateBeaconROC(withAccuracy accuracy: CLLocationAccuracy) {
        self.currentRate = self.currentDistance - accuracy
        var motionTypeString = String()
        
        if (self.currentMotion == motionType.walking) {
            //            if (self.currentRate > 0.06  || self.currentRate < -0.06) {
            if (self.currentRate > 0) {
                motionTypeString = "approaching"
                self.currentIntention = motionIntention.approaching
            } else {
                self.currentIntention = motionIntention.away
                motionTypeString = "away"
            }
            //            }
        } else {
            self.currentIntention = motionIntention.none
            motionTypeString = "none"
        }
        
        ref.child(currentId).child("direction").setValue(motionTypeString)
        self.directionLabel.text = motionTypeString
    }
    
    func setupEmitterBeacon() {
        
        beaconDelegate.didUpdateStateCallback = { peripheral in
            switch peripheral.state {
            case .poweredOn:
                print("Bluetooth Status: Turned On")
                self.advertiseDevice()
            case .poweredOff:
                print("Bluetooth Status: Turned Off")
                self.stopAdvertisingDevice()
            case .unauthorized:
                print("Bluetooth Status: Not Authorized")
            case .unsupported:
                print("Bluetooth Status: Not Supported")
            default:
                print("Bluetooth Status: Unknown")
            }
        }
        beaconManager.delegate = beaconDelegate
        beaconRegion = createBeaconRegion()!
    }
    
    
    func setupAccelerometer() {
        
        yMotionCounter = 0
        yMotionFlag = false
        xMotionCounter = 0
        xMotionFlag = false
        zMotionCounter = 0
        zMotionFlag = false
        
        currentDistance = 0
        self.setupMotionManager()
    }
    
    private func setupMotionManager() {
        motionManager.startDeviceMotionUpdates(to: OperationQueue.main) { (motion, error) in
            if let error = error {
                print(error.localizedDescription)
            } else {
                self.handleMotion(xComponent: motion!.userAcceleration.x,
                                  yComponent: motion!.userAcceleration.y,
                                  zComponent: motion!.userAcceleration.z)
          }
        }   
    }
    
    func handleMotion(xComponent: Double, yComponent: Double, zComponent: Double){
        
        //DATA PROCESSING
        if(yComponent < 0.05) {
            if(yMotionFlag == false){
                yMotionCounter = yMotionCounter + 1
            } else {
                yMotionCounter = 1
            }
            yMotionFlag = false
        } else {
            
            if(yMotionFlag == true){
                yMotionCounter = yMotionCounter + 1
            } else {
                yMotionCounter = 1
            }
            yMotionFlag = true
        }
        
        if(xComponent < 0.05) {
            if(xMotionFlag == false){
                xMotionCounter = xMotionCounter + 1
            } else {
                xMotionCounter = 1
            }
            xMotionFlag = false
        } else {
            
            if(xMotionFlag == true){
                xMotionCounter = xMotionCounter + 1
            } else {
                xMotionCounter = 1
            }
            xMotionFlag = true
        }
        
        if(zComponent < 0.2) {
            if(zMotionFlag == false){
                zMotionCounter = zMotionCounter + 1
            } else {
                zMotionCounter = 1
            }
            zMotionFlag = false
        } else {
            
            if(zMotionFlag == true){
                zMotionCounter = zMotionCounter + 1
            } else {
                zMotionCounter = 1
            }
            zMotionFlag = true
        }
        
        //DATA RESULTS
        if( yMotionCounter > 58 && !yMotionFlag){
            
            ref.child(currentId).child("activity").setValue("STATIONARY")
            self.activityLabel.text = "STATIONARY"
            currentMotion = motionType.stationary
            
        }else if (xMotionFlag && xMotionCounter > 5){

            ref.child(currentId).child("activity").setValue("SPINNING")
            self.activityLabel.text = "SPINNING"
            currentMotion = motionType.walking
        }

        else if(zMotionFlag && zMotionCounter > 5){

            ref.child(currentId).child("activity").setValue("SHAKIN")
            self.activityLabel.text = "SHAKIN"
            currentMotion = motionType.walking
        }
        
        else if( yMotionFlag && yMotionCounter > 5){
            
            ref.child(currentId).child("activity").setValue("WALKING")
            self.activityLabel.text = "WALKING"
            currentMotion = motionType.walking
        }
    }
    
    func setupObserver() {
        ref.child(otherId).observe(.value) { (snapshot) in
            if let data = snapshot.value as? [String: String] {
                
                if let activity = data["activity"]{
                    self.otherActivityLabel.text = activity
                }
                
                if let direction = data["direction"] {
                    self.otherDirectionLabel.text = direction
                }
                
                if let distance = data["distance"] {
                    self.otherDistanceLabel.text = distance
                }
            }
        }
    }
    
    // MARK: - Emitter
    
    func createBeaconRegion() -> CLBeaconRegion? {
        let proximityUUID = UUID(uuidString: "5DF62D9D-3358-443E-BD4F-4AC4207ACC04")
        let major: CLBeaconMajorValue = 0
        let identifier = "sling"
        
        return CLBeaconRegion(proximityUUID: proximityUUID!, major: major, minor: minor, identifier: identifier)
    }
    
    func advertiseDevice() {
        let peripheralData = beaconRegion.peripheralData(withMeasuredPower: nil)
        beaconManager.startAdvertising(((peripheralData as NSDictionary) as! [String : Any]))
        advertisingStatusLabel.text = "Advertising"
        print("Advertising")
    }
    
    func stopAdvertisingDevice() {
        beaconManager.stopAdvertising()
        advertisingStatusLabel.text = "Not advertising"
        print("Not advertising")
    }
    
    // MARK: - Receiver
    func setupReceiverBeacon() {
        
        beaconsToRange = [CLBeaconRegion]()
        startMonitoringForBeacons()
    }
    
    // Specify what Beacons to monitor
    func startMonitoringForBeacons() {
        
        if CLLocationManager.isMonitoringAvailable(for: CLBeaconRegion.self) {
            
            // Match all beacons with the specified UUID
            let proximityUUID = UUID(uuidString:"5DF62D9D-3358-443E-BD4F-4AC4207ACC04")
            let identifier = "sling"
            
            // Create the region and begin monitoring it.
            let region = CLBeaconRegion(proximityUUID: proximityUUID!, identifier: identifier)
            
            //locationManager.startMonitoring(for: region)
            startRangingForBeacons(beaconRegion: region)
        } else {
            print("Unable to monitor")
        }
    }
    
    func startRangingForBeacons(beaconRegion: CLBeaconRegion){
        
        // Removed check for if the CLRegion is a CLBeaconRegion
        // Start ranging only if the feature is available.
        if CLLocationManager.isRangingAvailable() {
            locationManager.startRangingBeacons(in: beaconRegion)
            
            // Store the beacon so that ranging can be stopped on demand.
            beaconsToRange.append(beaconRegion)
        } else {
            print("Unable to range")
        }
    }
}
