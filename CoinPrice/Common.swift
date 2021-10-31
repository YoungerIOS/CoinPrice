//
//  Common.swift
//  CoinPrice
//
//  Created by rbcoder on 2021/10/1.
//

import Cocoa

class Common: NSObject {
    //组合stream
    public static let baseURL = "wss://fstream.binance.com/stream?streams="
    //单一stream
    public static let baseURL2 = "wss://fstream.binance.com/ws/"
    
    /*
    public static func filePath(fileName: String) -> URL {
        let mainPaths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        let pathURL = URL(string: mainPaths.first!)
        let filepath = pathURL?.appendingPathComponent(fileName)
        return filepath!
    }
    
    //保存自选列表到本地
    private func saveArrayToFile(array: NSArray) {
        let filePath = Common.filePath(fileName: "favourites.plist")
        array.write(toFile: filePath.absoluteString, atomically: true)
    }
    
    //读取本地自选列表
    private func readArrayFromFile() -> NSArray {
        let filePath = Common.filePath(fileName: "favourites.plist")
        if let array = NSArray(contentsOfFile: filePath.absoluteString) {
            return array
        } else {
            return []
        }
    }
    */
    
    public static func saveUserPreference(object: Preference) {
        let jsonEncoder = JSONEncoder()
        let data = try? jsonEncoder.encode(object)
        UserDefaults.standard.set(data, forKey: "UserPreference")
    }
    
    public static func readUserPreference() -> Preference? {
        let jsonData = UserDefaults.standard.data(forKey: "UserPreference")
        let jsonDecoder = JSONDecoder()
        if let data = jsonData {
            guard let object = try? jsonDecoder.decode(Preference.self, from: data) else { return nil }
            return object
        }
        
        return nil
        
    }
    
}
