//
//  SwitchTableViewCell.swift
//  MQDemo
//
//  Copyright © 2018 Mapquest. All rights reserved.
//

import UIKit

/// A table view cell with label and switch control

class SwitchTableViewCell: UITableViewCell {

    /// Label to be shown on the cell
    @IBOutlet var label: UILabel!
    
    /// Initial/current value of the switch control
    @IBOutlet var onOff: UISwitch!
    
    /// Closure to be called when user changes the switch control value
    var valueChangedBlock: ((Bool) -> Void)?
    
    @IBAction func onOffValueChanged(_ sender: UISwitch) {
        valueChangedBlock?(sender.isOn)
    }
}
