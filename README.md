MapQuest Navigation Demo
========================

A simple navigation app designed for internal testing, to act as a reference design for customers, and to show off best UX practices for a navigation experience.

![picture](Screenshot/Screenshot.png)

Building the Project
-----------------------

The project uses [CocoaPods](http://cocoapods.org/) to manage 3rd party
libaries. Pods are included with the source, but if you make any pod-related
changes, run the following (and commit the resulting changes):

    $ [sudo] sudo gem install cocoapods

And then install the pods via:

    $ pod install

Note that you must open the *workspace* file from now on, not the *project*
file. The workspace file is configured to build the pods and then our project,
which now depends on the pod archive.

    $ open MQNavigationDemo.xcworkspace
    
You'll have to add your MapQuest access key to the `MQApplicationKey`
field in Info.plist. Also, be sure to update your Bundle Identifier and Team
Identity.

MapQuest API Key
---------------------------

Get your MapQuest access key at <https://developer.mapquest.com>.


Traffic Data Collection: Requesting User Consent
---------------------------

MQNavigation is designed to collect location data during active navigation sessions in order to improve the quality of our routes and traffic data. Verizon/Mapquest believes the user's privacy is of the highest importance. Your application is required to request explicit consent to collect location data and to use it for the purposes enumerated below before navigation will proceed. Verizon may share de-identified location information with third parties for limited aggregate purposes, such as traffic reporting.

This sample app has a generic dialog. Your in-app disclosure language should include:

- Allow [name of app] to collect location and navigation-session information from your device while navigating.
- Anonymous location data will be collected by Verizon's location service and sent to 3rd-party traffic services.
- Verizon and its affiliates may use this information to enhance other location-based services and experiences such as local advertising.
- Buttons: **No thanks** / **I Agree**

MQNavigationManager's userLocationTrackingConsentStatus flag has three possible states:

- *Awaiting* - this is the default state. MQNavigationManager will not start navigation in this state.
- *Granted* - the user has granted consent and MQNavigationManager will collect location information during active navigation only.
- *Denied* - the user has denied consent and MQNavigationManager will not collect location information.

While in the awaiting consent state, navigation will not start and you will receive an error that consent has not been set. You may persist the user's response and set it for future navigation sessions.

How to use this Project
---------------------------

This project has several components you can use as a basis for building your own MapQuest-based Navigation application. These areas are designed so that you can re-use the concepts and code in your own projects. The demo is heavily commented for your reading pleasure. The project can be separate into the following areas:

### Root User Interface

`RootViewController.swift` defines and sets up the basic user interface for the Navigation project. It is the delegate for `NavViewController` which allows it to respond to state changes:
        * Navigation Starting/Stopping
        * Updating UI for Manuever Text, ETA (estimated time of arrival), Warnings, Lane Guidance, Speed Limit
        * State of the map - whether its currently following the user's location/course or if the user has manually moved the map

The `RootViewController` also handles as a conduit between the Destination controller and the Navigation controller using the `TripPlanningProtocol` protocol.

### Map and Navigation Controller

`NavViewController` is the heart and soul of this demo. It defines a `NavViewControllerDelegate` to communicate with the `RootViewController`, works with the *MQNavigation* framework, and handles all navigation interaction.

The `NavViewController` uses the *MQNavigation* framework to request routes, based on a current location, a single destination, and trip options (avoid highway, tolls, etc). The resulting set of routes is then displayed as an overlay on the map. From there, we let the user select which route to use. When the user starts navigation, *MQNavigation* is again called to start navigation at which point `NavViewController` begins to receive delegate calls for:
        * Start/Stop/Pause/Resume Navigation
        * Location Updates
        * ETA/Traffic Updates
        * Traffic Reroute Requests
        * Speed Limit Changes
        * Reaching the Destination
        * Prompts

The `NavViewController` also is a delegate for the `MQMapView` and lets the `RootViewController` know about UI changes changes that need occur when the user takes the map out of navigation mode. For example if the user pans or zooms, the `RootViewController` adds a _Recenter_ button to bring the map back into navigation mode.

We have broken all of the delegate calls into their own extensions separated by `//MARK: ` statements so you can easily find what you're looking for.

### Audio Prompts

The `MQNavigationManagerPromptDelegate` provides prompts to you that you can handle any way you want. In this demo app we use our `AudioManager` that utilizes iOS' `AVSpeechSynthesizer` for the actual speech. The `AudioManager` handles the volume, ducking, headphone, Bluetooth, and alert management for you.

### Search Ahead/Destination Controller

`SearchDestinationViewController` is a simple view controller with a UITableView that works with our *MQSearchAhead* framework. As you type in text, the *MQSearchAhead* is queried and the results are processed into an array that's passed using the `SearchParentProtocol` protocol back to the `RootViewController` and then to the `NavViewController`.

In the `SearchAheadOperation` class there is a `collections` property which refines the search results to : airports, addresses, POI, and franchises. You can add categories and admin areas - but those will return results with no location. However this can be useful if you wish to allow the search ahead to dig deeper into a specific type or area. For example if a result for "Sushi" returns "Sushi Restaurants" as a category, you might use that to limit the results to only Sushi restaurants. Please refer to the *MQSearchAhead* documentation for more information on these collections. Also note that the demo app does not handle category or admin area collections. `SearchAheadOperation` is a subclass of `SearchOperation` which you can use to create new search data sources.

_We are using the [Pulley library on Github ](https://github.com/52inc/Pulley) to create a drawer for the Search Ahead. Pulley is not affiliated with MapQuest._

### Annotations and Route overlays

Routes are generated as `MGLPolyline` overlays on the map. The `RouteAnnotator` class takes an `MQRoute` and enumerates the shape coordinates to create a colorful route based on being the selected or inactive route, or traffic. The `NavController` removes the old route from the map and then adds the new routes. The method that implements this is: `draw(routes: [MQRoute])`.

The destination annotation shows up as an image by responding to the `mapView(:imageFor:)` delegate call from `MQMapView`. To change the destination image, change the image returned in this method.


### Requesting Routes and the Destination Class
The *MQNavigation* framework uses a `MQRouteDestination` protocol to define a single or set of destinations when requesting a route. This sample app subclasses the `MQPlace` class that we receive from *MQSearchAhead* and applies the `MQRouteDestination` protocol to this class. This allows us to have a complete destination object containing the destination name, address, display coordinate, POI MQID (if applicable) that can be used throughout our sample application and within the *MQNavigation* framework. The advantage to using the `MQRouteDestination` is if you have a MQID, our routing engine can use detailed context information to generate a better, more accurate route.

You can also request routes using only `CLLocation` coordinates as well.


### Multi-stop Routes

Typically most people will drive from one location to the next, but occasionally they will setup a multi-stop route: Home -> Dry Cleaning -> Office. *MQNavigation* gives you control over what happens upon reaching each destination point. Within the demo app, the `NavViewController` notifies `RootViewController` that a destination was reached (if its not the final destination) and then gives the user the ability to decide when they have reached the destination (for example they may need to park). Once the user has accepted the arrival the demo app pauses navigation. Pausing navigation allows the user to select when they will continue upon the route. We set the text in the bottom view to let the user know that when they tap on the bottom view - it will resume navigation to the next destination.

Tapping on the next destination label on the main screen will bring up an alert asking if you'd like to advance to the next leg. This uses the `MQNavigationManager`'s `advanceRouteToNextLeg` method. The `MQNavigationManager` provides the current route and the current leg and if you used a `MQRouteDestination` conformant object, the destinations you passed to `MQRouteService` to generate the route will also be available in the `MQNavigationManager` `MQRoute` object's `destinations` property.


### Logging

Navigation generates lots of userful information that you may want to log for support purposes. The demo app includes a fully customizable `LoggingManager` that implements our `LoggingProtocol`. You can create your own manager based on the protocol or simply use the existing manager.


Further Documentation
---------------------------

For more information on the MapQuest Navigation SDK, check out: <https://developer.mapquest.com/documentation/nav-sdk/ios/>

For more information on the MapQuest Maps SDK, check out: <https://developer.mapquest.com/documentation/ios-sdk/>

For more information on the MapQuest SearchAhead SDK, check out: <https://developer.mapquest.com/documentation/searchahead-sdk/ios/>
