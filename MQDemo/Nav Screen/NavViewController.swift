//
//  NavViewController.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import UIKit
import Mapbox
import MQCore
import MQNavigation
import SVProgressHUD
import AVFoundation
import UserNotifications

@objc enum NavUserFollowMode: Int {
    case notFollowing // Map is not moving the camera to follow the user in 3D
    case following // Map IS moving the camera
}

protocol NavViewControllerDelegate {
    
    /// Notification for navigation starting, useful to setup the UI for navigation
    func navigationStarting()
    
    /// Notification for navigation stopping, useful to clear the UI and offer new destination options
    func navigationStopped()
    
    /// Notification for reaching a destination
    func reachedDestination(_ destination:Destination,  nextDestination: Destination?, confirmArrival: @escaping MQConfirmArrivalBlock)
    
    /// Provide the upcoming maneuver distance
    func update(maneuverBarDistance: CLLocationDistance)
    
    /// Provide the upcoming maneuver text, type and typeText
    func update(maneuverBarText: String, turnType: MQManeuverType, maneuverTypeText: String)
    
    /// Provide updates to the ETA
    func update(currentLegETA: TimeInterval, finalETA: TimeInterval, distanceRemaining: CLLocationDistance, trafficOverview: MQTrafficOverview)
    
    /// Provide warnings
    func update(warnings: [String]?)
    
    /// Update the lane guidance if we have it
    func update(laneGuidance: [MQLaneInfo]?)
    
    /// negative indicates unknown speed limit.
    func update(speedLimit: CLLocationSpeed)
    
    /// Notification for the routes that have been retrieved
    func update(routes: [MQRoute])
    
    /// The map follow mode has changed. For example if the map is currently following the user as they are navigation vs if the user has zoomed out or panned away
    func userFollowMode(didChangeTo followMode: NavUserFollowMode)
    
    /// A pin was dropped on the map
    func pinDroppedOnMap(atLocation location: CLLocationCoordinate2D)
    
    /// Visible area for zooming
    var visibleEdgeInsets : UIEdgeInsets { get }
}

//MARK: -
class NavViewController: UIViewController, UIGestureRecognizerDelegate {
    
    //MARK: Public Properties
    var delegate: NavViewControllerDelegate?
    
    /// The route that is being highlighted and will be used for navigation if the user starts navigation
    var selectedRoute: MQRoute?
    
    /// All of the routes received from the routes service. Contains both the selected and alternate routes
    var availableRoutes: [MQRoute]?
    
    /// Property that provides the navigation controller with the current leg of a route
    var currentRouteLeg: MQRouteLeg? { return navigator.currentRouteLeg }
    
    /// Property that returns if the current leg is the final leg
    var isLegFinalDestination : Bool? {
        guard let leg = currentRouteLeg, let route = selectedRoute else { return nil }
        return route.legs.index(of: leg) == route.legs.count-1
    }
    
    var currentDestination : Destination? {
        guard destinations.count > 0, let routeLeg = currentRouteLeg, let indexOfRouteLeg = selectedRoute?.legs.index(of: routeLeg) else { return nil }
        return destinations[indexOfRouteLeg]
    }
    
    /// An array of destinations by title, coordinate, and if they have been reached or not
    var destinations = [Destination]()
    
    /// Trip options that you can expose to the user
    /// Used to affect the requestRoutes method and reroute requests
    var tripOptions: MQRouteOptions = {
        MQRouteOptions().build {
            $0.maxRoutes = 3
            $0.tolls = .avoid
            $0.ferries = .avoid
            $0.internationalBorders = .avoid
            $0.unpaved = .allow
            $0.seasonalClosures = .avoid
            $0.systemOfMeasurementForDisplayText = .unitedStatesCustomary
            $0.language = "en_US"
        }
    }()
    
    /// Current Location from the location Manager
    var currentLocation: CLLocation? {
        
        // Location Manager sometimes will not give us a location if we've stopped updating location, so here we start updating
        // location - get the current location - and then quit
        if hasInitialLocation {
            locationManager.startUpdatingLocation()
            defer { locationManager.stopUpdatingLocation() }
        }
        
        guard let location = locationManager.location else {
            return nil
        }
        return location
    }
    
    /// The current Navigation View State
    var state:MQNavigationManagerState {
        return navigator.navigationManagerState;
    }
    
    /// Set Navigation Sharing Consent
    var userLocationTrackingConsentStatus : MQUserLocationTrackingConsentStatus {
        set {
            MQDemoOptions.shared.userLocationTrackingConsentStatus = newValue
            self.navigator.userLocationTrackingConsentStatus = newValue
        }
    
        get {
            return MQDemoOptions.shared.userLocationTrackingConsentStatus
        }
    }
    
    //MARK: Interface Builder Outlets
    @IBOutlet weak var mapView: MQMapView! {
        didSet {
            mapView.maximumZoomLevel = 18
            mapView.showsUserLocation = true
            mapView.userTrackingMode = .follow
            
            //we are hiding the attribution on the map itself because we are exposing it via the floating buttons (the i button)
            mapView.attributionButton.isHidden = true
        }
    }
    
    //MARK: Private Properties
    
    /// Snapback timer is used to snap the user back to the route if they change the map via panning/zooming
    private let snapBackTimeout: TimeInterval = 8.0
    private var snapBackTimer: Timer?
    
    /// First good location after the app starts has been received and we've centered the map on this location
    private var hasInitialLocation = false
    
    /// MQNavigationManager is the framework to talk to the Mapquest Navigation
    private lazy var navigator: MQNavigationManager! = {
        let navigator = MQNavigationManager(delegate: self, promptDelegate: self)
        navigator?.userLocationTrackingConsentStatus = self.userLocationTrackingConsentStatus
        
        LoggingManager.shared.navigationManager = navigator
        return navigator
    }()
    
