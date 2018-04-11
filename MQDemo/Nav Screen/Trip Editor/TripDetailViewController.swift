//
//  TripDetailViewController.swift
//  MQDemo
//
//  Copyright © 2017 MapQuest. All rights reserved.
//

import UIKit
import MQNavigation

/// Sets multiple destinations and route options

class TripDetailViewController: UITableViewController {

    // MARK: Public Properties
    var destinations = [Destination]()
    weak var delegate: TripPlanningProtocol? {
        didSet {
            guard let delegate = delegate else { return }
            self.destinations = delegate.destinations

            guard isViewLoaded else { return }
            self.tableView.reloadData()
        }
    }

    // MARK: Private Properties
    private let destinationCellIdentifier = "destination"
    private let switchCellIdentifier = "switch"
    private let listItemCellIdentifier = "listItem"
    private let languages: [Language] = [ .englishUS, .spanishUS ]
    private let measurementUnits: [MQSystemOfMeasurement] = [ .unitedStatesCustomary, .metric ]
    
    private enum Language: String {
        case englishUS = "en_US"
        case spanishUS = "es_US"
        
        var title: String {
            switch self {
            case .englishUS: return "US English"
            case .spanishUS: return "US Spanish"
            }
        }
    }
    
    private enum Option: Int {
        case avoidTolls
        case avoidHighways
        case avoidFerries
        case avoidUnpaved
        case avoidInternationalBorders
        case avoidSeasonalClosures
        case allowOffRouteReroutes
        case allowInformationSharing
        case measurementUnits
        case navigationLanguage
    }
    
    private let driveOption: [Option] = [
        .avoidTolls,
        .avoidHighways,
        .avoidFerries,
        .avoidUnpaved,
        .avoidInternationalBorders,
        .avoidSeasonalClosures,
        .allowOffRouteReroutes,
        ]
    
    private let systemOption: [Option] = [
        .allowInformationSharing,
        .measurementUnits,
        .navigationLanguage,
        ]

