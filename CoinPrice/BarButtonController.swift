//
//  BarButtonController.swift
//  CoinPrice
//
//  Created by rbcoder on 2021/9/26.
//

import Cocoa
import SwiftyJSON

class BarButtonController: NSViewController {
    
    var statusItem: NSStatusItem? = nil
//    var rightMenu: NSMenu? = nil

    let popover = NSPopover()
    var eventMonitor: EventMonitor?
    let receiver = DataReceiver()
    
    var timer: Timer? = nil
    var tickers: [String: Ticker] = [:]
    
    //本地存储的所有自选币(包含是否需要在状态栏显示)
    lazy var prefered: Preference? = {
        var prefer: Preference? = Common.readUserPreference()
        
        if prefer == nil {
            var coin1 = Coin.init(name: "BTCUSDT")
            var coin2 = Coin.init(name: "ETHUSDT")
            prefer = Preference.init(favs: [coin1, coin2], barItems: [coin1.name, coin2.name])
            
        }
        return prefer
    }()
    
    //需要在列表显示的币种
    lazy var coinsOnTable: [String] = {
        var coins: [String] = []
        for item: Coin in prefered?.favs ?? [] {
            coins.append(item.name)
        }
        return coins
    }()
    
    //需要在状态栏显示的币种
    lazy var coinsOnStatusBar: [String] = {
        var coins: [String] = []
        for item: String in prefered?.barItems ?? [] {
            coins.append(item)
        }
        return coins
    }()
    
    // MARK: - 状态栏按钮及功能
    func setUpStatusBarButton() {
        //添加状态栏按钮
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(named: "StatusIcon")
            
        }
        
        //加载弹窗视图
        popover.contentViewController = PopoverViewController.freshController()
        
        //添加动作监视器
        eventMonitor = EventMonitor.init(mask: [.leftMouseDown, .rightMouseDown], handler: { [weak self] event in
            if let strongSelf = self, strongSelf.popover.isShown {
                strongSelf.closePopover(event!)
            }
        })
        
        //请求所有自选币种数据
        loadNewData(param: coinsOnTable)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refreshAllCoins), name: NSWorkspace.didWakeNotification, object: nil)
        
        //定期刷新数据显示
        self.timer = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(self.updateButtonTitle(_:)), userInfo: nil, repeats: true)

    }
    
    // MARK: - 添加币种到自选列表
    func addFavouriteCoin(name: String, handler: @escaping (Bool, String) -> Void) {
        receiver.requestSingleStream(param: name.lowercased()) { receivedText in
            if receivedText == "" {
                self.loadNewData(param: self.coinsOnTable)
                //返回提示
                handler(false, "未找到此交易对...")

            }else {
                self.receiver.socket.disconnect()
                self.coinsOnTable.append(name.uppercased())

                self.loadNewData(param: self.coinsOnTable)
                
                //保存用户设置
                self.prefered?.favs.append(Coin.init(name: name.uppercased()))
                Common.saveUserPreference(object: self.prefered!)
                
                //返回提示
                handler(true, "添加成功!")
            }
        }
        
    }
    
    // MARK: - 从自选列表删除币种
    func deleteFavouriteCoin(name: String) {
        if coinsOnStatusBar.contains(name) {
            //$0表示简写的闭包函数的第一个回调参数,$1表示第二个,以此类推
            //查询removeAll方法的文档可知, 此处$0表示调用者的每一个Element
            //即removeAll方法内部对调用者进行遍历时,通过闭包返回的每一个Element
            coinsOnStatusBar.removeAll(where: {name == $0})
        }
        coinsOnTable.removeAll(where: {name == $0})
        
        loadNewData(param: coinsOnTable)
        //此处是为了让 statusItem 的 button 刷新frame
        statusItem?.button?.image = NSImage(named: "StatusIcon")
        
        //保存用户设置
        self.prefered?.favs.removeAll(where: {name == $0.name})
        Common.saveUserPreference(object: self.prefered!)
    
    }
    
    // MARK: - 刷新列表所有币种
    @objc func refreshAllCoins() {
        loadNewData(param: coinsOnTable)
    }
    
    //请求数据
    private func loadNewData(param: [String]) {
        if receiver.socket != nil {
            receiver.socket.disconnect()
        }
        
        receiver.requestCombinedStream(params: param) { receivedText in
            //处理每条stream数据
            self.handleStreamData(data: receivedText)
        }
    }
    
    private func handleStreamData(data: String) {
        if let string = data.data(using: .utf8, allowLossyConversion: false) {
            do {
                let json = try JSON(data: string)
                let coin = json["data"]["s"].stringValue
                let ticker = Ticker()
                ticker.s = json["data"]["s"].stringValue
                ticker.p = json["data"]["p"].stringValue
                ticker.c = json["data"]["c"].stringValue
                ticker.P = json["data"]["P"].stringValue
                
                tickers.updateValue(ticker, forKey: coin)
                
            } catch {
                fatalError("JSON数据解析出错!\(error)")
            }
        }
    }

