//
//  Constants.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import Foundation

let kUserString = "kUserString"
let MPS_TO_MPH = 2.23694

struct TrafficColor {
    static let lightTraffic = UIColor(red: 0.16, green: 0.71, blue: 0.33, alpha: 1.0)
    static let mediumTraffic = UIColor(red: 0.96, green: 0.67, blue: 0.12, alpha: 1.0)
    static let heavyTraffic = UIColor(red: 0.96, green: 0.36, blue: 0.35, alpha: 1.0)
    
    static let stopAndGo = UIColor(red: 1.00, green: 0.33, blue: 0.33, alpha: 1.0)
    static let stopAndGoInActive = UIColor(red: 1.00, green: 0.4, blue: 0.4, alpha: 1.0)

    static let freeFlow = UIColor.green
    static let freeFlowInActive = UIColor(red: 0.40, green: 0.6, blue: 1, alpha: 1.0)

    static let slow = UIColor(red: 1.00, green: 0.93, blue: 0.27, alpha: 1.0)
    static let slowInActive = UIColor(red: 1, green: 1, blue: 0.60, alpha: 1.0)

    static let closed = UIColor.blue
    static let closedInActive = UIColor(red: 34.0/255.0, green: 34.0/255.0, blue: 17.0/255.0, alpha: 1.0)

    static let unknown = UIColor.black
    static let unknownInactive = UIColor(red: 102.0/255.0, green: 153.0/255.0, blue: 1, alpha: 1.0)
}

struct RouteColors {
    static let theDefault = UIColor(red: 0.0, green: 141.0/255.0, blue: 189.0/255.0, alpha: 1.0)
    static let casingColor = UIColor(red: 0.0, green: 0.0, blue: 102.0/255.0, alpha: 1.0)
    static let fillingColor = UIColor(red: 0.0, green: 141.0/255.0, blue: 189.0/255.0, alpha: 1.0)
}