    // MARK: - View
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.allowsSelectionDuringEditing = true
        isEditing = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    // MARK: - Public Methods
    func refreshDestinations() {
        tableView.reloadData()
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3;
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return destinations.count
        case 1:
            return driveOption.count
        case 2:
            return systemOption.count;
        default:
            assertionFailure()
            return 0;
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return destinations.count > 0 ? "Trip" : nil
        case 1:
            return "Drive Preferences";
        case 2:
            return "System Preferences";
        default:
            assertionFailure()
            return nil;
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: destinationCellIdentifier, for: indexPath)
            cell.textLabel?.text = destinations[indexPath.row].displayTitle
            cell.detailTextLabel?.text = destinations[indexPath.row].displaySubtitle
            return cell
        case 1:
            return optionTableView(tableView, cellOfType: driveOption[indexPath.row], forRowAt: indexPath)
        case 2:
            return optionTableView(tableView, cellOfType: systemOption[indexPath.row], forRowAt: indexPath)
        default:
            assertionFailure()
            return UITableViewCell();
        }
    }
    
    // MARK: - Table view delegate
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // Completely hide trip section when it's hidden
        return (section == 0 && destinations.count == 0) ? CGFloat.leastNonzeroMagnitude : UITableViewAutomaticDimension
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section > 0, let cell = tableView.cellForRow(at: indexPath), let option = optionForIndexPath(indexPath) else { return }
        
        switch option {
        case .avoidTolls, .avoidHighways, .avoidFerries, .avoidUnpaved, .avoidInternationalBorders, .avoidSeasonalClosures: break
        case .allowOffRouteReroutes, .allowInformationSharing: break
        case .measurementUnits:
            guard let vc = storyboard?.instantiateViewController(withIdentifier: "ListTableViewController") as? ListTableViewController else {
                assertionFailure()
                return
            }
            vc.list = measurementUnits.map { userFriendlyMeasurementSystem($0) }
            if let system = delegate?.tripOptions.systemOfMeasurementForDisplayText {
                vc.selectedIndex = measurementUnits.index(of: system) ?? -1
            } else {
                vc.selectedIndex = -1
            }
            vc.selectedBlock = { (selectedIndex: Int?) in
                guard let selectedIndex = selectedIndex else { return }
                self.delegate?.tripOptions.systemOfMeasurementForDisplayText = self.measurementUnits[selectedIndex]
            }
            navigationController?.show(vc, sender: self)
        case .navigationLanguage:
            guard let vc = storyboard?.instantiateViewController(withIdentifier: "ListTableViewController") as? ListTableViewController else {
                assertionFailure()
                return
            }
            vc.list = languages.map { $0.title }
            if let languageString = delegate?.tripOptions.language {
                if let language = Language(rawValue: languageString) {
                    vc.selectedIndex = languages.index(of: language) ?? -1
                } else {
                    vc.selectedIndex = -1
                }
            } else {
                vc.selectedIndex = languages.index(of: .englishUS) ?? -1
            }
            vc.selectedBlock = { (selectedIndex: Int?) in
                guard let selectedIndex = selectedIndex else { return }
                let selectedLanguage = self.languages[selectedIndex]
                cell.detailTextLabel?.text = selectedLanguage.title
                self.delegate?.tripOptions.language = selectedLanguage.rawValue
            }
            navigationController?.show(vc, sender: self)
        }
    }
        
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 0
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            destinations.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
        let destination = destinations[fromIndexPath.row]
        destinations.remove(at: fromIndexPath.row)
        destinations.insert(destination, at: to.row)
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 0 && destinations.count > 1
    }

    // MARK: - Actions
    @IBAction func attributionsTouched(_ sender: Any) {
        delegate?.showAttribution()
    }

    // MARK: - Helpers
    private func userFriendlyMeasurementSystem(_ measurementSystem: MQSystemOfMeasurement) -> String {
        switch measurementSystem {
        case .unitedStatesCustomary: return "US"
        case .metric: return "Metric"
        }
    }
    
    private func optionTableView(_ tableView: UITableView, cellOfType option: Option, forRowAt indexPath: IndexPath) -> UITableViewCell {
        switch option {
        case .avoidTolls:
            return switchCell(text: "Avoid Tolls", value: delegate?.tripOptions.tolls != .allow, for: indexPath, valueChangedBlock: { (selected: Bool) in
                self.delegate?.tripOptions.tolls = selected ? .avoid : .allow
            })
        case .avoidHighways:
            return switchCell(text: "Avoid Highways", value: delegate?.tripOptions.highways != .allow, for: indexPath, valueChangedBlock: { (selected: Bool) in
                self.delegate?.tripOptions.highways = selected ? .avoid : .allow
            })
        case .avoidFerries:
            return switchCell(text: "Avoid Ferries", value: delegate?.tripOptions.ferries != .allow, for: indexPath, valueChangedBlock: { (selected: Bool) in
                self.delegate?.tripOptions.ferries = selected ? .avoid : .allow
            })
        case .avoidUnpaved:
            return switchCell(text: "Avoid Unpaved", value: delegate?.tripOptions.unpaved != .allow, for: indexPath, valueChangedBlock: { (selected: Bool) in
                self.delegate?.tripOptions.unpaved = selected ? .avoid : .allow
            })
        case .avoidInternationalBorders:
            return switchCell(text: "Avoid International Borders", value: delegate?.tripOptions.internationalBorders != .allow, for: indexPath, valueChangedBlock: { (selected: Bool) in
                self.delegate?.tripOptions.internationalBorders = selected ? .avoid : .allow
            })
        case .avoidSeasonalClosures:
            return switchCell(text: "Avoid Seasonal Closures", value: delegate?.tripOptions.seasonalClosures != .allow, for: indexPath, valueChangedBlock: { (selected: Bool) in
                self.delegate?.tripOptions.seasonalClosures = selected ? .avoid : .allow
            })
        case .allowOffRouteReroutes:
            return switchCell(text: "Allow Off-Route Reroutes", value: MQDemoOptions.shared.shouldReroute, for: indexPath, valueChangedBlock: { (selected: Bool) in
                self.delegate?.shouldReroute = selected
            })
        case .allowInformationSharing:
            return switchCell(text: "Allow Information Sharing", value: MQDemoOptions.shared.userLocationTrackingConsentStatus == .granted, for: indexPath, valueChangedBlock: { (selected: Bool) in
                MQDemoOptions.shared.userLocationTrackingConsentStatus = selected ? .granted : .denied
                self.delegate?.consentChanged()
            })
        case .measurementUnits:
            var title: String? = nil
            if let system = delegate?.tripOptions.systemOfMeasurementForDisplayText {
                title = userFriendlyMeasurementSystem(system)
            }
            return listItemCell(text: "Measurement Units", value: title, for: indexPath)
        case .navigationLanguage:
            var title: String? = nil
            if let languageString = delegate?.tripOptions.language, let language = Language(rawValue: languageString) {
                title = language.title
            }
            return listItemCell(text: "Navigation Language", value: title, for: indexPath)
        }
    }
    
    private func optionForIndexPath(_ indexPath: IndexPath) -> Option? {
        switch indexPath.section {
        case 1:
            return driveOption[indexPath.row]
        case 2:
            return systemOption[indexPath.row]
        default:
            return nil
        }
    }
    
    private func switchCell(text: String, value: Bool, for indexPath: IndexPath, valueChangedBlock: ((Bool) -> Void)?) -> SwitchTableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: switchCellIdentifier, for: indexPath) as! SwitchTableViewCell
        cell.label.text = text
        cell.onOff.isOn = value
        cell.valueChangedBlock = valueChangedBlock
        return cell
    }
    
    private func listItemCell(text: String, value: String?, for indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: listItemCellIdentifier, for: indexPath)
        cell.textLabel?.text = text
        cell.detailTextLabel?.text = value
        return cell
    }
}

// MARK: DestinationSearchSelectionProtocol
extension TripDetailViewController: DestinationSearchSelectionProtocol {
    func selectedNew(destination: Destination) {
        destinations.append(destination)
        tableView.reloadData()
    }
}
