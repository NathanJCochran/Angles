//
//  Video.swift
//  Angles
//
//  Created by Nathaniel J Cochran on 4/24/16.
//  Copyright © 2016 Nathaniel J Cochran. All rights reserved.
//
import UIKit
import AVFoundation
import xlsxwriter

class Video : NSObject, NSCoding{
    
    // MARK: Properties
    var name: String
    var dateCreated: Date
    var videoURL: URL
    var frames: [Frame]
    
    // Private:
    private var cachedVideoAsset: AVAsset?
    private var cachedImageGenerator: AVAssetImageGenerator?
    private var cachedThumbnailImage: UIImage?
    
    private static let DocumentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private static let VideoFilesDirectoryURL = DocumentsDirectoryURL.appendingPathComponent("videoFiles")
    private static let CSVFilesDirectoryURL = DocumentsDirectoryURL.appendingPathComponent("csv")
    private static let XLSXFilesDirectoryURL = DocumentsDirectoryURL.appendingPathComponent("xlsx")
    private static let ArchiveURL = DocumentsDirectoryURL.appendingPathComponent("videos")
    private static let FileNameDateFormat = "yyyyMMddHHmmss"
    private static let XLSXColumnWidth = 20.0
    
    // MARK: Errors
    enum VideoError: Error {
        case imageGenerationError(message: String, error: NSError)
        case saveError(message: String, error: NSError?)
        case xlsxError(message: String, error: String?)
    }
    
    // MARK: Types
    struct PropertyKey {
        static let nameKey = "name"
        static let dateCreatedKey = "dateCreated"
        static let videoURLKey = "videoURL"
        static let framesKey = "frames"
        static let framesCountKey = "framesCount"
    }
    
    // MARK: Static methods
    
    static func SaveVideos(_ videos: [Video]) throws {
        let success = NSKeyedArchiver.archiveRootObject(videos, toFile: Video.ArchiveURL.path)
        if !success {
            throw VideoError.saveError(message: "Could not archive video objects", error: nil)
        }
    }
    
    static func LoadVideos() -> [Video] {
        if let videos = NSKeyedUnarchiver.unarchiveObject(withFile: Video.ArchiveURL.path) as? [Video] {
            return videos
        }
        return [Video]()
    }
    
