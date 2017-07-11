//
//  Frame.swift
//  Angles
//
//  Created by Nathaniel J Cochran on 5/8/16.
//  Copyright © 2016 Nathaniel J Cochran. All rights reserved.
//

import UIKit
import CoreMedia
import AVFoundation

class Frame : NSObject, NSCoding{
    
    // MARK: Properties
    var index: Int
    var seconds: Double // TODO: Store as CMTime instead of seconds for more accuracy (which matters, for sake of seeking to correct frame in video)
    var points: [CGPoint]
    
    // MARK: Cached items
    private var cachedImage: UIImage?
    private var cachedThumbnailImage: UIImage?
    
    // MARK: Types
    struct PropertyKey {
        static let indexKey = "index"
        static let secondsKey = "seconds"
        static let pointsKey = "points"
        static let pointsCountKey = "pointsCount"
    }
    
    init(index: Int, seconds: Double, points:[CGPoint] = []) {
        self.index = index
        self.seconds = seconds
        self.points = points
    }
    
    // MARK: Encoding
    
    required convenience init?(coder aDecoder: NSCoder) {
        let index = aDecoder.decodeInteger(forKey: PropertyKey.indexKey)
        let seconds = aDecoder.decodeDouble(forKey: PropertyKey.secondsKey)
        let pointsCount = aDecoder.decodeInteger(forKey: PropertyKey.pointsCountKey)
        var points = [CGPoint]()
        for i in 0..<pointsCount {
            let point = aDecoder.decodeCGPoint(forKey: PropertyKey.pointsKey + String(i))
            points.append(point)
        }
        self.init(index: index, seconds:seconds, points: points)
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(index, forKey: PropertyKey.indexKey)
        aCoder.encode(seconds, forKey: PropertyKey.secondsKey)
        aCoder.encode(points.count, forKey: PropertyKey.pointsCountKey)
        for i in 0..<points.count {
            aCoder.encode(points[i], forKey: PropertyKey.pointsKey + String(i))
        }
    }
    
    // MARK: Utility functions
    
    func freeMemory() {
        cachedImage = nil
        cachedThumbnailImage = nil
    }
    
    func getImage(video: Video) throws -> UIImage {
        if cachedImage == nil {
            cachedImage = try video.getImageAt(seconds: seconds, size: CGSize.zero) // CGSize.zero means original image size
        }
        return cachedImage!
    }
    
    func getThumbnailImage(video: Video, size: CGSize) throws -> UIImage {
        if cachedThumbnailImage == nil {
            cachedThumbnailImage = try video.getImageAt(seconds: seconds, size: video.getThumbnailImageGenerationSize(targetSize: size))
        }
        return cachedThumbnailImage!
    }
    
    func getAngleCount() -> Int {
        return points.count - 2
    }
    
    func getAnglesInDegrees() -> [CGFloat] {
        var angles = [CGFloat]()
        if points.count > 2 {
            for i in 0..<points.count-2 {
                let angle = Math.getAcuteAngleInDegrees(points[i], point2: points[i+1], point3: points[i+2])
                angles.append(angle)
            }
        }
        return angles
    }
}
