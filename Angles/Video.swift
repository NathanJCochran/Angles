//
//  Video.swift
//  Angles
//
//  Created by Nathan on 4/24/16.
//  Copyright © 2016 Nathan. All rights reserved.
//
import UIKit
import AVFoundation
import xlsxwriter

class Video : NSObject, NSCoding{
    
    // MARK: Properties
    var name: String
    var dateCreated: NSDate
    var videoURL: NSURL
    var frames: [Frame]
    
    // Private:
    private var cachedThumbnailImage: UIImage?
    
    private static let DocumentsDirectoryURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
    private static let VideoFilesDirectoryURL = DocumentsDirectoryURL.URLByAppendingPathComponent("videoFiles")
    private static let CSVFilesDirectoryURL = DocumentsDirectoryURL.URLByAppendingPathComponent("csv")
    private static let XLSXFilesDirectoryURL = DocumentsDirectoryURL.URLByAppendingPathComponent("xlsx")
    private static let ArchiveURL = DocumentsDirectoryURL.URLByAppendingPathComponent("videos")
    private static let FileNameDateFormat = "yyyyMMddHHmmss"
    private static let XLSXColumnWidth = 20.0
    
    enum VideoError: ErrorType {
        case SaveError(message: String, error: NSError?)
        case XLSXError(message: String, error: String?)
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
            for url in [Video.VideoFilesDirectoryURL, Video.CSVFilesDirectoryURL, Video.XLSXFilesDirectoryURL, Video.DocumentsDirectoryURL] {
                let directoryContents = try fileManager.contentsOfDirectoryAtURL(url, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions())
                for content in directoryContents {
                    print("Removing: " + content.absoluteString)
                    try fileManager.removeItemAtURL(content)
                }
            }
        } catch let error as NSError {
            print("Could not remove files from documents directory")
            print(error)
        }
    }

    init(name: String, dateCreated: NSDate, videoURL: NSURL, frames: [Frame] = []) {
        self.name = name
        if name == "" {
            self.name = "Untitled"
        }
        self.dateCreated = dateCreated
        self.videoURL = videoURL
        self.frames = frames
    }
    
    convenience init(tempVideoURL: NSURL, dateCreated: NSDate = NSDate()) throws {
        
        // Make sure the video files directory exists:
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
        let fileName = formatter.stringFromDate(dateCreated)
        var newVideoURL = Video.VideoFilesDirectoryURL.URLByAppendingPathComponent(fileName).URLByAppendingPathExtension(fileExtension!)
        
        // Check if video already exists at this URL, and update URL if so:
        var count = 1
        while fileManager.fileExistsAtPath(newVideoURL.path!) {
            newVideoURL = Video.VideoFilesDirectoryURL.URLByAppendingPathComponent(fileName + "_" + String(count)).URLByAppendingPathExtension(fileExtension!)
            count += 1
        }
        
        // Move the file from the tmp directory to the video files directory:
        do {
            try fileManager.moveItemAtURL(tempVideoURL, toURL: newVideoURL)
        } catch let error as NSError {
            throw VideoError.SaveError(message: "Could not move video file from tmp directory", error:error)
        }
        
        // Create new video domain object:
        self.init(name: "", dateCreated: dateCreated, videoURL: newVideoURL)
    }
    
    // MARK: Encoding
    
    required convenience init(coder aDecoder: NSCoder) {
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
    
    // MARK: Utility functions
    
    func deleteData() throws {
        let fileManager = NSFileManager.defaultManager()
        do {
            try fileManager.removeItemAtURL(videoURL)
        } catch let error as NSError {
            throw VideoError.SaveError(message: "Could not delete video file from Documents directory", error: error)
        }
        
        let csvURL = getCSVURL()
        if fileManager.fileExistsAtPath(csvURL.path!) {
            do {
                try fileManager.removeItemAtURL(csvURL)
            } catch let error as NSError {
                throw VideoError.SaveError(message: "Could not delete CSV file from Documents directory", error: error)
            }
        }
        
        let xlsxURL = getXLSXURL()
        if fileManager.fileExistsAtPath(xlsxURL.path!) {
            do {
                try fileManager.removeItemAtURL(xlsxURL)
            } catch let error as NSError {
                throw VideoError.SaveError(message: "Could not delete XSLX file from Documents directory", error: error)
            }
        }
    }
    
    func getFormattedDateCreated() -> String {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .LongStyle
        formatter.timeStyle = .ShortStyle
        return formatter.stringFromDate(dateCreated)
    }
    
    func getCSVURL() -> NSURL {
        let fileExtension = "csv"
        let fileName = videoURL.URLByDeletingPathExtension!.lastPathComponent!
        return Video.CSVFilesDirectoryURL.URLByAppendingPathComponent(fileName).URLByAppendingPathExtension(fileExtension)
    }
    
    func getXLSXURL() -> NSURL {
        let fileExtension = "xlsx"
        let fileName = videoURL.URLByDeletingPathExtension!.lastPathComponent!
        return Video.XLSXFilesDirectoryURL.URLByAppendingPathComponent(fileName).URLByAppendingPathExtension(fileExtension)
    }
    
    func getThumbnailImage() -> UIImage {
        if frames.first != nil {
            return frames.first!.image
        }
        if cachedThumbnailImage != nil {
            return cachedThumbnailImage!
        }
        
        let videoAsset = AVURLAsset(URL: videoURL, options: nil)
        let videoImageGenerator = AVAssetImageGenerator(asset: videoAsset)
        videoImageGenerator.appliesPreferredTrackTransform = true
        videoImageGenerator.requestedTimeToleranceBefore = kCMTimeZero
        videoImageGenerator.requestedTimeToleranceAfter = kCMTimeZero
        do {
            let time = CMTime(seconds:0, preferredTimescale: videoAsset.duration.timescale)
            let cgImage = try videoImageGenerator.copyCGImageAtTime(time, actualTime: nil)
            cachedThumbnailImage = UIImage(CGImage: cgImage)
            return cachedThumbnailImage!
        } catch {
            return UIImage() // Default image
        }
    }
    
    func getCSV() -> String {
        let angleCount = getMaxAngleCount()
        
        // Create header row:
        var fileData = "Time (seconds),"
        for i in 0..<angleCount {
            fileData += String(format: "Angle %d,", i+1)
        }
        fileData.removeAtIndex(fileData.endIndex.predecessor())
        fileData += "\n"
        
        // Create row for each frame:
        for frame in frames {
            fileData += String(format: "%f,", frame.seconds)
            let angles = frame.getAnglesInDegrees()
            for angle in angles {
                fileData += String(format: "%f,", angle)
            }
            fileData.removeAtIndex(fileData.endIndex.predecessor())
            fileData += "\n"
        }
        
        return fileData
    }
    
    func saveCSV() throws  {
        
        // Make sure the CSV files directory exists:
        let fileManager = NSFileManager.defaultManager()
        do {
            try fileManager.createDirectoryAtURL(Video.CSVFilesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            throw VideoError.SaveError(message: "Could not create CSV files directory", error: error)
        }

        // Save the CSV data to the specified location:
        let fileData = getCSV()
        do {
            
            try fileData.writeToURL(getCSVURL(), atomically: true, encoding: NSUTF8StringEncoding)
        } catch let error as NSError {
            throw VideoError.SaveError(message: "Could not write CSV data to temp file", error: error)
        }
    }
    
    func saveXLSX() throws {
        // Make sure the XLSX files directory exists:
        let fileManager = NSFileManager.defaultManager()
        do {
            try fileManager.createDirectoryAtURL(Video.XLSXFilesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            throw VideoError.SaveError(message: "Could not create XLSX files directory", error: error)
        }
        
        // Create xlsx workbook:
        let workbook = new_workbook((getXLSXURL().path! as NSString).fileSystemRepresentation)
        let rightAlignedFormat = workbook_add_format(workbook)
        format_set_align(rightAlignedFormat, UInt8(LXW_ALIGN_RIGHT.rawValue))
        
        // Create the points worksheet:
        let pointsWorksheet = workbook_add_worksheet(workbook, "Points")
        
        // Create the header row:
        let pointCount = getMaxPointCount()
        var err = worksheet_write_string(pointsWorksheet, 0, 0, "Time (seconds)", rightAlignedFormat)
        if err != LXW_NO_ERROR {
            throw VideoError.XLSXError(message: "Could not write column 0 header to Points worksheet", error: String.fromCString(lxw_strerror(err)))
        }
        err = worksheet_set_column(pointsWorksheet, 0, 0, Video.XLSXColumnWidth, nil)
        if err != LXW_NO_ERROR {
            throw VideoError.XLSXError(message: "Could not set column 0 width in xlsx Points worksheet", error: String.fromCString(lxw_strerror(err)))
        }
        for i in 0..<pointCount {
            let column = UInt16(i+1)
            err = worksheet_write_string(pointsWorksheet, 0, column, String(format: "Point %d", column), rightAlignedFormat)
            if err != LXW_NO_ERROR {
                throw VideoError.XLSXError(message: String(format:"Could not write column %d header to Points worksheet", column), error: String.fromCString(lxw_strerror(err)))
            }
            err = worksheet_set_column(pointsWorksheet, 0, column, Video.XLSXColumnWidth, nil)
            if err != LXW_NO_ERROR {
                throw VideoError.XLSXError(message: String(format: "Could not set column %d width in Points worksheet", column), error: String.fromCString(lxw_strerror(err)))
            }
        }
        
        
        // Create row for each frame:
        for (i, frame) in frames.enumerate() {
            let row = UInt32(i+1)
            err = worksheet_write_number(pointsWorksheet, row, 0, frame.seconds, nil)
            if err != LXW_NO_ERROR {
                throw VideoError.XLSXError(message: String(format: "Could not write row %d timestamp to Points worksheet", row), error: String.fromCString(lxw_strerror(err)))
            }
            
            // Add all of the frame's points to the row:
            for (j, point) in frame.points.enumerate() {
                let column = UInt16(j+1)
                err = worksheet_write_string(pointsWorksheet, row, column, String(format: "(%f, %f)", point.x, point.y) , rightAlignedFormat)
                if err != LXW_NO_ERROR {
                    throw VideoError.XLSXError(message: String(format:"Could not write row %d column %d point to Points worksheet", row, column), error: String.fromCString(lxw_strerror(err)))
                }
            }
        }
        
        // Create the angles worksheet:
        let anglesWorksheet = workbook_add_worksheet(workbook, "Angles")
        
        // Create header row:
        let angleCount = getMaxAngleCount()
        err = worksheet_write_string(anglesWorksheet, 0, 0, "Time (seconds)", rightAlignedFormat)
        if err != LXW_NO_ERROR {
            throw VideoError.XLSXError(message: "Could not write column 0 header to Angles worksheet", error: String.fromCString(lxw_strerror(err)))
        }
        err = worksheet_set_column(anglesWorksheet, 0, 0, Video.XLSXColumnWidth, nil)
        if err != LXW_NO_ERROR {
            throw VideoError.XLSXError(message: "Could not set column 0 width in Angles worksheet", error: String.fromCString(lxw_strerror(err)))
        }
        for i in 0..<angleCount {
            let column = UInt16(i+1)
            err = worksheet_write_string(anglesWorksheet, 0, column, String(format: "Angle %d (degrees)", column), rightAlignedFormat)
            if err != LXW_NO_ERROR {
                throw VideoError.XLSXError(message: String(format:"Could not write column %d header to Angles worksheet", column), error: String.fromCString(lxw_strerror(err)))
            }
            err = worksheet_set_column(anglesWorksheet, 0, column, Video.XLSXColumnWidth, nil)
            if err != LXW_NO_ERROR {
                throw VideoError.XLSXError(message: String(format:"Could not set column %d width in Angles worksheet", column), error: String.fromCString(lxw_strerror(err)))
            }
        }
        
        // Create row for each frame:
        for (i, frame) in frames.enumerate() {
            let row = UInt32(i+1)
            err = worksheet_write_number(anglesWorksheet, row, 0, frame.seconds, nil)
            if err != LXW_NO_ERROR {
                throw VideoError.XLSXError(message: String(format:"Could not write row %d timestamp to Angles worksheet", row), error: String.fromCString(lxw_strerror(err)))
            }
            
            // Add all of the frame's angles to the row:
            let angles = frame.getAnglesInDegrees()
            for (j, angle) in angles.enumerate() {
                let column = UInt16(j+1)
                err = worksheet_write_number(anglesWorksheet, row, column, Double(angle), nil)
                if err != LXW_NO_ERROR {
                    throw VideoError.XLSXError(message: String(format:"Could not write row %d column %d angle to Angles worksheet", row, column), error: String.fromCString(lxw_strerror(err)))
                }
            }
        }
        
        // Save the file:
        err = workbook_close(workbook)
        if err != LXW_NO_ERROR {
            throw VideoError.XLSXError(message: "Could not close xlsx workbook", error: String.fromCString(lxw_strerror(err)))
        }
    }
    
    func getMaxAngleCount() -> Int {
        var max = 0
        for frame in frames {
            let count = frame.getAngleCount()
            if count > max {
                max = count
            }
        }
        return max
    }
    
    func getMaxPointCount() -> Int {
        var max = 0
        for frame in frames {
            let count = frame.points.count
            if count > max {
                max = count
            }
        }
        return max
    }
}