//
//  AppDelegate.swift
//  MainAppHelper
//
//  Created by rbcoder on 2021/10/17.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.coinprice.CoinPrice") else { return }

        let path = "/bin"
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = [path]
        NSWorkspace.shared.openApplication(at: url,
                                           configuration: configuration,
                                           completionHandler: {_,_ in NSApplication.shared.terminate(self)})
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }


}

