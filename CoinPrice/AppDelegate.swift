//
//  AppDelegate.swift
//  CoinPrice
//
//  Created by rbcoder on 2021/9/21.
//

import Cocoa

let mainController = BarButtonController() //Tips:在AppDelegate中声明的全局变量将构成单例

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
//    let mainController = BarButtonController()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        mainController.setUpStatusBarButton()
        
        //此句代码可删除本地所有使用UserDefaults存储的数据
//        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        mainController.refreshAllCoins()
    }
}
