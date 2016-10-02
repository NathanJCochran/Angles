//
//  Frame.swift
//  Angles
//
//  Created by Nathan on 5/8/16.
//  Copyright © 2016 Nathan. All rights reserved.
//

import UIKit

class Frame : NSObject, NSCoding{
    
    // MARK: Properties
    var seconds: Double
    var image: UIImage
    var points: [CGPoint]
    
    // MARK: Types
    struct PropertyKey {
        static let secondsKey = "seconds"
        static let imageKey = "image"
        static let pointsKey = "points"
        static let pointsCountKey = "pointsCount"
    }
    
    init(seconds: Double, image:UIImage, points:[CGPoint] = []) {
        self.seconds = seconds
        self.image = image
        self.points = points
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        let seconds = aDecoder.decodeDouble(forKey: PropertyKey.secondsKey)
        let image = aDecoder.decodeObject(forKey: PropertyKey.imageKey) as! UIImage
        let pointsCount = aDecoder.decodeInteger(forKey: PropertyKey.pointsCountKey)
        var points = [CGPoint]()
        for i in 0..<pointsCount {
            let point = aDecoder.decodeCGPoint(forKey: PropertyKey.pointsKey + String(i))
            points.append(point)
        }
        self.init(seconds:seconds, image:image, points: points)
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(seconds, forKey: PropertyKey.secondsKey)
        aCoder.encode(image, forKey: PropertyKey.imageKey)
        aCoder.encode(points.count, forKey: PropertyKey.pointsCountKey)
        for i in 0..<points.count {
            aCoder.encode(points[i], forKey: PropertyKey.pointsKey + String(i))
        }
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
