//
//  MQDemoOptions.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import Foundation
import MQCore

class MQDemoOptions {
    enum PromptsAudio: Int {
        case always
        case none
        
        var image: UIImage {
            switch self {
            case .always: return #imageLiteral(resourceName: "Speaker")
            case .none: return #imageLiteral(resourceName: "SpeakerNone")
            }
        }
        
        func advance() -> PromptsAudio {
            switch self {
            case .always: return .none
            case .none: return .always
            }
        }
    }
    
    enum SearchResultType: String {
        case place, mru
        case home, parking, work
        case contact, event
        
        var isFavorite: Bool {
            switch self {
            case .home, .parking, .work: return true
            default: return false
            }
        }
        
        var isSaved: Bool {
            if isFavorite, self == .mru { return true }
            return false
        }
    }
    
    struct Constants {
        static let promptsAudio = "PromptsAudio"
        static let showSwipeMe = "showSwipeMe"
        static let showedTrackingTOS = "showedTrackingTOS"
        static let userConsentedTracking = "userConsentedTracking"
        static let mruDestinations = "mruDestinations"
    }
    
    private let defaults = UserDefaults.standard
    
    /// Public Methods
    static let shared = MQDemoOptions()
    var userConsentedTracking: Bool = false {
        didSet {
            defaults.set(userConsentedTracking, forKey: Constants.userConsentedTracking)
        }
    }
    
    var showedTrackingTOS: Bool = false {
        didSet {
            defaults.set(showedTrackingTOS, forKey: Constants.showedTrackingTOS)
        }
    }
    
    var showSwipeMe: Bool = false {
        didSet {
            defaults.set(showSwipeMe, forKey: Constants.showSwipeMe)
        }
    }
    var promptsAudio: PromptsAudio = .always {
        didSet {
            defaults.set(promptsAudio.rawValue, forKey: Constants.promptsAudio)
        }
    }
    
    // Destination places
    private(set) var mostRecentlyUsedDestinations: [Destination]!
    var workPlace: Destination? {
        didSet {
            guard let destination = workPlace else {
                defaults.removeObject(forKey: SearchResultType.work.rawValue)
                return
            }
            setPlace(destination: destination, type: .work)
        }
    }
    var parkingPlace: Destination? {
        didSet {
            guard let destination = parkingPlace else {
                defaults.removeObject(forKey: SearchResultType.parking.rawValue)
                return
            }
            setPlace(destination: destination, type: .parking)
        }
    }
    var homePlace: Destination? {
        didSet {
            guard let destination = homePlace else {
                defaults.removeObject(forKey: SearchResultType.home.rawValue)
                return
            }
            setPlace(destination: destination, type: .home)
        }
    }
    
    // MARK: Read in the options
    init() {
        
        func readPlace(type: SearchResultType) -> Destination? {
            guard let data = defaults.data(forKey: type.rawValue), let destination = NSKeyedUnarchiver.unarchiveObject(with: data) as? Destination else { return nil }
            return destination
        }
        
        func readMRU() -> [Destination] {
            guard let data = defaults.data(forKey: Constants.mruDestinations), let destinations = NSKeyedUnarchiver.unarchiveObject(with: data) as? [Destination] else {
                return [Destination]()
            }
            return destinations
        }
        
        promptsAudio = PromptsAudio(rawValue: defaults.integer(forKey: Constants.promptsAudio)) ?? .always
        showSwipeMe = defaults.bool(forKey: Constants.showSwipeMe)
        userConsentedTracking = defaults.bool(forKey: Constants.userConsentedTracking)
        showedTrackingTOS = defaults.bool(forKey: Constants.showedTrackingTOS)
        
        workPlace = readPlace(type: .work)
        parkingPlace = readPlace(type: .parking)
        homePlace = readPlace(type: .home)
        
        mostRecentlyUsedDestinations = readMRU()
    }
    
    /// Simple method to add an MRU and handle removing older items from the array
    ///
    /// - Parameter destination: A destination that was selected recently by the user
    func addMRU(destination: Destination) {
        guard destination.favoriteType == .place,  mostRecentlyUsedDestinations.contains(destination) == false else { return }
        
        destination.favoriteType = .mru
        mostRecentlyUsedDestinations.insert(destination, at: 0)
        if mostRecentlyUsedDestinations.count > 3 {
            mostRecentlyUsedDestinations.removeLast()
        }
        
        let data = NSKeyedArchiver.archivedData(withRootObject: mostRecentlyUsedDestinations) as Any
        defaults.set(data, forKey: Constants.mruDestinations)
    }
    
    /// Remove a place
    ///
    /// - Parameter type: A favorites type
    func removePlace(type: SearchResultType) {
        defaults.removeObject(forKey: type.rawValue)
        
        switch type {
        case .home: homePlace = nil
        case .parking: parkingPlace = nil
        case .work: workPlace = nil
        default: break // using default here because the other types don't apply to favorites
        }
    }
    
    // MARK: Helper functions for archived objects
    
    private func setPlace(destination: Destination, type: SearchResultType) {
        destination.favoriteType = type
        
        let data = NSKeyedArchiver.archivedData(withRootObject: destination) as Any
        defaults.set(data, forKey: type.rawValue)
        
        guard let index = mostRecentlyUsedDestinations.index(of: destination) else { return }
        mostRecentlyUsedDestinations.remove(at: index)
    }
}