    private lazy var audioManager = AudioManager()
    private lazy var routeService = MQRouteService()
    
    /// Create route overlays
    private lazy var routeOverlayFactory = RouteOverlayFactory()
    
    // Storage for the overlays/annotations to make it easier to remove them as needed
    private lazy var routeNameAnnotations = [RouteNameAnnotation]()
    private lazy var destinationAnnotations = [Destination]()
    private lazy var routeHighlightOverlays = [RouteHighlightPolyline]()
    
    // The last location observation is stored to compare against new observations
    private var lastLocationObservation: MQLocationObservation?
    private var hasGPSLock = false
    
    /// The last completed leg so we can know to stop drawing other legs
    private var lastCompletedRouteLeg: MQRouteLeg?
    
    // We use this to center the user on the map once we get a good location
    // and to request user's permission to use location services
    lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        return manager
    }()
    
    private var previousUserTrackingMode: MGLUserTrackingMode?
    private var lastETASpoken: TimeInterval?
    
    // Debug/logging properties
    var numRerouteCounterDebug = 0
    var rerouteRequestLocation: CLLocation?
    var rerouteRequestDate: Date?
    var trafficRequestLocation: CLLocation?
    var trafficRequestDate: Date?
    
    //MARK: - Public Methods
    
    /// Start the navigation with the selected route
    func startNavigation(withRoute route: MQRoute) {
        updateSelectedRoute(withRoute: route)
        startNav(trafficReroute: false)
    }
    
    /// Clear the navigation UI if the Destination Controller gets cleared
    func clearNavigation() {
        clearNavigationUI()
    }
    
    /// Start navigation with the selected route
    func startNav(trafficReroute: Bool) {
        guard let route = selectedRoute, let currentLocation = currentLocation, route.destinations.count > 0 else { return }
        
        // If this is a traffic reroute, simply start a new navigation with this route
        if trafficReroute {
            navigator.startNavigation(with: route)
            return
        }
        
        // Regular route (not a reroute)
        let camera = MGLMapCamera(lookingAtCenter: currentLocation.coordinate, fromDistance: 250.0, pitch: 45.0, heading: currentLocation.course)
        mapView.fly(to: camera) {
            self.mapView.setUserLocationVerticalAlignment(.bottom, animated: false)
            self.mapView.setUserTrackingMode(.followWithCourse, animated: true)
        }
        
        delegate?.navigationStarting()
        
        if MQDemoOptions.shared.promptsAudio != .none {
            audioManager.active = true
        }
        UIApplication.shared.isIdleTimerDisabled = true
        navigator.startNavigation(with: route)
    }
    
    /// Stop navigation
    func stopNav() {
        navigator.cancelNavigation()
    }
    
    /// Pause navigation
    func pauseNavigation() {
        navigator.pauseNavigation()
    }
    
    /// Resume navigation
    func resumeNavigation() {
        navigator.resumeNavigation()
    }
    
    /// Advance to the next leg of a multi-leg route
    func advanceRouteToNextLeg() {
        guard let reachedDestination = currentDestination, let reachedLeg = currentRouteLeg, navigator.advanceRouteToNextLeg() else { return }

        updateDestination(reachedDestination: reachedDestination, forCompletedRouteLeg: reachedLeg, isFinalDestination: false, requestUserAcceptance: false, confirmArrival: {_ in })
    }
    
    /// This method resumes following the user's location after a user pans or zooms the map
    func resumeUserFollowMode() {
        snapBackTimer?.invalidate()
        snapBackTimer = nil
        
        if mapView.userTrackingMode != .followWithCourse {
            mapView.userTrackingMode = .followWithCourse
            delegate?.userFollowMode(didChangeTo: .following)
        }
    }
    
    /// Centers the user's current location on the map
    func centerMapOnUser() {
        guard let currentLocation = currentLocation, currentLocation.horizontalAccuracy < 1024, currentLocation.timestamp.timeIntervalSinceNow > -180 else { return }
        mapView.setCenter(currentLocation.coordinate, zoomLevel: 12, animated: false)
    }
    
    /// Updates the Root View Controller with the latest ETA information
    func updateETA() {
        guard let currentLegETA = currentRouteLeg?.traffic.estimatedTimeOfArrival.time?.timeIntervalSinceNow,
            let finalLegETA = navigator.route?.legs.last?.traffic.estimatedTimeOfArrival.time?.timeIntervalSinceNow,
            currentLegETA.isEqual(to: -Double.greatestFiniteMagnitude) == false,
            let lastLocationObservation = lastLocationObservation,
            let selectedRoute = selectedRoute else { return }
        
        delegate?.update(currentLegETA: currentLegETA,
                         finalETA: finalLegETA,
                         distanceRemaining: lastLocationObservation.remainingLegDistance,
                         trafficOverview: selectedRoute.trafficOverview)
        
    }
    
    //MARK: Internal Controller
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        // We ask for the current location of the user and once we get a good enough one, we center the map
        locationManager.requestWhenInUseAuthorization()
        
        centerMapOnUser()
        
        // Drop a pin
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(dropPin(_:)))
        mapView.addGestureRecognizer(gesture)
    }
    
    /// Seutp the notification system so that we can alert the user if the background timer has expired
    func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            guard granted else { return }
            
            let continueAction = UNNotificationAction(identifier: "Continue",
                                                      title: "Continue", options: [])
            let exitAction = UNNotificationAction(identifier: "Exit",
                                                  title: "Exit Navigation", options: [.destructive])
            
            let category = UNNotificationCategory(identifier: "BackgroundTimer",
                                                  actions: [continueAction,exitAction],
                                                  intentIdentifiers: [], options: [])
            center.setNotificationCategories([category])
            
        }
    }
    
    /// Allow a user to drop a pin to select a destination
    @objc func dropPin(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, navigator.navigationManagerState == .stopped else { return }
        
        let point = gesture.location(in: mapView)
        let destinationCoordinate = mapView.convert(point, toCoordinateFrom: mapView)
        delegate?.pinDroppedOnMap(atLocation: destinationCoordinate)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Once navigation has started, the user may be opening other views (like instructions) and
        // we don't want to center map on the user again
        guard navigator.navigationManagerState == .stopped, mapView.userTrackingMode == .none else { return }
        
        centerMapOnUser()
        
        // If the user does not have location services enabled, open Settings app
        // to allow the user to enable location services
        if CLLocationManager.locationServicesEnabled() == false {
            
            let gotoSettings = UIAlertAction(title: "Goto Settings", style: .default, handler: { _ in
                guard let settingsUrl = URL(string: UIApplicationOpenSettingsURLString) else {
                    return
                }
                
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl, completionHandler: { success in
                        print("Settings opened: \(success)") // Prints true
                    })
                }
            })
            
            let alert = UIAlertController(title: "Location Services",
                                          message: "MapQuest Navigation requires location services to be turned on.",
                                          preferredStyle: .alert,
                                          actions: [gotoSettings, UIAlertController.cancelActionNil])
            present(alert, animated: true, completion: nil)
        }
    }
    
    /*
     This code is not used in the MQDemo app. However it is here to give you an example of how to handle taps on the screen and finding the closest route.
     It uses a gesture recognizer for the tap, and then loops through the routes and the legs of each route. It then converts the tap point into a map coordinate and then uses closestPositionOnRoute to find which route is the nearest to that point.
     
 */
