//
//  Video.swift
//  angles
//
//  Created by Nathan on 4/24/16.
//  Copyright © 2016 Nathan. All rights reserved.
//
import UIKit

class Video {
    
    // MARK: Properties
    var name: String
    var dateCreated: NSDate
    var videoURL: NSURL
    
    init?(name: String, dateCreated: NSDate, videoURL: NSURL) {
        if name == "" {
            return nil
        }
        self.name = name
        self.dateCreated = dateCreated
        self.videoURL = videoURL
    }
}