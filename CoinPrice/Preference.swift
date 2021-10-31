//
//  Preference.swift
//  CoinPrice
//
//  Created by rbcoder on 2021/10/6.
//

import Cocoa

struct Preference: Codable {
    var favs: [Coin] = []
    var barItems: [String] = []
}

struct Coin: Codable {
    var name: String = ""
}