//    @objc fileprivate func selectRouteGesture(gesture: UITapGestureRecognizer) {
//        guard let routes = alternateRoutes, routes.count >= 1 && navigator.isStopped else { return }
    //
//        let gestureLocation = gesture.location(in: mapView)
//        var shortestDistance = CGFloat.greatestFiniteMagnitude
//        var nearestRoute: MQRoute?
    //
//        //find nearest route
//        for route in routes {
//            for leg in route.legs {
//                //get coordinate on the map using the CGPoint in mapView
//                let coordinate = mapView.convert(gestureLocation, toCoordinateFrom: mapView)
//                //get the coordinate on the route that is closest to the coordinate where user tapped
//                leg.shape.closestPositionOnRoute(to: coordinate) { [weak self] (closestCoordinate, closestPosition) in
//                     if let routePointClosestToCoordinate = self?.mapView.convert(closestCoordinate, toPointTo: self?.mapView) {
//                        let distance = gestureLocation.distance(to: routePointClosestToCoordinate)
    //
//                        if distance < shortestDistance {
//                            shortestDistance = distance
//                            nearestRoute = route
//                        }
//                    }
//                }
//            }
//        }
    //
//        guard shortestDistance < 100 else { return }
//        selectedRoute = nearestRoute
    //
//        draw(routes: routes)
//        drawETATimes(routes: routes)
//    }
    
    /// Reset the navigation UI, map camera, and clear the routes
    fileprivate func clearNavigationUI() {
        UIApplication.shared.isIdleTimerDisabled = false
        
        if MQDemoOptions.shared.promptsAudio != .none {
            audioManager.stopPlayback()
            audioManager.active = false
        }
        
        if let annotations = mapView.annotations {
            mapView.removeAnnotations(annotations)
        }
        
        mapView.setUserTrackingMode(.none, animated: false)
        
        let camera = mapView.camera
        if camera.pitch.isZero == false {
            camera.pitch = 0.0
            if let centerCoordinate = self.currentLocation?.coordinate {
                camera.centerCoordinate = centerCoordinate
            }
        }
        if camera.altitude < 1000.0 {
            camera.altitude = 1000.0
        }
        camera.heading = 0
        mapView.setCamera(camera, animated: true)
        
        selectedRoute = nil
        numRerouteCounterDebug = 0
        
        destinations.removeAll()
    }
    
    /// Request Routes from the MQNavigation SDK
    /// Once we receive the routes we choose the first route as a default selected route and draw all of the routes
    /// We also annotate the destinations and ETA times
    /// - Parameter locations: An array of locations
    private func requestRoutes(withDestinations routableDestinations: [MQRouteDestination]) {
        
        //TODO: Once we support a list of MQIDs instead of locations, I'll need to take in an array of MQIDs
        
        guard destinations.count > 0, let currentLocation = currentLocation else {
            OperationQueue.main.addOperation {
                SVProgressHUD.showError(withStatus: "Could not get current location for route…")
            }
            return
        }
        
        routeService.requestRoutes(withStart: currentLocation, destinations: routableDestinations, options: tripOptions) { routes, error in
            
            defer {
                OperationQueue.main.addOperation {
                    SVProgressHUD.dismiss()
                }
            }
            guard let routes = routes, error == nil, routes.count > 0 else {
                let errorString: String = {
                    if let error = error {
                        return error.localizedDescription
                    } else {
                        return "We could not find any routes for your destinations."
                    }
                }()
                
                OperationQueue.main.addOperation {
                    let alert = UIAlertController(title: nil, message: errorString, preferredStyle: .alert, actions: [UIAlertController.continueActionNil])
                    self.present(alert, animated: true, completion: nil)
                }
                return
            }
            
            // draw the routes
            OperationQueue.main.addOperation { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.selectedRoute = routes.first
                strongSelf.availableRoutes = routes
                strongSelf.draw(routes: routes)
                strongSelf.drawNames(routes: routes)

                // We want to update the UI before we annotate the destinations and zoom
                strongSelf.delegate?.update(routes: routes)

                strongSelf.annotateDestinations(zoomMap: true)
            }
        }
    }
    
    /// Add the Route Overlays to the map
    /// The selected route is always drawn on top
    private func draw(routes: [MQRoute]) {
        
        guard let selectedRoute = selectedRoute else { return }
        routeOverlayFactory.lastCompletedRouteLeg = lastCompletedRouteLeg
        
        var highlights = [RouteHighlightPolyline]()
        if routes.count > 1 {
            // We draw the alternate routes first and then the selected one so it goes on top
            let nonSelectedRoutes = routes.filter { $0 != selectedRoute }
            nonSelectedRoutes.forEach {
                highlights.append(contentsOf: routeOverlayFactory.polylines(forRouteLegs: $0.legs, isActive: false))
            }
        }
        
        // Only draw the current leg so we don't get overdrawn routes
        let currentLegs : [MQRouteLeg] = {
            if navigator.navigationManagerState == .navigating, let currentLeg = self.currentRouteLeg {
                return [currentLeg]
            }
            return selectedRoute.legs
        }()
        
        highlights.append(contentsOf: routeOverlayFactory.polylines(forRouteLegs: currentLegs, isActive: true))
        
        // Now draw the routes
        mapView.remove(routeHighlightOverlays)
        mapView.add(highlights)
        routeHighlightOverlays = highlights
    }
    
    /// Draw the selected route and remove ETA annotations
    private func drawSelectedRoute() {
        guard let route = selectedRoute else { return }
        draw(routes: [route])
        removeRouteNameAnnotations()
    }
    
    private func updateSelectedRoute(withRoute route: MQRoute) {
        selectedRoute = route
        drawSelectedRoute()
        
        // Destinations might not match the route destinations due to the new route starting at the point the reroute occurred
        guard let routeDestinations = route.destinations as? [Destination] else {
            assertionFailure("Destinations are not what we expect")
            return
        }
        destinations = routeDestinations
    }
    
    /// Remove Route Name annotations
    private func removeRouteNameAnnotations() {
        routeNameAnnotations.forEach { mapView.removeAnnotation($0) }
        routeNameAnnotations.removeAll()
    }
    
    /// Add the Route Names on top of each route
    /// In order for the annotations not to draw on top of each other, we divide the leg length by an increasing index and position the ETA on a portion of the route. This algorithm is simple and not optimized.
    private func drawNames(routes: [MQRoute]) {
        removeRouteNameAnnotations()
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        var index: UInt = 2
        var selectedAnnotation: RouteNameAnnotation?
        routes.forEach {
            guard let leg = $0.legs.first else { return }
            
            let coordinateCount = leg.shape.coordinateCount()
            
            let annotation = RouteNameAnnotation()
            annotation.route = $0
            annotation.coordinate = leg.shape.coordinate(at: coordinateCount / index)
            annotation.title = $0.name
            routeNameAnnotations.append(annotation)
            
            index += 1
            
            if selectedRoute == $0 {
                selectedAnnotation = annotation
            }
        }
        
        mapView.addAnnotations(routeNameAnnotations)
        if let selectedAnnotation = selectedAnnotation {
            mapView.selectAnnotation(selectedAnnotation, animated: true)
        }
    }
    
    /// Add the Destination annotations on the map
    private func annotateDestinations(zoomMap: Bool) {
        destinationAnnotations.forEach { mapView.removeAnnotation($0) }
        destinationAnnotations = destinations
        
        mapView.addAnnotations(destinationAnnotations)
        
        var annotations = destinationAnnotations as [MGLAnnotation]
        annotations.append(mapView.userLocation!)
        
        if zoomMap, let visibleEdgeInsets = delegate?.visibleEdgeInsets {
            mapView.showAnnotations(annotations, edgePadding: visibleEdgeInsets, animated: true)
        }
    }
    
    /// Update our UI based on reaching the next destination
    func updateDestination(reachedDestination: MQRouteDestination, forCompletedRouteLeg completedRouteLeg: MQRouteLeg, isFinalDestination: Bool, requestUserAcceptance: Bool, confirmArrival: @escaping MQConfirmArrivalBlock) {
        guard let destination = reachedDestination as? Destination,
            let indexOfNextDestination = destinations.index(of: destination)?.advanced(by: 1) else {
                
                let alert = UIAlertController(title: "Completed Route", message: "We don't have a selected Route or the route leg is wrong", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                present(alert, animated: true, completion: nil)
                return
        }

        let nextDestination : Destination? = {
            guard destinations.count > indexOfNextDestination else { return nil }
            return destinations[indexOfNextDestination]
        }()
        
        func updateNavigationView() {
            // if its accepted, then setup properties
            self.lastCompletedRouteLeg = completedRouteLeg
            
            destination.reached = true
            self.annotateDestinations(zoomMap: false)
            
            // Draw the next leg of the route
            self.drawSelectedRoute()
        }
        
        guard requestUserAcceptance else {
            updateNavigationView()
            return
        }
        
        delegate?.reachedDestination(destination, nextDestination: nextDestination, confirmArrival: { (didArrive) in
            
            // Call the Navigation Manager callback with the result
            confirmArrival(didArrive)

            // If that was the final destination - we're going to stop navigating
            guard didArrive, isFinalDestination == false else { return }
            
            updateNavigationView()
        })
    }
}

