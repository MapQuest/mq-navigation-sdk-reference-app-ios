//
//  LoggingManager.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import Foundation

class LoggingManager: NSObject, SessionLoggingProtocol {
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
    override init() {
        super.init()
        if let userID = UserDefaults.standard.string(forKey: kUserString) {
            userString = userID
        }
    }
    
    func requestRoutes() {
        print("Logger: Requesting Routes")
    }
    
    /// Record the start of a route
    /// The completion block provides the session ID
    func start(route: MQRoute, completion: ((String?) -> Void)?) {
        guard LoggingManager.shared.shouldLog else { return }
        
        print("Logger: Starting Route: \(route.name)")
        prompts.removeAll()
        currentSessionId = UUID().uuidString
        completion?(currentSessionId)
    }
    
    /// Record the ending of a session
    /// At the end of a session, we provide you all of the prompts that were received
    func end(reason: SessionEndReason, completion: (([PromptPlayEntry]) -> Void)?) {
        guard LoggingManager.shared.hasActiveLoggingSession else { return }
        
        print("Logger: Ending Route for reason: \(reason.description)")

        currentSessionId = nil
        completion?(prompts)
    }
    
    /// Record the reroute event with a result
    func startReroute(location: CLLocation, requestedTime: Date, receivedTime: Date, geofenceRadius: NSNumber, rerouteDelay: NSNumber, receivedRoute: MQRoute?, result: RerouteResult) {
        
        guard LoggingManager.shared.hasActiveLoggingSession else { return }
        print("Logger: Starting Reroute")
    }
    
    /// Record the reroute event with extra details
    func startReroute(location: CLLocation, requestedTime: Date, receivedTime: Date, geofenceRadius: NSNumber, rerouteDelay: NSNumber, receivedRoute: MQRoute?, result: RerouteResult, resultDetails: String) {
        
        guard LoggingManager.shared.hasActiveLoggingSession else { return }
        print("Logger: Starting Reroute")
    }
    
    /// Record the location received from the Navigation Manager - it includes a raw GPS location and a location snapped to the route
    func update(locationObservation: MQLocationObservation) {
        guard LoggingManager.shared.hasActiveLoggingSession else { return }
        print("Logger: Updating Location: Raw: \(locationObservation.rawGPSLocation), Snapped: \(locationObservation.snappedLocation)")
    }
    
    /// Record the latest Route update and why
    func update(route: MQRoute, reason: UpdatedRouteReason) {
        guard LoggingManager.shared.hasActiveLoggingSession else { return }
        print("Logger: Update Route: \(route.name) for reason: \(reason.description)")
    }
    
    /// Record the latest network status, including in-call status
    func update(networkStatus: SessionNetworkStatus) {
        guard LoggingManager.shared.hasActiveLoggingSession else { return }
        print("Logger: Updating Network Status: \(networkStatus.description)")
    }
    
    /// Recording a received Prompt to display/speak to the user
    func recordPromptReceived(prompt: MQPrompt, routeLeg: MQRouteLeg) -> PromptPlayEntry? {
        guard LoggingManager.shared.hasActiveLoggingSession else { return nil }
        print("Logger: Prompt Received: \(prompt.text) for route Leg: \(routeLeg.routeLegId)")
        let entry = PromptPlayEntry(prompt: prompt, routeLeg: routeLeg)
        prompts.append(entry)
        return entry
    }
    
    /// Recording the prompt being played to the user
    func recordPromptPlayed(entry: PromptPlayEntry, start: Date, end: Date, interrupted: Bool) {
        guard LoggingManager.shared.hasActiveLoggingSession else { return }
        print("Logger: Prompt Played: \(entry.prompt.text) for route: \(entry.routeLeg) received: \(start), played: \(end), interrupted: \(interrupted ? "Yes":"No")")
    }
    
    /// Use this as a debug action or special menu for turning logging on/off
    func specialMenuAction(presenting viewController: UIViewController, view: UIView) {
    }
    
    /// User tapped cancel navigation after getting a route
    func navigationCanceled() {
    }
    
    func navigationManagerDidStartNavigation(_ navigationManager: MQNavigationManager) {
    }
    
    func navigationManager(_ navigationManager: MQNavigationManager, failedToStartNavigationWithError error: Error) {
    }
    
    func navigationManager(_ navigationManager: MQNavigationManager, stoppedNavigation navigationStoppedReason: MQNavigationStoppedReason) {
    }
    
    func navigationManagerDidPauseNavigation(_ navigationManager: MQNavigationManager) {
    }
    
    func navigationManagerDidResumeNavigation(_ navigationManager: MQNavigationManager) {
    }
    
    func navigationManager(_ navigationManager: MQNavigationManager, didUpdateUpcomingManeuver upcomingManeuver: MQManeuver) {
    }
    
    func navigationManager(_ navigationManager: MQNavigationManager, reachedDestination routeDestination: MQRouteDestination, for completedRouteLeg: MQRouteLeg, isFinalDestination: Bool, confirmArrival: @escaping MQConfirmArrivalBlock) {
    }
    
    func navigationManagerWillUpdateETA(_ navigationManager: MQNavigationManager) {
    }
    
    func navigationManagerDidUpdateETA(_ navigationManager: MQNavigationManager, withETAByRouteLegId etaByRouteLegId: [String : MQEstimatedTimeOfArrival]) {
    }
    
    func navigationManagerWillUpdateTraffic(_ navigationManager: MQNavigationManager) {
    }
    
    func navigationManagerDidUpdateTraffic(_ navigationManager: MQNavigationManager, withTrafficByRouteLegId trafficByRouteLegId: [String : MQTraffic]) {
    }
    
    func navigationManager(_ navigationManager: MQNavigationManager, foundTrafficReroute route: MQRoute) {
    }
    
    func navigationManagerShouldReroute(_ navigationManager: MQNavigationManager) -> Bool {
        return true
    }
    
    func navigationManager(_ navigationManager: MQNavigationManager, didReroute route: MQRoute) {
    }
    
    func navigationManagerDiscardedReroute(_ navigationManager: MQNavigationManager) {
    }
    
    func navigationManager(_ navigationManager: MQNavigationManager, crossedSpeedLimitBoundariesWithExitedZones exitedSpeedLimits: Set<MQSpeedLimit>?, enteredZones enteredSpeedLimits: Set<MQSpeedLimit>?) {
    }
    
    func navigationManagerBackgroundTimerExpired(_ navigationManager: MQNavigationManager) {
    }
    
    /// User confirmed arrival to intermidiate or final destination
    ///
    /// - Parameter didArrive: Boolean value indicating if user accepted or declined arrival
    func userConfirmedArrival(didArrive: Bool) {
    }
}

