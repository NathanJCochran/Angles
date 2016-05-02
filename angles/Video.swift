//
//  Video.swift
//  angles
//
//  Created by Nathan on 4/24/16.
//  Copyright © 2016 Nathan. All rights reserved.
//
import UIKit

class Video : NSObject, NSCoding{
    
    // MARK: Properties
    var name: String
    var dateCreated: NSDate
    var videoURL: NSURL
    
    static let DocumentsDirectoryURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
    static let VideoFilesDirectoryURL = DocumentsDirectoryURL.URLByAppendingPathComponent("videoFiles")
    static let ArchiveURL = DocumentsDirectoryURL.URLByAppendingPathComponent("videos")
    
    // MARK: Types
    struct PropertyKey {
        static let nameKey = "name"
        static let dateCreatedKey = "dateCreated"
        static let videoURLKey = "videoURL"
    }
    
    init?(name: String, dateCreated: NSDate, videoURL: NSURL) {
        if name == "" {
            return nil
        }
        self.name = name
        self.dateCreated = dateCreated
        self.videoURL = videoURL
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        let name = aDecoder.decodeObjectForKey(PropertyKey.nameKey) as! String
        let dateCreated = aDecoder.decodeObjectForKey(PropertyKey.dateCreatedKey) as! NSDate
        let videoPathComponent = aDecoder.decodeObjectForKey(PropertyKey.videoURLKey) as! String
        let videoURL = Video.VideoFilesDirectoryURL.URLByAppendingPathComponent(videoPathComponent)
        self.init(name: name, dateCreated: dateCreated, videoURL: videoURL)
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(name, forKey: PropertyKey.nameKey)
        aCoder.encodeObject(dateCreated, forKey: PropertyKey.dateCreatedKey)
        aCoder.encodeObject(videoURL.lastPathComponent!, forKey: PropertyKey.videoURLKey)
    }
   
}