// MARK: - MGLMapViewDelegate
extension NavViewController: MGLMapViewDelegate {
    
    /// If the Map mode changes, we want to create a new snapback timer and let the RootView controller know so that it can show the recenter button, or alternatively if it is following with course, we want to let the RootView controller hide the recenter button
    fileprivate func map(didChange mode: MGLUserTrackingMode) {
        if let previousMode = previousUserTrackingMode, previousMode == mode { return }
        
        previousUserTrackingMode = mode
        
        snapBackTimer?.invalidate()
        snapBackTimer = nil
        
        // We don't need to update the follow mode if navigation is stopped
        if navigator.navigationManagerState == .stopped {
            return
        }
        
        if mode == .followWithCourse {
            delegate?.userFollowMode(didChangeTo: .following)
            return
        }
        
        snapBackTimer = Timer.scheduledTimer(withTimeInterval: snapBackTimeout, repeats: false) { _ in
            self.resumeUserFollowMode()
        }
        
        delegate?.userFollowMode(didChangeTo: .notFollowing)
    }
    
    func mapView(_ mapView: MGLMapView, regionDidChangeAnimated animated: Bool) {
        // User moved the map, which means he/she doesn't want the app to show current location
        // automatically at the app start this time, so stop location manager
        if locationManager.delegate != nil {
            locationManager.delegate = nil
            locationManager.stopUpdatingLocation()
        }
        
        map(didChange: mapView.userTrackingMode)
    }
    
