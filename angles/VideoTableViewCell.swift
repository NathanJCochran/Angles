//
//  VideoTableViewCell.swift
//  angles
//
//  Created by Nathan on 4/24/16.
//  Copyright © 2016 Nathan. All rights reserved.
//

import UIKit

class VideoTableViewCell: UITableViewCell {
    
    // MARK: Properties
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
