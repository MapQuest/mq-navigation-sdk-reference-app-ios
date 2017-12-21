//
//  KerningLabel.swift
//  MQDemo
//
//  Copyright © 2017 Mapquest. All rights reserved.
//

import UIKit

class KerningLabel: UILabel {
    
    //MARK: Public Properties
    var characterSpacing : CGFloat = 0 {
        didSet {
            updateText()
        }
    }
    
    var paragraphLineSpacing : CGFloat = 0 {
        didSet {
            updateText()
        }
    }
    
    var size : CGSize {
        let constraintSize = CGSize(width: frame.width, height: CGFloat.greatestFiniteMagnitude)
        guard let text = self.text, let attributesDict = attributedText?.attributes(at: 0, effectiveRange: nil) else { return CGSize.zero}
        
        let nsText = text as NSString
        let boundingRect = nsText.boundingRect(with: constraintSize, options: .usesLineFragmentOrigin, attributes: attributesDict, context: nil)
        
        return boundingRect.size
    }
    
    override var text: String? {
        didSet {
            updateText()
        }
    }
    
    //MARK: - Private Methods
    fileprivate func updateText() {
        let text = self.text ?? ""
        
        let attrStr = NSMutableAttributedString(string: text)
        let style = NSMutableParagraphStyle()
        style.lineSpacing = paragraphLineSpacing
        style.alignment = textAlignment
        
        attrStr.addAttributes([.kern:characterSpacing, .paragraphStyle:style], range: NSMakeRange(0, attrStr.length))
        attributedText = attrStr
    }
}
