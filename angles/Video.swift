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
    var frames: [Frame]
    
    private static let DocumentsDirectoryURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
    private static let VideoFilesDirectoryURL = DocumentsDirectoryURL.URLByAppendingPathComponent("videoFiles")
    private static let ArchiveURL = DocumentsDirectoryURL.URLByAppendingPathComponent("videos")
    private static let FileNameDateFormat = "yyyyMMddHHmmss"
    
    enum VideoError: ErrorType {
        case SaveError(message: String, error: NSError?)
    }
    
    // MARK: Types
    struct PropertyKey {
        static let nameKey = "name"
        static let dateCreatedKey = "dateCreated"
        static let videoURLKey = "videoURL"
        static let framesKey = "frames"
        static let framesCountKey = "framesCount"
    }
    
    static func SaveVideos(videos: [Video]) throws {
        let success = NSKeyedArchiver.archiveRootObject(videos, toFile: Video.ArchiveURL.path!)
        if !success {
            throw VideoError.SaveError(message: "Could not archive video objects", error: nil)
        }
    }
    
    static func LoadVideos() -> [Video] {
        if let videos = NSKeyedUnarchiver.unarchiveObjectWithFile(Video.ArchiveURL.path!) as? [Video] {
            return videos
        }
        return [Video]()
    }
    
    static func ClearSavedVideos() {
        let fileManager = NSFileManager.defaultManager()
        
        do {
            let videoDirectoryContents = try fileManager.contentsOfDirectoryAtURL(Video.VideoFilesDirectoryURL, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions())
            for content in videoDirectoryContents {
                print("Removing: " + content.absoluteString)
                try fileManager.removeItemAtURL(content)
            }
            
            let directoryContents = try fileManager.contentsOfDirectoryAtURL(Video.DocumentsDirectoryURL, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions())
            for content in directoryContents {
                print("Removing: " + content.absoluteString)
                try fileManager.removeItemAtURL(content)
            }
        } catch let error as NSError {
            print("Could not remove saved video files from documents directory")
            print(error)
        }
    }

    init?(name: String, dateCreated: NSDate, videoURL: NSURL, frames: [Frame] = []) {
        if name.isEmpty {
            return nil
        }
        self.name = name
        self.dateCreated = dateCreated
        self.videoURL = videoURL
        self.frames = frames
    }
    
    convenience init?(tempVideoURL: NSURL) throws {
        
        // Get the URL of the video files directory, and make sure it exists:
        let fileManager = NSFileManager.defaultManager()
        do {
            try fileManager.createDirectoryAtURL(Video.VideoFilesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            throw VideoError.SaveError(message: "Could not create video files directory", error: error)
        }
        
        // Create new video URL:
        let fileExtension = tempVideoURL.pathExtension
        if fileExtension == nil {
            throw VideoError.SaveError(message: "No file extension for video: " + tempVideoURL.absoluteString, error: nil)
        }
        let formatter = NSDateFormatter()
        formatter.dateStyle = .NoStyle
        formatter.dateFormat = Video.FileNameDateFormat
        let fileName = formatter.stringFromDate(NSDate()) + "." + fileExtension!
        let newVideoURL = Video.VideoFilesDirectoryURL.URLByAppendingPathComponent(fileName)
        
        // Move the file from the tmp directory to the video files directory:
        do {
            try fileManager.moveItemAtURL(tempVideoURL, toURL: newVideoURL)
        } catch let error as NSError {
            throw VideoError.SaveError(message: "Could not move video file from tmp directory", error:error)
        }
        
        // Create new video domain object:
        self.init(name: "Untitled", dateCreated: NSDate(), videoURL: newVideoURL)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        let name = aDecoder.decodeObjectForKey(PropertyKey.nameKey) as! String
        let dateCreated = aDecoder.decodeObjectForKey(PropertyKey.dateCreatedKey) as! NSDate
        let videoPathComponent = aDecoder.decodeObjectForKey(PropertyKey.videoURLKey) as! String
        let videoURL = Video.VideoFilesDirectoryURL.URLByAppendingPathComponent(videoPathComponent)
        let frames = aDecoder.decodeObjectForKey(PropertyKey.framesKey) as! [Frame]
        self.init(name: name, dateCreated: dateCreated, videoURL: videoURL, frames: frames)
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(name, forKey: PropertyKey.nameKey)
        aCoder.encodeObject(dateCreated, forKey: PropertyKey.dateCreatedKey)
        aCoder.encodeObject(videoURL.lastPathComponent!, forKey: PropertyKey.videoURLKey)
        aCoder.encodeObject(frames, forKey: PropertyKey.framesKey)
    }
}