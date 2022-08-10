//
//  StreamData.swift
//  CoinPrice
//
//  Created by rbcoder on 2021/9/24.
//

import Cocoa
import Starscream

class DataReceiver: NSObject, WebSocketDelegate {
    
    var socket: WebSocket!
    let server = WebSocketServer()
    var callback: (String) -> Void = {_ in }
    var failureCallback: () -> Void = {}
    var isReceivingText = false
    
    func requestSingleStream(param: String, handler: @escaping (String) -> Void) {
        callback = handler
        //        let urlString = "wss://fstream.binance.com/ws/btcusdt@markPrice"
        let urlString = String(format: "%@%@@ticker", Common.baseURL2, param)
        
        var request = URLRequest(url: URL(string: urlString)!)
        request.timeoutInterval = 5
        socket = WebSocket(request: request)
        socket.delegate = self
        socket.connect()
        
        //由于无数据时,didReceive方法不走text()分支,也不走error()分支,
        //因此无法通过回调给调用者返回有用的text
        //临时解决办法:
        isReceivingText = false
        DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
            if !self.isReceivingText {
                //3秒后如果没有text返回,则走此处
                self.callback("")
            }
        }
        
    }
    
    func requestCombinedStream(params: [String], handler: @escaping (String) -> Void, failure: @escaping () -> Void) {
        callback = handler
        failureCallback = failure

//        let urlString = "wss://fstream.binance.com/stream?streams=btcaaausdt@ticker"
        let urlString = splicingUrlWithStrings(array: params)
        
        var request = URLRequest(url: URL(string: urlString)!)
        request.timeoutInterval = 5
        socket = WebSocket(request: request)
        socket.delegate = self
        socket.connect()
        
    }
    
    func splicingUrlWithStrings(array: [String]) -> String {
        var urlSring = Common.baseURL
        var stream = ""
        for (index, item) in array.enumerated() {
            if index == array.count - 1 {
                stream += String(format: "%@@ticker", item.lowercased())
            }else {
                stream += String(format: "%@@ticker/", item.lowercased())
            }
        }
        urlSring.append(stream)
        return urlSring
    }
    
    func writeText(_ sender: AnyObject) {
        socket.write(string: "hello there!")
    }
    
    // MARK: - WebSocketDelegate
    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected(let headers):
            print("websocket is connected: \(headers)")
        case .disconnected(let reason, let code):
            failureCallback()
            print("websocket is disconnected: \(reason) with code: \(code)")
        case .text(let string):
            isReceivingText = true
            callback(string)
            string.isEmpty ? failureCallback() : nil
        case .binary(let data):
            print("Received data: \(data.count)")
        case .ping(_):
            break
        case .pong(_):
            break
        case .viabilityChanged(_):
            break
        case .reconnectSuggested(_):
            break
        case .cancelled:
            break
        case .error(let error):
            handleError(error)
            failureCallback()
        }
    }

    func handleError(_ error: Error?) {
        if let e = error as? WSError {
            print("websocket encountered an error: \(e.message)")
        } else if let e = error {
            print("websocket encountered an error: \(e.localizedDescription)")
        } else {
            print("websocket encountered an error")
        }
    }
}