    func mapView(_ mapView: MGLMapView, didChange mode: MGLUserTrackingMode, animated: Bool) {
        map(didChange: mode)
    }
    
    /// Set the stroke color for the
    func mapView(_ mapView: MGLMapView, strokeColorForShapeAnnotation annotation: MGLShape) -> UIColor {
        guard let annotation = annotation as? RouteHighlightPolyline, let color = annotation.color else {
            return RouteColors.theDefault
            
        }
        return color
    }
    
    func mapView(_ mapView: MGLMapView, lineWidthForPolylineAnnotation annotation: MGLPolyline) -> CGFloat {
        guard let annotation = annotation as? RouteHighlightPolyline else { return 0.0 }
        return annotation.lineWidth
    }
    
    /// We want the destination annotations to show the callout, but not the ETAs
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        guard annotation is Destination else {
            return false
        }
        
        return true
    }
    
    /// Create the annotation views for destination and ETA
    func mapView(_ mapView: MGLMapView, viewFor annotation: MGLAnnotation) -> MGLAnnotationView? {
        
        // Use the point annotation’s coordinate value (as a string) as the reuse identifier for its view.
        let reuseIdentifier = "R\(annotation.coordinate.longitude)-\(annotation.coordinate.latitude)"

        switch annotation {
        case let annotation as RouteNameAnnotation:
            
            // For better performance, always try to reuse existing annotations.
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? RouteTimeAnnotationView
            
            // If there’s no reusable annotation view available, initialize a new one.
            if annotationView == nil {
                annotationView = RouteTimeAnnotationView(reuseIdentifier: reuseIdentifier)
                annotationView!.frame = CGRect(origin: CGPoint.zero, size: annotationView!.size(forText: annotation.title ?? " - "))
                
                annotationView?.time = annotation.title ?? " - "
            }
            
            return annotationView
 
        default:
            return nil
        }
    }
    
    func mapView(_ mapView: MGLMapView, imageFor annotation: MGLAnnotation) -> MGLAnnotationImage? {
        guard let _ = annotation as? Destination else { return nil }
        
        var annotationImage = mapView.dequeueReusableAnnotationImage(withIdentifier: "Destination")
        if annotationImage == nil {
            annotationImage = MGLAnnotationImage(image: #imageLiteral(resourceName: "destination-pin"), reuseIdentifier: "Destination")
        }
        return annotationImage
    }
    
    /// Select a route based on the ETA annotation the user selects
    func mapView(_ mapView: MGLMapView, didSelect annotationView: MGLAnnotationView) {
        guard let alternateRoutes = availableRoutes else { return }
        
        if let annotationView = annotationView as? RouteTimeAnnotationView {
            guard let annotation = annotationView.annotation as? RouteNameAnnotation, let selectedRoute = annotation.route else { return }
            
            self.selectedRoute = selectedRoute
            draw(routes: alternateRoutes)
        }
    }
}

//MARK: - MQNavigationManagerDelegate
extension NavViewController: MQNavigationManagerDelegate {
    
    /// This is a delegate call from the Navigation Manager that allows you to update the UI or perform certain actions
    /// In this demo, we do not use it as we update our UI when the user requests the navigation to start
    func navigationManagerDidStartNavigation(_ navigationManager: MQNavigationManager) {
        lastCompletedRouteLeg = nil
        setupNotifications()
        if LoggingManager.shared.shouldLog, let route = self.navigator.route {
            LoggingManager.shared.start(route: route, completion: nil)
        }
    }
    
    /// This is a delegate call from the Navigation Manager after attempting to start navigation, but encountering an error
    func navigationManager(_ navigationManager: MQNavigationManager, failedToStartNavigationWithError error: Error) {
        let errorCode = (error as NSError).code
        var errorDescription = ""
        
        if errorCode == MQNavigationErrorCode.userLocationTrackingConsentNotSet.rawValue {
            errorDescription = "Please set user consent to location tracking to navigate"
        } else if errorCode == MQNavigationErrorCode.deniedLocationAuthorization.rawValue {
            errorDescription = "Please allow location services to navigate"
        }
        
        SVProgressHUD.showError(withStatus: errorDescription)
        lastCompletedRouteLeg = nil
        clearNavigationUI()
        delegate?.navigationStopped()
    }
    
    /// This is a delegate call from the Navigation Manager that allows you to update the UI or perform certain actions
    /// In this demo, we do not use it as we update our UI when the user requests the navigation to stop
    func navigationManager(_ navigationManager: MQNavigationManager, stoppedNavigation navigationStoppedReason: MQNavigationStoppedReason) {
        lastCompletedRouteLeg = nil
        
        clearNavigationUI()
        
        delegate?.navigationStopped()
        
        guard LoggingManager.shared.hasActiveLoggingSession else { return }
        LoggingManager.shared.end(reason: navigationStoppedReason == .completed ? .reachedDestination:.userEnded, completion: nil)
    }
    
     /// This is a delegate call from the Navigation Manager that allows you to update the UI or perform certain actions
    /// In this demo, we do not use it as we update our UI when the user requests the navigation to stop
    func navigationManagerDidPauseNavigation(_ navigationManager: MQNavigationManager) {
        
    }
    
