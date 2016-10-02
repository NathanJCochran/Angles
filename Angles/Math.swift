//
//  Math.swift
//  Angles
//
//  Created by Nathan on 7/9/16.
//  Copyright © 2016 Nathan. All rights reserved.
//

import Foundation
import CoreGraphics

class Math {
    static func getDistanceBetweenPoints(_ a:CGPoint, b:CGPoint) -> CGFloat {
        return hypot(a.x - b.x, a.y - b.y)
    }
    
    static func getAcuteAngleInRadians(_ point1:CGPoint, point2:CGPoint, point3:CGPoint) -> CGFloat {
        let len12 = getDistanceBetweenPoints(point1, b: point2)
        let len23 = getDistanceBetweenPoints(point2, b: point3)
        let len31 = getDistanceBetweenPoints(point3, b: point1)
        let angle = acos((pow(len12, 2) + pow(len23, 2) - pow(len31, 2)) / (2 * len12 * len23)) // By the Law of Cosines
        
        return angle
    }
    
    static func getAcuteAngleInDegrees(_ point1:CGPoint, point2:CGPoint, point3:CGPoint) -> CGFloat {
        let len12 = getDistanceBetweenPoints(point1, b: point2)
        let len23 = getDistanceBetweenPoints(point2, b: point3)
        let len31 = getDistanceBetweenPoints(point3, b: point1)
        let angle = acos((pow(len12, 2) + pow(len23, 2) - pow(len31, 2)) / (2 * len12 * len23)) // By the Law of Cosines
        
        return radiansToDegrees(angle)
    }
    
    static func radiansToDegrees(_ radians: CGFloat) -> CGFloat {
        return (radians * 180) / CGFloat(M_PI)
    }
}
