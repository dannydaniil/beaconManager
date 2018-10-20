//
//  settings.swift
//  beaconManager
//
//  Created by Anmol Jain on 10/20/18.
//  Copyright © 2018 Danny Daniil. All rights reserved.
//

import UIKit

class settings: UITableViewController, UITextFieldDelegate {

    @IBOutlet weak var xSensitivity: UITextField!
    @IBOutlet weak var ySensitivity: UITextField!
    @IBOutlet weak var zSensitivity: UITextField!
    @IBOutlet weak var stationarySensitivity: UITextField!
    @IBOutlet weak var walkingSensitivity: UITextField!
    @IBOutlet weak var spinningSensitivity: UITextField!
    @IBOutlet weak var shakingSensitivity: UITextField!
    @IBOutlet weak var restoreDefaults: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hideKeyboardWhenSwipeDown()
        hideKeyboardWhenTappedAround()
        
        xSensitivity.delegate = self
        ySensitivity.delegate = self
        zSensitivity.delegate = self
        stationarySensitivity.delegate = self
        walkingSensitivity.delegate = self
        spinningSensitivity.delegate = self
        shakingSensitivity.delegate = self
        
        xSensitivity.text = String(xSen)
        ySensitivity.text = String(ySen)
        zSensitivity.text = String(zSen)
        stationarySensitivity.text = String(stationarySen)
        walkingSensitivity.text = String(walkingSen)
        spinningSensitivity.text = String(spinningSen)
        shakingSensitivity.text = String(shakingSen)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        let val = textField.text?.toDouble()
        if textField == xSensitivity {
            xSen = val!
        } else if textField == ySensitivity {
            ySen = val!
        } else if textField == zSensitivity {
            zSen = val!
        } else if textField == stationarySensitivity {
            stationarySen = val!
        } else if textField == walkingSensitivity {
            walkingSen = val!
        } else if textField == spinningSensitivity {
            spinningSen = val!
        } else if textField == shakingSensitivity {
            shakingSen = val!
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        dismissKeyboard()
        return true
    }

    @IBAction func restoreButtonPressed(_ sender: Any) {
        xSen = 0.05
        ySen = 0.05
        zSen = 0.2
        stationarySen = 58.0
        walkingSen = 5.0
        spinningSen = 5.0
        shakingSen = 5.0
    }
}
