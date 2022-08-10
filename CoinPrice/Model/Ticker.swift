//
//  Ticker.swift
//  CoinPrice
//
//  Created by rbcoder on 2021/9/28.
//

import Cocoa

class Ticker: NSObject {
    var s: String = ""  //名称
    var p: String = ""  //价格变化
    var c: String = ""  //价格
    var P: String = ""  //价格变化(百分比)
    
    var isShow: Bool = false
    
    override func setValue(_ value: Any?, forUndefinedKey key: String) {
        
    }

}
