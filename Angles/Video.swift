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
    var version: Int
    
    // Private:
    private var cachedVideoAsset: AVAsset?
    private var cachedImageGenerator: AVAssetImageGenerator?
    private var cachedThumbnailImage: UIImage?
    private var cachedFrameTimestamps: [CMTime]?
    
    private static let DocumentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private static let VideoFilesDirectoryURL = DocumentsDirectoryURL.appendingPathComponent("videoFiles")
    private static let CSVFilesDirectoryURL = DocumentsDirectoryURL.appendingPathComponent("csv")
    private static let XLSXFilesDirectoryURL = DocumentsDirectoryURL.appendingPathComponent("xlsx")
    private static let ArchiveURL = DocumentsDirectoryURL.appendingPathComponent("videos")
    private static let FileNameDateFormat = "yyyyMMddHHmmss"
    private static let XLSXColumnWidth = 20.0
    private static let CurrentVersion = 1
    
    // MARK: Errors
    enum VideoError: LocalizedError {
        case archiveError
        case directoryCreationError(directory: URL)
        case videoFileMoveError(from: URL, to: URL)
        case videoAssetReaderError(videoURL: URL)
        case imageGenerationError(seconds: Double)
        case fileDeletionError(fileURL: URL)
        case fileWriteError(fileURL: URL)
        case xlsxWriteError(worksheet: String, row: UInt32, column: UInt16)
        case xlsxColumnSizeError(worksheet: String, column: UInt16)
        case xlsxWorkbookCloseError
        
        var errorDescription: String? {
            switch self {
            case .archiveError: return "Could not archive video objects"
            case .directoryCreationError(let directory): return "Could not create \(directory.lastPathComponent) directory"
            case .videoFileMoveError(let from, let to): return "Could not move video file from \(from.lastPathComponent) to \(to.lastPathComponent)"
            case .videoAssetReaderError(let videoURL): return "Could not create asset reader for video: \(videoURL.lastPathComponent)"
            case .imageGenerationError(let seconds): return "Could not generate image from video file at time: \(seconds)s"
            case .fileDeletionError(let fileURL): return "Could not delete file from Documents directory: \(fileURL.lastPathComponent)"
            case .fileWriteError(let fileURL): return "Could not write to file: \(fileURL.lastPathComponent)"
            case .xlsxWriteError(let worksheet, let row, let column): return "Could not write to row \(row) column \(column) of \(worksheet) worksheet"
            case .xlsxColumnSizeError(let worksheet, let column): return "Could not set column \(column) width in \(worksheet) worksheet"
            case .xlsxWorkbookCloseError: return "Could not close xlsx workbook"
            }
        }
    }
    
    // MARK: Types
    struct PropertyKey {
        static let nameKey = "name"
        static let dateCreatedKey = "dateCreated"
        static let videoURLKey = "videoURL"
        static let framesKey = "frames"
        static let framesCountKey = "framesCount"
        static let versionKey = "version"
    }
    
    // MARK: Static methods
    
    static func SaveVideos(_ videos: [Video]) throws {
        let success = NSKeyedArchiver.archiveRootObject(videos, toFile: Video.ArchiveURL.path)
        if !success {
            throw VideoError.archiveError
        }
    }
    
    static func LoadVideos() -> [Video] {
        if let videos = NSKeyedUnarchiver.unarchiveObject(withFile: Video.ArchiveURL.path) as? [Video] {
            return videos
        }
        return [Video]()
    }
    
    // WARNING: Erases ALL user data
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
        } catch {
            print(error)
            print("Could not remove files from documents directory")
        }
    }
    
    // MARK: Instance methods:

    init(name: String, dateCreated: Date, videoURL: URL, frames: [Frame] = [], version: Int) {
        self.name = name
        if name == "" {
            self.name = "Untitled"
        }
        self.dateCreated = dateCreated
        self.videoURL = videoURL
        self.frames = frames
        self.version = version
    }
    
    convenience init(tempVideoURL: URL, dateCreated: Date = Date()) throws {
        
        // Make sure the video files directory exists:
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: Video.VideoFilesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error)
            throw VideoError.directoryCreationError(directory: Video.VideoFilesDirectoryURL)
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
        } catch {
            print(error)
            throw VideoError.videoFileMoveError(from: tempVideoURL, to: newVideoURL)
        }
        
        // Create new video domain object:
        self.init(name: "", dateCreated: dateCreated, videoURL: newVideoURL, version: Video.CurrentVersion)
    }
    
    // MARK: Encoding
    
    required convenience init(coder aDecoder: NSCoder) {
        let name = aDecoder.decodeObject(forKey: PropertyKey.nameKey) as! String
        let dateCreated = aDecoder.decodeObject(forKey: PropertyKey.dateCreatedKey) as! Date
        let videoPathComponent = aDecoder.decodeObject(forKey: PropertyKey.videoURLKey) as! String
        let videoURL = Video.VideoFilesDirectoryURL.appendingPathComponent(videoPathComponent)
        let frames = aDecoder.decodeObject(forKey: PropertyKey.framesKey) as! [Frame]
        let version = aDecoder.decodeInteger(forKey: PropertyKey.versionKey)
        self.init(name: name, dateCreated: dateCreated, videoURL: videoURL, frames: frames, version: version)
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: PropertyKey.nameKey)
        aCoder.encode(dateCreated, forKey: PropertyKey.dateCreatedKey)
        aCoder.encode(videoURL.lastPathComponent, forKey: PropertyKey.videoURLKey)
        aCoder.encode(frames, forKey: PropertyKey.framesKey)
        aCoder.encode(version, forKey: PropertyKey.versionKey)
    }
    
    // MARK: Backwards Compatibility Migrations:
    
    func isOutdatedVersion() -> Bool {
        return version < Video.CurrentVersion
    }
    
    func backpopulateData() throws {
        if version == Video.CurrentVersion {
            print("backpopulateData: already at current version")
            return
        } else if version == 0 {
            print("backpopulateData: backpopulating from version 0 to version 1")
            let frameTimestamps = try getFrameTimestamps()
            for (i, frame) in frames.enumerated() {
                print("backpopulateData: frame \(i): seconds=\(frame.seconds)")
                frame.index = try getNearestFrameIndex(seconds: frame.seconds)
                frame.seconds = frameTimestamps[frame.index].seconds
                print("backpopulateData: frame \(i): new index= \(frame.index) new seconds=\(frame.seconds)")
            }
            version = 1
        }
    }
    
    // MARK: Utility functions
    
    func freeMemory() {
        cachedVideoAsset = nil
        cachedImageGenerator = nil
        cachedThumbnailImage = nil
        cachedFrameTimestamps = nil
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
    
    func getVideoAssetReader() throws -> AVAssetReader {
        do {
            return try AVAssetReader(asset: getVideoAsset())
        } catch {
            print(error)
            throw VideoError.videoAssetReaderError(videoURL: videoURL)
            
        }
    }
    
    func getFrameTimestamps() throws -> [CMTime] {
        if cachedFrameTimestamps == nil {
            let track = getVideoAsset().tracks(withMediaType: AVMediaType.video).first!
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil) // nil gets original sample data without overhead for decompression
            let reader = try getVideoAssetReader()
            output.alwaysCopiesSampleData = false
            reader.add(output)
            reader.startReading()
            
            var frameTimestamps = [CMTime]()
            while let sampleBuffer = output.copyNextSampleBuffer() {
                if !CMSampleBufferIsValid(sampleBuffer) {
                    print("getFrameTimestamps: Invalid sample buffer")
                    continue
                } else if CMSampleBufferGetTotalSampleSize(sampleBuffer) == 0 {
                    print("getFrameTimestamps: Total sample size 0")
                    continue
                }
                
                let frameTimestamp = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
                if !frameTimestamp.isValid {
                    print("getFrameTimestamps: Invalid frame timestamp")
                    continue
                }
                print("getFrameTimestamps: frameTimestamp=\(frameTimestamp)")
                frameTimestamps.append(frameTimestamp)
            }
            if reader.status != .completed {
                print("getFrameTimestamps: AVAssetReader finished with unexpected status: \(reader.status.rawValue)")
            }
            frameTimestamps.sort()
            cachedFrameTimestamps = frameTimestamps
        }
        return cachedFrameTimestamps!
    }
    
    // TODO: Move to video class, and implement data migration for backwards compatibility
    func getNearestFrameIndex(seconds: Double) throws -> Int {
        let frameTimestamps = try getFrameTimestamps()
        if frameTimestamps.count == 0 {
            return 0
        }
        
        // Bisection search:
        var low = 0
        var high = frameTimestamps.count - 1
        while (low + 1) != high {
            let mid = low + ((high - low) / 2)
            let frame = frameTimestamps[mid]
            if frame.seconds == seconds {
                return mid
            } else if frame.seconds < seconds {
                low = mid
            } else {
                high = mid
            }
        }
        return low
    }
    
    func getDuration() -> CMTime {
        return getVideoAsset().duration
    }
    
    func getImageGenerator() -> AVAssetImageGenerator {
        if cachedImageGenerator == nil {
            // Load video and image generator:
            cachedImageGenerator = AVAssetImageGenerator(asset: getVideoAsset())
            cachedImageGenerator!.appliesPreferredTrackTransform = true
            cachedImageGenerator!.requestedTimeToleranceBefore = CMTime.zero
            cachedImageGenerator!.requestedTimeToleranceAfter = CMTime.zero
        }
        return cachedImageGenerator!
    }
    
    func getImageAt(seconds: Double, size: CGSize) throws -> UIImage {
        do {
            // Get and configure image generator:
            let imageGenerator = getImageGenerator()
            imageGenerator.maximumSize = size
            
            // Generate new frame image from video asset:
            let time = CMTime(seconds:seconds, preferredTimescale: getDuration().timescale) // TODO: Use actual CMTime timestamp instead
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print(error)
            throw VideoError.imageGenerationError(seconds: seconds)
        }
    }
    
    func getVideoSize() -> CGSize {
        let track = getVideoAsset().tracks(withMediaType: AVMediaType.video).first!
        let size = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
    }
    
    func getThumbnailImageGenerationSize(targetSize: CGSize) -> CGSize {
        // We need to generate a thumbnail image whose smaller dimension (width/height)
        // matches the corresponding dimension of the target view, but whose larger dimension
        // may overflow the view, since the image view's content mode is "Aspect Fill".
        // This also leverages the fact that we know the image view is a square:
        let videoSize = getVideoSize()
        if videoSize.width > videoSize.height {
            // Zero width means don't worry about width, just scale it with the height.
            return CGSize(width: 0, height: targetSize.height * UIScreen.main.scale) // Scaled because points != pixels
        }
        // Zero height means don't worry about height, just scale it with the width.
        return CGSize(width: targetSize.width * UIScreen.main.scale, height: 0) // Scaled because points != pixels
    }
    
    func getThumbnailImage(size: CGSize) throws -> UIImage {
        if cachedThumbnailImage == nil {
            cachedThumbnailImage = try getImageAt(seconds: frames.first?.seconds ?? 0, size: getThumbnailImageGenerationSize(targetSize: size))
        }
        return cachedThumbnailImage!
    }
    
    func deleteData() throws {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(at: videoURL)
        } catch {
            print(error)
            throw VideoError.fileDeletionError(fileURL: videoURL)
        }
        
        let csvURL = getCSVURL()
        if fileManager.fileExists(atPath: csvURL.path) {
            do {
                try fileManager.removeItem(at: csvURL)
            } catch {
                print(error)
                throw VideoError.fileDeletionError(fileURL: csvURL)
            }
        }
        
        let xlsxURL = getXLSXURL()
        if fileManager.fileExists(atPath: xlsxURL.path) {
            do {
                try fileManager.removeItem(at: xlsxURL)
            } catch {
                print(error)
                throw VideoError.fileDeletionError(fileURL: xlsxURL)
            }
        }
    }
    
    func getFormattedDateCreated() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: dateCreated)
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
        fileData.remove(at: fileData.index(before: fileData.endIndex))
        fileData += "\n"
        
        // Create row for each frame:
        for frame in frames {
            fileData += String(format: "%f,", frame.seconds)
            let angles = frame.getAnglesInDegrees()
            for angle in angles {
                fileData += String(format: "%f,", angle)
            }
            fileData.remove(at: fileData.index(before: fileData.endIndex))
            fileData += "\n"
        }
        
        return fileData
    }
    
    func saveCSV() throws  {
        
        // Make sure the CSV files directory exists:
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: Video.CSVFilesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error)
            throw VideoError.directoryCreationError(directory: Video.CSVFilesDirectoryURL)
        }

        // Save the CSV data to the specified location:
        let fileData = getCSV()
        let fileURL = getCSVURL()
        do {
            try fileData.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            print(error)
            throw VideoError.fileWriteError(fileURL: fileURL)
        }
    }
    
    func saveXLSX() throws {
        // Make sure the XLSX files directory exists:
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: Video.XLSXFilesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print(error)
            throw VideoError.directoryCreationError(directory: Video.XLSXFilesDirectoryURL)
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
            print(String(cString: lxw_strerror(err)))
            throw VideoError.xlsxWriteError(worksheet: "Points", row: 0, column: 0)
        }
        err = worksheet_set_column(pointsWorksheet, 0, 0, Video.XLSXColumnWidth, nil)
        if err != LXW_NO_ERROR {
            print(String(cString: lxw_strerror(err)))
            throw VideoError.xlsxColumnSizeError(worksheet: "Points", column: 0)
        }
        for i in 0..<pointCount {
            let column = UInt16(i+1)
            err = worksheet_write_string(pointsWorksheet, 0, column, String(format: "Point %d", column), rightAlignedFormat)
            if err != LXW_NO_ERROR {
                print(String(cString: lxw_strerror(err)))
                throw VideoError.xlsxWriteError(worksheet: "Points", row: 0, column: column)
            }
            err = worksheet_set_column(pointsWorksheet, 0, column, Video.XLSXColumnWidth, nil)
            if err != LXW_NO_ERROR {
                print(String(cString: lxw_strerror(err)))
                throw VideoError.xlsxColumnSizeError(worksheet: "Points", column: column)
            }
        }
        
        
        // Create row for each frame:
        for (i, frame) in frames.enumerated() {
            let row = UInt32(i+1)
            err = worksheet_write_number(pointsWorksheet, row, 0, frame.seconds, nil)
            if err != LXW_NO_ERROR {
                print(String(cString: lxw_strerror(err)))
                throw VideoError.xlsxWriteError(worksheet: "Points", row: row, column: 0)
            }
            
            // Add all of the frame's points to the row:
            for (j, point) in frame.points.enumerated() {
                let column = UInt16(j+1)
                err = worksheet_write_string(pointsWorksheet, row, column, String(format: "(%f, %f)", point.x, point.y) , rightAlignedFormat)
                if err != LXW_NO_ERROR {
                    print(String(cString: lxw_strerror(err)))
                    throw VideoError.xlsxWriteError(worksheet: "Points", row: row, column: column)
                }
            }
        }
        
        // Create the angles worksheet:
        let anglesWorksheet = workbook_add_worksheet(workbook, "Angles")
        
        // Create header row:
        let angleCount = getMaxAngleCount()
        err = worksheet_write_string(anglesWorksheet, 0, 0, "Time (seconds)", rightAlignedFormat)
        if err != LXW_NO_ERROR {
            print(String(cString: lxw_strerror(err)))
            throw VideoError.xlsxWriteError(worksheet: "Angles", row: 0, column: 0)
        }
        err = worksheet_set_column(anglesWorksheet, 0, 0, Video.XLSXColumnWidth, nil)
        if err != LXW_NO_ERROR {
            print(String(cString: lxw_strerror(err)))
            throw VideoError.xlsxColumnSizeError(worksheet: "Angles", column: 0)
        }
        for i in 0..<angleCount {
            let column = UInt16(i+1)
            err = worksheet_write_string(anglesWorksheet, 0, column, String(format: "Angle %d (degrees)", column), rightAlignedFormat)
            if err != LXW_NO_ERROR {
                print(String(cString: lxw_strerror(err)))
                throw VideoError.xlsxWriteError(worksheet: "Angles", row: 0, column: column)
            }
            err = worksheet_set_column(anglesWorksheet, 0, column, Video.XLSXColumnWidth, nil)
            if err != LXW_NO_ERROR {
                print(String(cString: lxw_strerror(err)))
                throw VideoError.xlsxColumnSizeError(worksheet: "Angles", column: column)
            }
        }
        
        // Create row for each frame:
        for (i, frame) in frames.enumerated() {
            let row = UInt32(i+1)
            err = worksheet_write_number(anglesWorksheet, row, 0, frame.seconds, nil)
            if err != LXW_NO_ERROR {
                print(String(cString: lxw_strerror(err)))
                throw VideoError.xlsxWriteError(worksheet: "Angles", row: row, column: 0)
            }
            
            // Add all of the frame's angles to the row:
            let angles = frame.getAnglesInDegrees()
            for (j, angle) in angles.enumerated() {
                let column = UInt16(j+1)
                err = worksheet_write_number(anglesWorksheet, row, column, Double(angle), nil)
                if err != LXW_NO_ERROR {
                    print(String(cString: lxw_strerror(err)))
                    throw VideoError.xlsxWriteError(worksheet: "Angles", row: row, column: column)
                }
            }
        }
        
        // Save the file:
        err = workbook_close(workbook)
        if err != LXW_NO_ERROR {
            print(String(cString: lxw_strerror(err)))
            throw VideoError.xlsxWorkbookCloseError
        }
    }
}