    // WARNING: Erases ALL users data
    static func ClearSavedVideos() {
        let fileManager = FileManager.default
        
        do {
            for url in [Video.VideoFilesDirectoryURL, Video.CSVFilesDirectoryURL, Video.XLSXFilesDirectoryURL, Video.DocumentsDirectoryURL] {
                let directoryContents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions())
                if directoryContents != nil {
                    for content in directoryContents! {
                        print("Removing: " + content.absoluteString)
                        try fileManager.removeItem(at: content)
                    }
                }
            }
        } catch let error as NSError {
            print("Could not remove files from documents directory")
            print(error)
        }
    }
    
    // MARK: Instance methods:

    init(name: String, dateCreated: Date, videoURL: URL, frames: [Frame] = []) {
        self.name = name
        if name == "" {
            self.name = "Untitled"
        }
        self.dateCreated = dateCreated
        self.videoURL = videoURL
        self.frames = frames
    }
    
    convenience init(tempVideoURL: URL, dateCreated: Date = Date()) throws {
        
        // Make sure the video files directory exists:
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: Video.VideoFilesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            throw VideoError.saveError(message: "Could not create video files directory", error: error)
        }
        
        // Create new video URL:
        let fileExtension = tempVideoURL.pathExtension
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.dateFormat = Video.FileNameDateFormat
        let fileName = formatter.string(from: dateCreated)
        var newVideoURL = Video.VideoFilesDirectoryURL.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
        
        // Check if video already exists at this URL, and update URL if so:
        var count = 1
        while fileManager.fileExists(atPath: newVideoURL.path) {
            newVideoURL = Video.VideoFilesDirectoryURL.appendingPathComponent(fileName + "_" + String(count)).appendingPathExtension(fileExtension)
            count += 1
        }
        
        // Move the file from the tmp directory to the video files directory:
        do {
            try fileManager.moveItem(at: tempVideoURL, to: newVideoURL)
        } catch let error as NSError {
            throw VideoError.saveError(message: "Could not move video file from tmp directory", error:error)
        }
        
        // Create new video domain object:
        self.init(name: "", dateCreated: dateCreated, videoURL: newVideoURL)
    }
    
    // MARK: Encoding
    
    required convenience init(coder aDecoder: NSCoder) {
        let name = aDecoder.decodeObject(forKey: PropertyKey.nameKey) as! String
        let dateCreated = aDecoder.decodeObject(forKey: PropertyKey.dateCreatedKey) as! Date
        let videoPathComponent = aDecoder.decodeObject(forKey: PropertyKey.videoURLKey) as! String
        let videoURL = Video.VideoFilesDirectoryURL.appendingPathComponent(videoPathComponent)
        let frames = aDecoder.decodeObject(forKey: PropertyKey.framesKey) as! [Frame]
        self.init(name: name, dateCreated: dateCreated, videoURL: videoURL, frames: frames)
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: PropertyKey.nameKey)
        aCoder.encode(dateCreated, forKey: PropertyKey.dateCreatedKey)
        aCoder.encode(videoURL.lastPathComponent, forKey: PropertyKey.videoURLKey)
        aCoder.encode(frames, forKey: PropertyKey.framesKey)
    }
    
    // MARK: Utility functions
    
    func freeMemory() {
        cachedVideoAsset = nil
        cachedImageGenerator = nil
        cachedThumbnailImage = nil
        for frame in frames {
            frame.freeMemory()
        }
    }
    
    func getVideoAsset() -> AVAsset {
        if cachedVideoAsset == nil {
            cachedVideoAsset = AVURLAsset(url: videoURL, options: nil)
        }
        return cachedVideoAsset!
    }
    
    func getImageGenerator() -> AVAssetImageGenerator {
        if cachedImageGenerator == nil {
            // Load video and image generator:
            cachedImageGenerator = AVAssetImageGenerator(asset: getVideoAsset())
            cachedImageGenerator!.appliesPreferredTrackTransform = true
            cachedImageGenerator!.requestedTimeToleranceBefore = kCMTimeZero
            cachedImageGenerator!.requestedTimeToleranceAfter = kCMTimeZero
            
        }
        return cachedImageGenerator!
    }
    
    func getThumbnailImage() throws -> UIImage {
        return try getImageAt(seconds: frames.first?.seconds ?? 0)
    }
    
    func getImageAt(seconds: Double) throws -> UIImage {
        do {
            // Generate new frame image from video asset:
            let time = CMTime(seconds:seconds, preferredTimescale: getDuration().timescale)
            let cgImage = try getImageGenerator().copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch let error as NSError {
            throw VideoError.imageGenerationError(message: "Could not generate image from video at " + String(seconds) + " seconds", error: error)
        }
    }
    
    func getDuration() -> CMTime {
        return getVideoAsset().duration
    }
    
    func deleteData() throws {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(at: videoURL)
        } catch let error as NSError {
            throw VideoError.saveError(message: "Could not delete video file from Documents directory", error: error)
        }
        
        let csvURL = getCSVURL()
        if fileManager.fileExists(atPath: csvURL.path) {
            do {
                try fileManager.removeItem(at: csvURL)
            } catch let error as NSError {
                throw VideoError.saveError(message: "Could not delete CSV file from Documents directory", error: error)
            }
        }
        
        let xlsxURL = getXLSXURL()
        if fileManager.fileExists(atPath: xlsxURL.path) {
            do {
                try fileManager.removeItem(at: xlsxURL)
            } catch let error as NSError {
                throw VideoError.saveError(message: "Could not delete XSLX file from Documents directory", error: error)
            }
        }
    }
    
    func getFormattedDateCreated() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: dateCreated)
    }
    
    func getCSVURL() -> URL {
        let fileExtension = "csv"
        let fileName = videoURL.deletingPathExtension().lastPathComponent
        return Video.CSVFilesDirectoryURL.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
    }
    
    func getXLSXURL() -> URL {
        let fileExtension = "xlsx"
        let fileName = videoURL.deletingPathExtension().lastPathComponent
        return Video.XLSXFilesDirectoryURL.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
    }
    
    func getCSV() -> String {
        let angleCount = getMaxAngleCount()
        
        // Create header row:
        var fileData = "Time (seconds),"
        for i in 0..<angleCount {
            fileData += String(format: "Angle %d,", i+1)
        }
        fileData.remove(at: fileData.characters.index(before: fileData.endIndex))
        fileData += "\n"
        
        // Create row for each frame:
        for frame in frames {
            fileData += String(format: "%f,", frame.seconds)
            let angles = frame.getAnglesInDegrees()
            for angle in angles {
                fileData += String(format: "%f,", angle)
            }
            fileData.remove(at: fileData.characters.index(before: fileData.endIndex))
            fileData += "\n"
        }
        
        return fileData
    }
    
    func saveCSV() throws  {
        
        // Make sure the CSV files directory exists:
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: Video.CSVFilesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            throw VideoError.saveError(message: "Could not create CSV files directory", error: error)
        }

        // Save the CSV data to the specified location:
        let fileData = getCSV()
        do {
            
            try fileData.write(to: getCSVURL(), atomically: true, encoding: String.Encoding.utf8)
        } catch let error as NSError {
            throw VideoError.saveError(message: "Could not write CSV data to temp file", error: error)
        }
    }
    
    func saveXLSX() throws {
        // Make sure the XLSX files directory exists:
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: Video.XLSXFilesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            throw VideoError.saveError(message: "Could not create XLSX files directory", error: error)
        }
        
        // Create xlsx workbook:
        let workbook = new_workbook((getXLSXURL().path as NSString).fileSystemRepresentation)
        let rightAlignedFormat = workbook_add_format(workbook)
        format_set_align(rightAlignedFormat, UInt8(LXW_ALIGN_RIGHT.rawValue))
        
        // Create the points worksheet:
        let pointsWorksheet = workbook_add_worksheet(workbook, "Points")
        
        // Create the header row:
        let pointCount = getMaxPointCount()
        var err = worksheet_write_string(pointsWorksheet, 0, 0, "Time (seconds)", rightAlignedFormat)
        if err != LXW_NO_ERROR {
            throw VideoError.xlsxError(message: "Could not write column 0 header to Points worksheet", error: String(cString: lxw_strerror(err)))
        }
        err = worksheet_set_column(pointsWorksheet, 0, 0, Video.XLSXColumnWidth, nil)
        if err != LXW_NO_ERROR {
            throw VideoError.xlsxError(message: "Could not set column 0 width in xlsx Points worksheet", error: String(cString: lxw_strerror(err)))
        }
        for i in 0..<pointCount {
            let column = UInt16(i+1)
            err = worksheet_write_string(pointsWorksheet, 0, column, String(format: "Point %d", column), rightAlignedFormat)
            if err != LXW_NO_ERROR {
                throw VideoError.xlsxError(message: String(format:"Could not write column %d header to Points worksheet", column), error: String(cString: lxw_strerror(err)))
            }
            err = worksheet_set_column(pointsWorksheet, 0, column, Video.XLSXColumnWidth, nil)
            if err != LXW_NO_ERROR {
                throw VideoError.xlsxError(message: String(format: "Could not set column %d width in Points worksheet", column), error: String(cString: lxw_strerror(err)))
            }
        }
        
        
        // Create row for each frame:
        for (i, frame) in frames.enumerated() {
            let row = UInt32(i+1)
            err = worksheet_write_number(pointsWorksheet, row, 0, frame.seconds, nil)
            if err != LXW_NO_ERROR {
                throw VideoError.xlsxError(message: String(format: "Could not write row %d timestamp to Points worksheet", row), error: String(cString: lxw_strerror(err)))
            }
            
            // Add all of the frame's points to the row:
            for (j, point) in frame.points.enumerated() {
                let column = UInt16(j+1)
                err = worksheet_write_string(pointsWorksheet, row, column, String(format: "(%f, %f)", point.x, point.y) , rightAlignedFormat)
                if err != LXW_NO_ERROR {
                    throw VideoError.xlsxError(message: String(format:"Could not write row %d column %d point to Points worksheet", row, column), error: String(cString: lxw_strerror(err)))
                }
            }
        }
        
        // Create the angles worksheet:
        let anglesWorksheet = workbook_add_worksheet(workbook, "Angles")
        
        // Create header row:
        let angleCount = getMaxAngleCount()
        err = worksheet_write_string(anglesWorksheet, 0, 0, "Time (seconds)", rightAlignedFormat)
        if err != LXW_NO_ERROR {
            throw VideoError.xlsxError(message: "Could not write column 0 header to Angles worksheet", error: String(cString: lxw_strerror(err)))
        }
        err = worksheet_set_column(anglesWorksheet, 0, 0, Video.XLSXColumnWidth, nil)
        if err != LXW_NO_ERROR {
            throw VideoError.xlsxError(message: "Could not set column 0 width in Angles worksheet", error: String(cString: lxw_strerror(err)))
        }
        for i in 0..<angleCount {
            let column = UInt16(i+1)
            err = worksheet_write_string(anglesWorksheet, 0, column, String(format: "Angle %d (degrees)", column), rightAlignedFormat)
            if err != LXW_NO_ERROR {
                throw VideoError.xlsxError(message: String(format:"Could not write column %d header to Angles worksheet", column), error: String(cString: lxw_strerror(err)))
            }
            err = worksheet_set_column(anglesWorksheet, 0, column, Video.XLSXColumnWidth, nil)
            if err != LXW_NO_ERROR {
                throw VideoError.xlsxError(message: String(format:"Could not set column %d width in Angles worksheet", column), error: String(cString: lxw_strerror(err)))
            }
        }
        
        // Create row for each frame:
        for (i, frame) in frames.enumerated() {
            let row = UInt32(i+1)
            err = worksheet_write_number(anglesWorksheet, row, 0, frame.seconds, nil)
            if err != LXW_NO_ERROR {
                throw VideoError.xlsxError(message: String(format:"Could not write row %d timestamp to Angles worksheet", row), error: String(cString: lxw_strerror(err)))
            }
            
            // Add all of the frame's angles to the row:
            let angles = frame.getAnglesInDegrees()
            for (j, angle) in angles.enumerated() {
                let column = UInt16(j+1)
                err = worksheet_write_number(anglesWorksheet, row, column, Double(angle), nil)
                if err != LXW_NO_ERROR {
                    throw VideoError.xlsxError(message: String(format:"Could not write row %d column %d angle to Angles worksheet", row, column), error: String(cString: lxw_strerror(err)))
                }
            }
        }
        
        // Save the file:
        err = workbook_close(workbook)
        if err != LXW_NO_ERROR {
            throw VideoError.xlsxError(message: "Could not close xlsx workbook", error: String(cString: lxw_strerror(err)))
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
