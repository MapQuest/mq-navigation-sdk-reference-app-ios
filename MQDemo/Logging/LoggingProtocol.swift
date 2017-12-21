//
//  LoggingProtocol.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import Foundation
import MQNavigation

@objc enum SessionEndReason : Int {
    case reachedDestination = 0
    case userEnded
    case idleTooLong
    case interrupted
    case appKilled
    case errorPreviousSessionNotClosed
    case unknown = -1
    
    var description : String {
        switch self {
        case .reachedDestination:               return "Reached Destination"
        case .userEnded:                        return "User Ended"
        case .idleTooLong:                      return "Idle too Long"
        case .interrupted:                      return "Interrupted"
        case .appKilled:                        return "App Killed"
        case .errorPreviousSessionNotClosed:    return "Previous Session Not Closed"
        case .unknown:                          return "Unknown"
        }
    }
}

//MARK: -
@objc enum RerouteResult : Int {
    case accepted = 0
    case error
    case cancelled
    case noData
    case offRouteOffRoadNetwork
    case offRouteNearRoute
}

//MARK: -
@objc enum UpdatedRouteReason : Int {
    case firstRoute = 0
    case reroute
    case traffic
    
    var description : String {
        switch self {
        case .firstRoute:   return "First Route"
        case .reroute:      return "Reroute"
        case .traffic:      return "Traffic"
        }
    }
}

//MARK: -
@objc enum SessionNetworkStatus : Int {
    case connected = 0
    case noService
    case noServiceCall
    
    var description : String {
        switch self {
        case .connected:        return "Connected"
        case .noService:        return "No Service"
        case .noServiceCall:    return "No Service, in a call"
        }
    }
}

//MARK: -
@objcMembers
public class PromptPlayEntry : NSObject {
    var prompt: MQPrompt
    var routeLeg: MQRouteLeg
    init(prompt: MQPrompt, routeLeg: MQRouteLeg) {
        self.prompt = prompt
        self.routeLeg = routeLeg
        super.init()
    }
}

//MARK: -
protocol SessionLoggingProtocol {
    var hasActiveLoggingSession : Bool { get }
    var currentSessionId: String? { get }
    var userString: String? { get set }
    weak var navigationManager: MQNavigationManager? { get set }

    func start(route: MQRoute, completion: ((_ sessionID: String?)->Void)?)
    func end(reason: SessionEndReason, completion: ((_ promptPlayHistory: [PromptPlayEntry])->Void)?)

    func startReroute(location: CLLocation, requestedTime: Date, receivedTime: Date, geofenceRadius: NSNumber, rerouteDelay: NSNumber, receivedRoute: MQRoute?, result: RerouteResult)
    func startReroute(location: CLLocation, requestedTime: Date, receivedTime: Date, geofenceRadius: NSNumber, rerouteDelay: NSNumber, receivedRoute: MQRoute?, result: RerouteResult, resultDetails: String)
    
    func update(locationObservation: MQLocationObservation)
    func update(route: MQRoute, reason: UpdatedRouteReason)
    func update(networkStatus: SessionNetworkStatus)
    
    func recordPromptReceived(prompt: MQPrompt, routeLeg: MQRouteLeg) -> PromptPlayEntry?
    func recordPromptPlayed(entry: PromptPlayEntry, start: Date, end: Date, interrupted: Bool)
    
    func specialMenuAction(presenting viewController: UIViewController, view: UIView)
}
