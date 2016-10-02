//
//  FrameCollectionViewCell.swift
//  Angles
//
//  Created by Nathaniel J Cochran on 5/15/16.
//  Copyright © 2016 Nathaniel J Cochran. All rights reserved.
//

import UIKit

class FrameCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var frameImageView: UIImageView!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.backgroundView = UIView(frame: self.bounds)
        self.backgroundView!.backgroundColor = nil
        self.selectedBackgroundView = UIView(frame:self.bounds)
        self.selectedBackgroundView!.backgroundColor = UIColor.yellow
    }
}
