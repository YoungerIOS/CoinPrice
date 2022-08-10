//
//  extensions.swift
//  CoinPrice
//
//  Created by Joey Young on 2022/8/4.
//

import Foundation
import Cocoa

extension String {
    mutating func addBlank(per: Int = 1) -> String {
        let spaceCount = Int(count/per)
        for i in 1 ..< spaceCount {
            // 字符串插入空格
            self.insert(contentsOf: "，", at: self.index(self.startIndex, offsetBy: per * i + i - 1))

        }
        return self
    }
    
}

extension NSView {
   func startAnimtion(clockwise:Bool = true) {
       wantsLayer = true
       // 注意⚠️，修改了anchorPoint会变更frame，无法实现预期在效果。在macOS上anchorPoint默认为(0,0)
       let oldFrame = layer?.frame
       layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
       layer?.frame = oldFrame!
       let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
       let from:CGFloat = CGFloat.pi
       let end:CGFloat = 0
       rotateAnimation.fromValue = clockwise ? from : end
       rotateAnimation.toValue = clockwise ? end : from
       rotateAnimation.duration = 0.5
       rotateAnimation.isAdditive = true
       rotateAnimation.repeatCount = 1
       layer?.add(rotateAnimation, forKey: "rotateAnimation")
   }
   
   func stopAnimation() {
       layer?.removeAnimation(forKey: "rotateAnimation")
   }
   
}
