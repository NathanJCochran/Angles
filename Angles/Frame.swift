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
    var seconds: Double
    var points: [CGPoint]
    
    private var cachedImage: UIImage?
    
    // MARK: Types
    struct PropertyKey {
        static let secondsKey = "seconds"
        static let pointsKey = "points"
        static let pointsCountKey = "pointsCount"
    }
    
    init(seconds: Double, points:[CGPoint] = []) {
        self.seconds = seconds
        self.points = points
    }
    
    // MARK: Encoding
    
    required convenience init?(coder aDecoder: NSCoder) {
        let seconds = aDecoder.decodeDouble(forKey: PropertyKey.secondsKey)
        let pointsCount = aDecoder.decodeInteger(forKey: PropertyKey.pointsCountKey)
        var points = [CGPoint]()
        for i in 0..<pointsCount {
            let point = aDecoder.decodeCGPoint(forKey: PropertyKey.pointsKey + String(i))
            points.append(point)
        }
        self.init(seconds:seconds, points: points)
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(seconds, forKey: PropertyKey.secondsKey)
        aCoder.encode(points.count, forKey: PropertyKey.pointsCountKey)
        for i in 0..<points.count {
            aCoder.encode(points[i], forKey: PropertyKey.pointsKey + String(i))
        }
    }
    
    // MARK: Utility functions
    
    func freeMemory() {
        cachedImage = nil
    }
    
    func getImage(video: Video) throws -> UIImage {
        if cachedImage == nil {
            cachedImage = try video.getImageAt(seconds: seconds)
        }
        return cachedImage!
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
