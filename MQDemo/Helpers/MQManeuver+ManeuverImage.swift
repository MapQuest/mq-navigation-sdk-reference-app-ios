//
//  MQManeuver+ManeuverImage.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

extension MQManeuver {
    
    //MARK: - Public Methods
    class func image(maneuverType: MQManeuverType) -> UIImage? {
        guard let imageName = imageName(maneuverType: maneuverType) else { return nil }
        return UIImage(named: imageName)
    }
    
    class func hasImage(maneuverType: MQManeuverType) -> Bool {
        return (imageName(maneuverType: maneuverType) != nil)
    }
    
    //MARK: - Private Methods
    private class func imageName(maneuverType: MQManeuverType) -> String? {
        switch (maneuverType) {
        case .noDirectionIndicated: return nil
        case .straight: return "navatar_straight"
        case .slightRight: return "navatar_slight_right"
        case .right: return "navatar_right"
        case .sharpRight: return "navatar_sharp_right"
        case .sharpLeft: return "navatar_sharp_left"
        case .left: return "navatar_left"
        case .slightLeft: return "navatar_slight_left"
        case .leftUturn: return "navatar_uturn_left"
        case .rightUturn: return "navatar_uturn_right"
        case .rightMerge: return "navatar_merge_right"
        case .leftMerge: return "navatar_merge_left"
        case .merge: return "navatar_merge"
        case .rightOnRamp: return "navatar_merge_right"
        case .leftOnRamp: return "navatar_merge_left"
        case .rightOffRamp: return "navatar_fork_right"
        case .leftOffRamp: return "navatar_fork_left"
        case .rightFork: return "navatar_fork_right"
        case .leftFork: return "navatar_fork_left"
        case .straightFork: return "navatar_straight"
        case .destination: return "navatar_destination"
        case .enterRoundabout: return "navatar_roundabout"
        case .exitRoundabout: return "navatar_roundabout"
        case .start: return "navatar_location"
        }
    }
}