    func navigationManagerDidResumeNavigation(_ navigationManager: MQNavigationManager) {
        
    }
    
    /// This is a delegate call from the Navigation Manager that allows you to update the UI or perform certain actions when a new location is observed
    /// The location observation provides the raw GPS location as well as the snapped location on the route, upcoming maneuvers, and ETA
    func navigationManager(_ navigationManager: MQNavigationManager, receivedLocationObservation locationObservation: MQLocationObservation) {
        
        // Update the logger with the latest location info
        func updateLogger() {
            LoggingManager.shared.update(locationObservation: locationObservation)
        }
        
        // Handle the location observation
        lastLocationObservation = locationObservation
        
        if LoggingManager.shared.hasActiveLoggingSession {
            updateLogger()
        }
        
        updateETA()
        delegate?.update(maneuverBarDistance: locationObservation.distanceToUpcomingManeuver)
        
        // Error bar
        hasGPSLock = (locationObservation.rawGPSLocation.horizontalAccuracy < 100) ? true : false
        
        guard hasGPSLock else {
            delegate?.update(warnings: ["GPS Lost"])
            return
        }
        delegate?.update(warnings: nil)
    }
    
    /// Updates the Root View Controller with the latest maneuver information
    func navigationManager(_ navigationManager: MQNavigationManager, didUpdateUpcomingManeuver upcomingManeuver: MQManeuver) {
        delegate?.update(maneuverBarText: upcomingManeuver.name, turnType: upcomingManeuver.type, maneuverTypeText: upcomingManeuver.typeText)
    }
    
    /// The Navigation Manager determines that the user has reached the destination
    func navigationManager(_ navigationManager: MQNavigationManager, reachedDestination routeDestination: MQRouteDestination, for completedRouteLeg: MQRouteLeg, isFinalDestination: Bool, confirmArrival: @escaping MQConfirmArrivalBlock) {
        
        updateDestination(reachedDestination: routeDestination, forCompletedRouteLeg: completedRouteLeg, isFinalDestination: isFinalDestination, requestUserAcceptance: true, confirmArrival: confirmArrival)
    }
    
    /// The Navigation Manager has updated the ETA with a new one
    func navigationManagerDidUpdateETA(_ navigationManager: MQNavigationManager, withETAByRouteLegId etaByRouteLegId: [String : MQEstimatedTimeOfArrival]) {
        updateETA()
        
        guard MQDemoOptions.shared.promptsAudio == .always, let currentLegETA = currentRouteLeg?.traffic.estimatedTimeOfArrival.time?.timeIntervalSinceNow else { return }
        let shortDateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            let shortDateFormat = DateFormatter.dateFormat(fromTemplate: "h:mm a", options: 0, locale: Locale.current)
            formatter.dateFormat = shortDateFormat
            return formatter
        }()
        
        // Don't speak ETA unless its a significant difference (using 30 seconds to cover enough of a cross-minute difference)
        if let lastETAReceived = lastETASpoken, abs(lastETAReceived - currentLegETA) < 30 {
             return
        }

        //Speak the arrival time
        let arrivalTime = Date(timeIntervalSinceNow: currentLegETA)
        let arrivalTimeString = shortDateFormatter.string(from: arrivalTime).lowercased()
        let minutesETA = duration(forRouteTime: currentLegETA) ?? ""
        