// MARK: -  刷新按钮标题
    @objc func updateButtonTitle(_ sender: AnyObject) {

        if let button = statusItem?.button {
            let titleStr = NSMutableAttributedString(string: "")
            for item in coinsOnStatusBar {
                if let ticker = tickers[item] {
                    let aPrice = makeAttributedString(ticker: ticker)
                    titleStr.append(aPrice)
                }
            }
            
            if button.image != nil {
                button.image = nil
//                if timer!.isValid {
//                    timer?.fireDate = Date(timeIntervalSinceNow: 1)
//                }
                NSAnimationContext.runAnimationGroup({ context in
                    // 1 second animation
                    context.duration = 0.6
//                    button.animator().alphaValue = 0
//                    button.animator().isHidden = true
                }) { [self] in
                    
                    button.frame = NSRect.init(x: 0, y: 0, width: 100, height: statusItem?.button?.bounds.height ?? 22)
                    button.animator().isHidden = false
                    button.animator().alphaValue = 1
                                        
                }
                
                let cell = ItemButtonCell.init(textCell: "")
                cell.backgroundColor = NSColor.clear
//                cell.showsBorderOnlyWhileMouseInside = true
                cell.isBordered = false
                button.cell = cell
                button.attributedTitle = titleStr
                
                button.target = self
                button.action = #selector(togglePopover(_:))
//                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
                
            } else {
                button.attributedTitle = titleStr
            }
            
        }
    
    }
    
    private func makeAttributedString(ticker: Ticker) -> NSMutableAttributedString {
        let font = NSFont.boldSystemFont(ofSize: 18)
        let redColor = NSColor.init(red: 220/255, green: 20/255, blue: 60/255, alpha: 1)
        let greenColor = NSColor.init(red: 50/255, green: 205/255, blue: 50/255, alpha: 1)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: Double(ticker.p) ?? 0 >= 0 ? greenColor : redColor,
        ]
        let attributes2: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.init(red: 255/255, green: 215/255, blue: 0/255, alpha: 1)
        ]
        
        var number = ticker.c
        if let cc = Float(ticker.c) {
            switch cc {
            case 1000... :
                number = String(format: "%.0f ", cc)
            case 10..<1000 :
                number = String(format: "%.2f ", cc)
            case 1..<10 :
                number = String(format: "%.3f ", cc)
            case 0.0001..<1 :
                number = String(format: "%.4f ", cc)
            case 0..<0.0001 :
                number = String(format: "%.6f ", cc)
            default:
                break
            }

        }
        
        let dollerString = NSMutableAttributedString(string: "$", attributes: attributes2)
        let numberString = NSMutableAttributedString(string: number, attributes: attributes)
        numberString.addAttribute(.foregroundColor, value: Double(ticker.p) ?? 0 >= 0 ? NSColor.green : NSColor.red, range: NSMakeRange(2, numberString.length - 2))
//        numberString.addAttribute(.strokeWidth, value: NSNumber(integerLiteral: 4), range: NSMakeRange(2, numberString.length - 2))
        
        let priceStr = NSMutableAttributedString(string: "")
        priceStr.append(dollerString)
        priceStr.append(numberString)
        
        return priceStr
    }

    //处理按钮点击事件
//    @objc func mouseClickHandler(_ sender: AnyObject) {
//        guard let event = NSApp.currentEvent else { return }
//            switch event.type {
//            case .rightMouseUp:
//                statusItem.menu = rightMenu
//                statusItem.button?.performClick(nil)
//            default:
//                togglePopover(popover)
//            }
//    }
    
// MARK: - 处理弹窗
    //左键点击
    @objc func togglePopover(_ sender: AnyObject) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    //显示弹窗
    @objc func showPopover(_ sender: AnyObject) {
        if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
        eventMonitor?.start()
    }
    
    //隐藏弹窗
    @objc func closePopover(_ sender: AnyObject) {
        popover.performClose(sender)
        eventMonitor?.stop()
    }
    
}

class ItemButtonCell: NSButtonCell {

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(textCell string: String) {
        super.init(textCell: string)
    }
    
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var textFrame = super.titleRect(forBounds: rect)
//        let textSize = super.attributedTitle.size()
//        textFrame.origin.y = rect.origin.y - (rect.size.height - textSize.height)*0.5
        textFrame.origin.y = rect.origin.y + 1
        return textFrame
        
    }
}
