//
//  sensitivity variables.swift
//  beaconManager
//
//  Created by Anmol Jain on 10/20/18.
//  Copyright © 2018 Danny Daniil. All rights reserved.
//

import Foundation
import UIKit

var xSen = 0.05
var ySen = 0.05
var zSen = 0.2
var stationarySen = 58.0
var walkingSen = 5.0
var spinningSen = 5.0
var shakingSen = 5.0


extension String {
    func toDouble() -> Double? {
        return NumberFormatter().number(from: self)?.doubleValue
    }
}

extension UIViewController {
    
    func hideKeyboardWhenTappedAround() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    func hideKeyboardWhenSwipeDown() {
        let swipe: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        swipe.cancelsTouchesInView = false
        swipe.direction = .down
        view.addGestureRecognizer(swipe)
    }
    
    @objc func dismissKeyboard() {
        UIView.animate(withDuration: 0.1) {
            self.view.endEditing(true)
        }
    }
}