        audioManager.playText("ETA is now \(arrivalTimeString) in \(minutesETA)", language: nil) { (success) in }
        lastETASpoken = currentLegETA
    }
    
    /// The Navigation Manager will be updating traffic
    func navigationManagerWillUpdateTraffic(_ navigationManager: MQNavigationManager) {
        trafficRequestLocation = lastLocationObservation?.rawGPSLocation
        trafficRequestDate = Date()
    }
    
    /// The Navigation Manager has updated traffic. This is a good time to update the routes with new traffic info
    private func navigationManagerDidUpdateTraffic(_ navigationManager: MQNavigationManager, withTrafficByRouteLegId trafficByRouteLegId: [AnyHashable: Any]) {
//        SVProgressHUD.showInfo(withStatus: "🚗🚙Traffic Update🚕🚗")
        draw(routes: [selectedRoute!])
        AudioServicesPlaySystemSound (1057)
    }
    
    /// The navigation manager has determined that there is a better route due to traffic.
    /// We want to offer the user the choice to use the new route or keep to the current route
    func navigationManager(_ navigationManager: MQNavigationManager, foundTrafficReroute route: MQRoute) {
        
        func cleanupTrafficRequestInfo() {
            trafficRequestLocation = nil
            trafficRequestDate = nil
        }

        // Draw the updated reroute
        draw(routes: [route])
        
        // Zoominto the updated route
        if let annotations = mapView.annotations {
            mapView.showAnnotations(annotations, animated: true)
        }

        let alert = UIAlertController(title: "Traffic Reroute", message: "We found a better route, do you want to use it?", preferredStyle: .actionSheet, actions: [UIAlertAction(title: "Use New Route", style: .destructive, handler: { _ in
            // User chose the new route
            self.updateSelectedRoute(withRoute: route)
            self.startNav(trafficReroute: true)
            self.updateETA()
            
            if LoggingManager.shared.hasActiveLoggingSession {
                LoggingManager.shared.update(route: route, reason: .traffic)
            }
            
            guard let trd = self.trafficRequestDate, let trl = self.trafficRequestLocation, LoggingManager.shared.hasActiveLoggingSession else { return }
            
            LoggingManager.shared.startReroute(location: trl, requestedTime: trd, receivedTime: Date(), geofenceRadius: 0 as NSNumber, rerouteDelay: 0 as NSNumber, receivedRoute: route, result: .accepted)
            
            cleanupTrafficRequestInfo()
            }), UIAlertAction(title: "Existing Route", style: .default, handler: { _ in
                // User chose the existing route
                self.draw(routes: [self.selectedRoute!])
                self.mapView.setUserTrackingMode(.followWithCourse, animated: true)

                guard let trd = self.trafficRequestDate, let trl = self.trafficRequestLocation, LoggingManager.shared.hasActiveLoggingSession else { return }
                
                LoggingManager.shared.startReroute(location: trl, requestedTime: trd, receivedTime: Date(), geofenceRadius: 0 as NSNumber, rerouteDelay: 0 as NSNumber, receivedRoute: route, result: .cancelled)
                
                cleanupTrafficRequestInfo()
        })])
        
        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = CGRect(x: 0, y: view.bounds.height-1, width: view.bounds.width, height: 1)
        present(alert, animated: true, completion: nil)
    }
    
    func navigationManagerShouldReroute(_ navigationManager: MQNavigationManager) -> Bool {
        return self.shouldReroute;
    }
    
    /// The Navigation Manager has a new route due to the user being off-route
    func navigationManager(_ navigationManager: MQNavigationManager, didReroute route: MQRoute) {
        updateSelectedRoute(withRoute: route)
        AudioServicesPlaySystemSound (1057)
        AudioServicesPlaySystemSound (1057)

        guard LoggingManager.shared.hasActiveLoggingSession else { return }
        LoggingManager.shared.update(route: route, reason: .reroute)
    }
    
    /// Happens when:
    ///  - Got back on route and reroute cancelled
    func navigationManagerDiscardedReroute(_ navigationManager: MQNavigationManager) {
        
        guard LoggingManager.shared.hasActiveLoggingSession, let rrl = rerouteRequestLocation, let rrd = rerouteRequestDate else { return }
        
        LoggingManager.shared.startReroute(location: rrl, requestedTime: rrd, receivedTime: Date(), geofenceRadius: 0 as NSNumber, rerouteDelay: 0 as NSNumber, receivedRoute: nil, result: .cancelled)
        
        rerouteRequestDate = nil
        rerouteRequestLocation = nil
    }
    
    /// The Navigation Manager has received new speed limit info
    func navigationManager(_ navigationManager: MQNavigationManager, crossedSpeedLimitBoundariesWithExitedZones exitedSpeedLimits: Set<MQSpeedLimit>?, enteredZones enteredSpeedLimits: Set<MQSpeedLimit>?) {
        
        guard let updateSpeedLimit = delegate?.update(speedLimit:) else { return }
        
        guard let enteredSpeedLimits = enteredSpeedLimits, enteredSpeedLimits.count > 0 else {
            updateSpeedLimit(-1.0)
            return
        }
        
        // Find the maximum speed limit and show it
        // There are also School and Minimum speed limits available
        for limit in enteredSpeedLimits {
            if limit.speedLimitType == .maximum {
                updateSpeedLimit(limit.speed)
                return
            }
        }
    }
 
    /// Called when the app is in the background and navigating, but has not moved enough in a period of time
    func navigationManagerBackgroundTimerExpired(_ navigationManager: MQNavigationManager) {
        let content = UNMutableNotificationContent()
        content.title = "Do you wish to continue navigating to \(currentDestination?.displayTitle ?? "")?"
        content.body = "You haven't moved in awhile while navigation has been in the background. Please let us know if you wish to continue navigating."
        content.sound = UNNotificationSound.default()
        content.categoryIdentifier = "BackgroundTimer"
        let request = UNNotificationRequest(identifier: "BackgroundTimerExpired", content: content, trigger: nil)
        
        // Schedule the notification.
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.add(request, withCompletionHandler: nil)
    }
}

//MARK: - MQNavigationManagerPromptDelegate
extension NavViewController: MQNavigationManagerPromptDelegate {
    
    /// Provides the prompts to speak or use as needed
    func navigationManager(_ navigationManager: MQNavigationManager, receivedPrompt promptToSpeak: MQPrompt, userInitiated: Bool) {
        let startTime = Date()
        let promptLoggingEntry: PromptPlayEntry? = {
            guard LoggingManager.shared.hasActiveLoggingSession, let currentRouteLeg = self.currentRouteLeg else { return nil }
            return LoggingManager.shared.recordPromptReceived(prompt: promptToSpeak, routeLeg: currentRouteLeg)
        }()
        
        guard MQDemoOptions.shared.promptsAudio == .always else { return }
        
        audioManager.playText(promptToSpeak.speech, language: self.navigator.route?.options.language) { successful in
            guard userInitiated == false, let entry = promptLoggingEntry else { return }
            LoggingManager.shared.recordPromptPlayed(entry: entry, start: startTime, end: Date(), interrupted: !successful)
        }
    }
    
    /// Notifies us when we should turn off all audio
    func cancelPrompts(for navigationManager: MQNavigationManager) {
        if MQDemoOptions.shared.promptsAudio != .none {
            audioManager.stopPlayback()
        }
    }
}


// MARK: - Routing Processing
extension NavViewController {
    
