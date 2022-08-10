//
//  Preference.swift
//  CoinPrice
//
//  Created by rbcoder on 2021/10/6.
//

import Cocoa

struct Preference: Codable {
    //所有个人数据 都写在这个类中 保存在本地
    //但给此类添加属性会导致本地旧数据无法读取，因此以后不能再添加新属性了
    //1.自选币种
    var favs: [Coin] = []
    //2.添加到状态栏的币种
    var barItems: [String] = []
    //3.开启了语音播报的币种
    var speakable: [Coin] = []
    //4.警报
    var alertItems: [Alert] = []
    
}

struct Coin: Codable {
    var name: String = ""
    var speakTimeInterval: Double = 0.0
}

struct Alert: Codable {
    var name: String = ""
    var min: String = ""
    var max: String = ""
    var onOff: String = "ON"
}
