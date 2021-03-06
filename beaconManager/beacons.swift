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


let currentId = "2"
let otherId   = "1"
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
            $0.accelerometerUpdateInterval = 0.01
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
    
    //Testing IBOutlets
    @IBOutlet weak var experimentButton: UIButton!
    
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
    var yMotionCounter: Double!
    var yMotionFlag: Bool!
    var xMotionCounter: Double!
    var xMotionFlag: Bool!
    var zMotionCounter: Double!
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
    
    var startExperiment: Bool = {
        var flag = false
        return flag
    }()
    
    // Firebase Testing
    var xArray: [Double] = {
        var array = [Double]()
        return array
    }()
    
    var yArray: [Double] = {
        var array = [Double]()
        return array
    }()
    
    var zArray: [Double] = {
        var array = [Double]()
        return array
    }()
    
    var walkingArray: [Bool] = {
        var array = [Bool]()
        return array
    }()
    
    var spinningArray: [Bool] = {
        var array = [Bool]()
        return array
    }()
    
    var shakingArray: [Bool] = {
        var array = [Bool]()
        return array
    }()
    
    var stationaryArray: [Bool] = {
        var array = [Bool]()
        return array
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
        
        yMotionCounter = 0.0
        yMotionFlag = false
        xMotionCounter = 0.0
        xMotionFlag = false
        zMotionCounter = 0.0
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

        
        // 0.05 is the senitivity
        if(yComponent < ySen) {
            if(yMotionFlag == false){
                yMotionCounter = yMotionCounter + 1
            } else {
                yMotionCounter = 1.0
            }
            yMotionFlag = false
        } else {
            
            if(yMotionFlag == true){
                yMotionCounter = yMotionCounter + 1
            } else {
                yMotionCounter = 1.0
            }
            yMotionFlag = true
        }
        
        if(xComponent < xSen) {
            if(xMotionFlag == false){
                xMotionCounter = xMotionCounter + 1
            } else {
                xMotionCounter = 1.0
            }
            xMotionFlag = false
        } else {
            
            if(xMotionFlag == true){
                xMotionCounter = xMotionCounter + 1
            } else {
                xMotionCounter = 1.0
            }
            xMotionFlag = true
        }
        
        if(zComponent < zSen) {
            if(zMotionFlag == false){
                zMotionCounter = zMotionCounter + 1
            } else {
                zMotionCounter = 1.0
            }
            zMotionFlag = false
        } else {
            
            if(zMotionFlag == true){
                zMotionCounter = zMotionCounter + 1
            } else {
                zMotionCounter = 1.0
            }
            zMotionFlag = true
        }
        
        
        //DATA RESULTS
        if( yMotionCounter > stationarySen && !yMotionFlag){
            
            ref.child(currentId).child("activity").setValue("STATIONARY")
            self.activityLabel.text = "STATIONARY"
            currentMotion = motionType.stationary
            
        }else if (xMotionFlag && xMotionCounter > spinningSen){
            
            ref.child(currentId).child("activity").setValue("SPINNING")
            self.activityLabel.text = "SPINNING"
            currentMotion = motionType.spinning
        }

        else if(zMotionFlag && zMotionCounter > shakingSen){

            ref.child(currentId).child("activity").setValue("SHAKIN")
            self.activityLabel.text = "SHAKIN"
            currentMotion = motionType.shaking
        }
        
        else if( yMotionFlag && yMotionCounter > walkingSen){
            
            ref.child(currentId).child("activity").setValue("WALKING")
            self.activityLabel.text = "WALKING"
            currentMotion = motionType.walking

        }
        
        if(startExperiment) {
            
            self.experimentButton.setTitle("Stop", for: .normal)
            
            xArray.append(xComponent)
            yArray.append(yComponent)
            zArray.append(zComponent)
            
            ref.child(currentId).child("xMotion").setValue(xArray)
            ref.child(currentId).child("yMotion").setValue(yArray)
            ref.child(currentId).child("zMotion").setValue(zArray)
            
            if(self.currentMotion == motionType.stationary) {
                walkingArray.append(false)
                spinningArray.append(false)
                shakingArray.append(false)
                stationaryArray.append(true)

            } else {
                  stationaryArray.append(false)
                if(self.currentMotion == motionType.walking) {
                    walkingArray.append(true)
                    spinningArray.append(false)
                    shakingArray.append(false)
                    
                } else if (self.currentMotion == motionType.shaking){
                    shakingArray.append(true)
                    walkingArray.append(false)
                    spinningArray.append(false)
                } else if (self.currentMotion == motionType.spinning){
                    spinningArray.append(true)
                    shakingArray.append(false)
                    walkingArray.append(false)
                }
            }
             ref.child(currentId).child("walking").setValue(walkingArray)
             ref.child(currentId).child("shaking").setValue(shakingArray)
             ref.child(currentId).child("spinning").setValue(spinningArray)
            ref.child(currentId).child("stationary").setValue(spinningArray)
            
        } else {
            
            self.experimentButton.setTitle("Start", for: .normal)
            xArray = []
            yArray = []
            zArray = []
            walkingArray = []
            spinningArray = []
            shakingArray = []
            stationaryArray = []
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
    

    @IBAction func startButtonTapped(_ sender: Any) {
        self.startExperiment = !self.startExperiment
    }
    
    @IBAction func resetButtonTapped(_ sender: Any) {
        ref.child(currentId).child("xMotion").setValue("")
        ref.child(currentId).child("yMotion").setValue("")
        ref.child(currentId).child("zMotion").setValue("")
        ref.child(currentId).child("walking").setValue("")
        ref.child(currentId).child("spinning").setValue("")
        ref.child(currentId).child("shaking").setValue("")
        ref.child(currentId).child("stationary").setValue("")
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