    /// We're using the Mapquest Geocoder to identify routable locations for addresses we get from Contacts or addresses without an MQID
    ///
    /// - Parameter completion: A completion block that we'll pass back the array of routable locations
    private func requestRoutableLocations(completion: @escaping (([MQRouteDestination]?)-> Void)) {
        
        guard var urlComponents = URLComponents(string: "https://www.mapquestapi.com/geocoding/v1/batch") else {
            completion(nil)
            return
        }
        
        var routeableLocations = destinations
        
        // Setup the URL
        let defaultSession = URLSession(configuration: .default)
        var queryItems = [URLQueryItem]()
        queryItems.append(URLQueryItem(name: "key", value: Bundle.main.object(forInfoDictionaryKey: "MQApplicationKey") as! String!))
        queryItems.append(URLQueryItem(name: "inFormat", value: "kvp"))
        queryItems.append(URLQueryItem(name: "outFormat", value: "json"))
        queryItems.append(URLQueryItem(name: "thumbMaps", value: "false"))
        queryItems.append(URLQueryItem(name: "maxResults", value: "1"))
        
        // Add the destinations in case there are multiple address from Contacts
        // Ignore the destinations that don't need geocoding
        destinations.forEach { destination in
            //We don't want to geocode destinations that already have an mqid or routeableLocation
            if destination.mqid == nil, destination.routeableLocation == nil, let value = destination.geoAddress.singleLineString(), value.isEmpty == false {
                queryItems.append(URLQueryItem(name: "location", value: value))
            }
        }
        urlComponents.queryItems = queryItems
        
        //check to see if we have any actual geolocation items
        if queryItems.count == 5 {
            completion(routeableLocations)
            return
        }
        
        guard let url = urlComponents.url else {
            completion(nil)
            return
        }
        
        // URLSession Request
        let dataTask = defaultSession.dataTask(with: url) { data, response, error in
            
            // In production, you'll want to provide some better error handling
            if let error = error {
                print(error)
                completion(nil)
                return
            }
            
            // Check for valid data
            guard let data = data, let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                completion(nil)
                return
            }
            
            // The assumption here is that since we are only geocoding for Destinations that we have no mqID or routableLocation, the first one in the list is the one we're going to set the new routableLocation in
            func firstAvailableDestination() -> Destination? {
                return routeableLocations.first { $0.routeableLocation == nil && $0.mqid == nil && $0.geoAddress.singleLineString().isEmpty == false }
            }
            
            // Once we're done with any aspect of this - send back the routable locations
            defer {
                if firstAvailableDestination() == nil {
                    completion(routeableLocations)
                }
            }
           
            // Here we parse out the results and get the routable lat/long
            do {
                guard let geocodedJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let results = geocodedJSON["results"] as? [[String:Any]] else { return }
                
                for result in results {
                    guard let locations = result["locations"] as? [[String:Any]] else { return }
                    
                    for location in locations {
                        guard let latLng = location["latLng"] as? [String:Double], let routableLat = latLng["lat"], let routableLong = latLng["lng"] else { return }
                        let routableLocation = CLLocation(latitude: routableLat, longitude: routableLong)
                        guard let destination = firstAvailableDestination() else {
                            assertionFailure("Our Destinations list doesn't match what we expect")
                            return
                        }
                        destination.routeableLocation = routableLocation
                    }
                }
            } catch let error {
                // In production, you'll want to provide some better error handling
                print("Error Parsing: \(error)")
            }
        }
        
        dataTask.resume()
    }
}

/// This protocol is used as a conduit from the Destination Updating screen
//MARK: - Destination Routing Protocol
extension NavViewController: DestinationManagementProtocol {
    
    func refreshDestinations() {
        SVProgressHUD.show(withStatus: "Fetching route…")
        requestRoutableLocations { routeableDestinations in
            guard let routeableDestinations = routeableDestinations else {
                OperationQueue.main.addOperation {
                    SVProgressHUD.showError(withStatus: "")
                }
                return
            }
            self.requestRoutes(withDestinations: routeableDestinations)
        }
    }
    
    func selectedNew(destination: Destination) {
        destinations.removeAll()
        destinations.append(destination)
    }
    
    func replace(destinations: [Destination]) {
        self.destinations.removeAll()
        self.destinations.append(contentsOf: destinations)
    }
}

//MARK: - TripPlanningProtocol
extension NavViewController : TripPlanningProtocol {
    var shouldReroute: Bool {
        get {
            return MQDemoOptions.shared.shouldReroute
        }
        set {
            MQDemoOptions.shared.shouldReroute = newValue
        }
    }
    
    func showAttribution() {
        mapView.attributionButton.sendActions(for: .touchUpInside)
    }
    
}

/// We ask for the current location of the user and once we get a good enough one, we center the map
//MARK: - Location Manager Delegate
extension NavViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            // You may want to write code here to notify user that this app best functions when
            // location services are enabled
            return
        }
        
        /// When the user authorizes, we can bring up the TOS
        func showTOS() {
            guard MQDemoOptions.shared.showedTrackingTOS == false else { return }
            
            let allowAction = UIAlertAction(title: "I Agree", style: .default) { _ in
                MQDemoOptions.shared.showedTrackingTOS = true
                self.userLocationTrackingConsentStatus = .granted
            }
            let declineAction = UIAlertAction(title: "No Thanks", style: .default) { _ in
                MQDemoOptions.shared.showedTrackingTOS = true
                self.userLocationTrackingConsentStatus = .denied
            }
            
            let tosAlert = UIAlertController(title: "Allow Additional Usage of Location Data?", message: Bundle.main.localizedString(forKey: "informationSharingPrompt", value: nil, table: "InfoPlist"), preferredStyle: .alert, actions: [allowAction, declineAction])
            
            present(tosAlert, animated: true, completion: nil)
        }
        
        // Go ahead and start getting the location so we can see where to center the map
        locationManager.startUpdatingLocation()
        
        // Show the TOS if applicable
        showTOS()
        
        //Attempt to center if we have an old location
        centerMapOnUser()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard hasInitialLocation == false, let location = locations.last else { return }
        
        if location.horizontalAccuracy < 1024, location.timestamp.timeIntervalSinceNow > -180 {
            
            centerMapOnUser()
            locationManager.delegate = nil
            locationManager.stopUpdatingLocation()
            hasInitialLocation = true
        }
    }
}

extension NavViewController: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        switch response.actionIdentifier {
        case UNNotificationDismissActionIdentifier, UNNotificationDefaultActionIdentifier, "Continue":
            break
        case "Exit":
            navigator.cancelNavigation()
        default:
            print("Unknown action")
        }
        
        completionHandler()
    }
}
