//
//  GCDTool.swift
//  CoinPrice
//
//  Created by Joey Young on 2022/1/22.
//

import Cocoa


typealias Task = (_ cancel: Bool) ->()

class GCDTool: NSObject {
    
    @discardableResult static func delay(_ time: TimeInterval, task: @escaping ()->()) -> Task? {
        func dispatch_later(block: @escaping ()->()) {
            let t = DispatchTime.now() + time
            DispatchQueue.main.asyncAfter(deadline: t, execute: block)
        }
        var closure: (()->())? = task
        var result: Task?
        let delayedClosure: Task = { cancel in
            if let internalClosure = closure {
                if cancel == false {
                    DispatchQueue.main.async(execute: internalClosure)
                }
            }
            closure = nil
            result = nil
        }
        
        result = delayedClosure
        dispatch_later {
            if let delayedClosure = result {
                    delayedClosure(false)
                }
            }
            return result
        }
    
        static func cancel(_ task: Task?) {
            task?(true)
        }
}
