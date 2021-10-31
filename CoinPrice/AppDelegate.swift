//
//  AppDelegate.swift
//  CoinPrice
//
//  Created by rbcoder on 2021/9/21.
//

import Cocoa

let barButton = BarButtonController() //Tips:在AppDelegate中声明的全局变量将构成单例

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
//    let barButton = BarButtonController()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        barButton.setUpStatusBarButton()
        
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        barButton.refreshAllCoins()
    }
}
