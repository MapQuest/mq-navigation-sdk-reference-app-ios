//
//  InstructionsViewController.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import UIKit
import MQNavigation

//MARK: -
class InstructionsViewController: UIViewController {

    //MARK: Public Properties
    var currentRouteLeg : MQRouteLeg!
    var route: MQRoute!
    var flagString: String?
    var displayAddress : String!
    
    //MARK: Interface Builder Outlets
    @IBOutlet weak var tableView : UITableView!
    @IBOutlet weak var dismissView : UIVisualEffectView!
    @IBOutlet weak var flag : UILabel!
    
    //MARK: Private Properties
    private let destinationCellIdentifier = "InstructionsTableViewCell"
    
    //MARK: - Internal Controller
    override func viewDidLoad() {
        super.viewDidLoad()

        if let flagString = flagString {
            flag.isHidden = false
            flag.text = flagString
        } else {
            flag.isHidden = true
        }
        
        var inset = tableView.contentInset
        inset.bottom = dismissView.frame.height
        tableView.contentInset = inset
        tableView.scrollIndicatorInsets = inset
    }
    
    @IBAction func dismissViewController(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }

}

//MARK: - UITableViewDataSource
extension InstructionsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let instructions = currentRouteLeg?.instructions else { return 0 }
        return instructions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: destinationCellIdentifier, for: indexPath) as! InstructionsTableViewCell
        
        if let instructions = currentRouteLeg?.instructions {
            cell.isLastCell = (indexPath.row == instructions.count - 1)
            cell.instruction = instructions[indexPath.row]
        } else {
            cell.instruction = nil
            cell.isLastCell = false
        }
        cell.setUpCell()
        return cell;
    }
}

//MARK: - UITableViewDelegate
extension InstructionsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 0
        guard let instruction = currentRouteLeg?.instructions[indexPath.row] else {
            return 50
        }
        height = 50
        let promptLabelHeight = InstructionsTableViewCell.heightForString(instruction.instruction, cellWidth: view.frame.width)
        let subtextLabelHeight: CGFloat = 0
        let textHeight = promptLabelHeight + subtextLabelHeight
        if promptLabelHeight < 20 && MQManeuver.hasImage(maneuverType: instruction.maneuverType) {
            height += 20
        }
        height += textHeight
        return height
    }
}
