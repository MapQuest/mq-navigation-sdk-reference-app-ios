//
//  LoggingManager.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import Foundation

class LoggingManager : SessionLoggingProtocol {
    //MARK: Public Properties
    static let shared = LoggingManager()
    weak var navigationManager: MQNavigationManager?

    /// Deteremines if logging should be active or not
    /// For example you could have a UI switch for turning logging on or off
    var shouldLog : Bool = true
 
    /// Used to determine if the logging session active
    var hasActiveLoggingSession : Bool {
        return shouldLog && currentSessionId?.isEmpty == false && userString?.isEmpty == false
    }
    
    /// This is required for Logging
    var userString: String? {
        didSet {
            UserDefaults.standard.set(userString, forKey: kUserString)
        }
    }

    /// The session ID for this logging session
    /// Generally stored by the Logging Manager and not used by the client
    var currentSessionId: String?
    
    //MARK: Private Properties
    fileprivate var prompts = [PromptPlayEntry]()
    
     //MARK: - Public Methods
    init() {
        if let userID = UserDefaults.standard.string(forKey: kUserString) {
            userString = userID
        }
    }
    
    /// Record the start of a route
    /// The completion block provides the session ID
    func start(route: MQRoute, completion: ((String?) -> Void)?) {
        
        print("Logger: Starting Route: \(route.name)")
        prompts.removeAll()
        currentSessionId = UUID().uuidString
        completion?(currentSessionId)
    }
    
    /// Record the ending of a session
    /// At the end of a session, we provide you all of the prompts that were received
    func end(reason: SessionEndReason, completion: (([PromptPlayEntry]) -> Void)?) {
        print("Logger: Ending Route for reason: \(reason.description)")

        currentSessionId = nil
        completion?(prompts)
    }
    
    /// Record the reroute event with a result
    func startReroute(location: CLLocation, requestedTime: Date, receivedTime: Date, geofenceRadius: NSNumber, rerouteDelay: NSNumber, receivedRoute: MQRoute?, result: RerouteResult) {
        
        print("Logger: Starting Reroute")
    }
    
    /// Record the reroute event with extra details
    func startReroute(location: CLLocation, requestedTime: Date, receivedTime: Date, geofenceRadius: NSNumber, rerouteDelay: NSNumber, receivedRoute: MQRoute?, result: RerouteResult, resultDetails: String) {
        
        print("Logger: Starting Reroute")
    }
    
    /// Record the location received from the Navigation Manager - it includes a raw GPS location and a location snapped to the route
    func update(locationObservation: MQLocationObservation) {
        print("Logger: Updating Location: Raw: \(locationObservation.rawGPSLocation), Snapped: \(locationObservation.snappedLocation)")
    }
    
    /// Record the latest Route update and why
    func update(route: MQRoute, reason: UpdatedRouteReason) {
        print("Logger: Update Route: \(route.name) for reason: \(reason.description)")
    }
    
    /// Record the latest network status, including in-call status
    func update(networkStatus: SessionNetworkStatus) {
        print("Logger: Updating Network Status: \(networkStatus.description)")
    }
    
    /// Recording a received Prompt to display/speak to the user
    func recordPromptReceived(prompt: MQPrompt, routeLeg: MQRouteLeg) -> PromptPlayEntry? {
        print("Logger: Prompt Received: \(prompt.text) for route Leg: \(routeLeg.routeLegId)")
        let entry = PromptPlayEntry(prompt: prompt, routeLeg: routeLeg)
        prompts.append(entry)
        return entry
    }
    
    /// Recording the prompt being played to the user
    func recordPromptPlayed(entry: PromptPlayEntry, start: Date, end: Date, interrupted: Bool) {
        print("Logger: Prompt Played: \(entry.prompt.text) for route: \(entry.routeLeg) received: \(start), played: \(end), interrupted: \(interrupted ? "Yes":"No")")
    }
    
    /// Use this as a debug action or special menu for turning logging on/off
    func specialMenuAction(presenting viewController: UIViewController, view: UIView) {
        
    }
}

