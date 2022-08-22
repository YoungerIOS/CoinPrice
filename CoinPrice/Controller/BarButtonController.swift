//
//  BarButtonController.swift
//  CoinPrice
//
//  Created by rbcoder on 2021/9/26.
//

import Cocoa
import SwiftyJSON
import AVFoundation

class BarButtonController: NSViewController {
    
    var statusItem: NSStatusItem? = nil
//    var rightMenu: NSMenu? = nil

    let popover = NSPopover()
    var popoverVC: PopoverViewController!
    var eventMonitor: EventMonitor?
    let receiver = DataReceiver()
    
    var timer: Timer? = nil
    var tickers: [String:Ticker] = [:]
    
    //本地存储的所有自选币(包含是否需要在状态栏显示)
    lazy var prefered: Preference? = {
        var prefer: Preference? = Common.readUserPreference()
        
        if prefer == nil {
            var coin1 = Coin.init(name: "BTCUSDT", speakTimeInterval: 0)
            var coin2 = Coin.init(name: "ETHUSDT", speakTimeInterval: 0)
            prefer = Preference.init(favs: [coin1, coin2],
                                     barItems: [coin1.name, coin2.name],
                                     speakable: [],
                                     alertItems: [])
            
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
    
    //需要定时语音播报的币种
    lazy var coinsNeedSpeech: [Coin] = {
        var coins: [Coin] = []
        if let array = prefered?.speakable {
            coins = prefered!.speakable
        }
        return coins
    }()
    
    //已设定的警报
    var coinsPriceAlerts: [Alert] {
        get {
            if prefered?.alertItems == nil {
                return []
            }
            return prefered!.alertItems
        }
        
        set {
            prefered?.alertItems = newValue
            Common.saveUserPreference(object: prefered!)
            
            var actived: [Int:Alert] = [:]
            for (index, elm) in newValue.enumerated() {
                if elm.onOff == "ON" {
                    actived.updateValue(elm, forKey: index)
                }
            }
            activeAlerts = actived
        }
        
    }
    
    //已激活的警报
    var activeAlerts: [Int:Alert] = [:]

    // MARK: - 状态栏按钮及功能
    func setUpStatusBarButton() {
        //添加状态栏按钮
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(named: "StatusIcon")
            
        }
        
        //加载弹窗视图
        popoverVC = PopoverViewController.freshController()
        popover.contentViewController = popoverVC
        
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
        timer = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(self.updateButtonTitle(_:)), userInfo: nil, repeats: true)
        
        //定期语音播报价格
        prepareForSpeaking()
        
        //初始化开启状态的警报项目
        initializeAlertItems()
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
        if coinsNeedSpeech.contains(where: {name == $0.name}) {
            coinsNeedSpeech.removeAll(where: {name == $0.name})
        }
        coinsOnTable.removeAll(where: {name == $0})
        
        loadNewData(param: coinsOnTable)
        //此处是为了让 statusItem 的 button 刷新frame
        statusItem?.button?.image = NSImage(named: "StatusIcon")
        
        //保存用户设置
        prefered?.speakable = coinsNeedSpeech
        prefered?.barItems = coinsOnStatusBar
        prefered?.favs.removeAll(where: {name == $0.name})
        Common.saveUserPreference(object: prefered!)
    
    }
    
    // MARK: - 刷新列表所有币种
    @objc func refreshAllCoins() {
        loadNewData(param: coinsOnTable)
        
    }
    
    //请求数据
    private func loadNewData(param: [String]) {
        if receiver.socket != nil {
            receiver.socket.forceDisconnect()
        }
        
        receiver.requestCombinedStream(params: param) { receivedText in
            //处理每条stream数据
            self.handleStreamData(data: receivedText)
        } failure: {
            self.refreshAllCoins()
        }

    }
    
    private func handleStreamData(data: String) {
        print("Received data: \(data)")
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
    private var heartBeatCounter = 1
    @objc func updateButtonTitle(_ sender: AnyObject) {
        //刷新状态栏显示
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
        
        //对比实时价格与警报价格
        compareAlertPriceWithTheLatest()
        
        //计数，用于隔一定时间重新请求数据，防止断联
        heartBeatCounter += 1
        heartBeatCounter % 200 == 0 ? refreshAllCoins() : nil
    
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
    
// MARK: - 处理价格定期播报和邮件通知
    var speechTimer: Timer? = nil
    var task1: Task? = nil
    var task2: Task? = { closure in }
    
    lazy var isSpeechOpen: Bool = {
        return UserDefaults.standard.bool(forKey: "OPENSPEECH")
    }()
    
    lazy var isEmailOpen: Bool = {
        return UserDefaults.standard.bool(forKey: "NOTIFYBYEMAIL")
    }()
    
    //定时播报和发送邮件
    func prepareForSpeaking() {
        if coinsNeedSpeech.count == 0 {
            if speechTimer != nil {
                speechTimer!.invalidate()
                speechTimer = nil
            }
            print("计时器置空")
            return
        }
        
        print("执行预处理")
        var m3:[String]  = []
        var m5:[String]  = []
        var m15:[String] = []
        var m30:[String] = []
        var m60:[String] = []
        for c:Coin in coinsNeedSpeech {
            switch c.speakTimeInterval {
            case 180:
                m3.append(c.name)
            case 300:
                m5.append(c.name)
            case 900:
                m15.append(c.name)
            case 1800:
                m30.append(c.name)
            default:
                m60.append(c.name)
            }
        }
        
        let (m, s):(Int, Int) = Common.getMinute()
        
        var delayTime:Int = 0
        var interval:Int = 60
        if m60.count > 0 {
            delayTime = (60 - (m % 60) - 1)*60 + (60 - s)
            interval = 3600
        }
        if m30.count > 0 {
            delayTime = (30 - (m % 30) - 1)*60 + (60 - s)
            interval = 1800
        }
        if m15.count > 0 {
            delayTime = (15 - (m % 15) - 1)*60 + (60 - s)
            interval = 900
        }
        if m5.count > 0 {
            delayTime = (5 - (m % 5) - 1)*60 + (60 - s)
            interval = 300
        }
        if m3.count > 0 {
            delayTime = (3 - (m % 3) - 1)*60 + (60 - s)
            interval = 60
        }
        
        let names = [m3, m5, m15, m30, m60]
        if let timer = speechTimer {
            if timer.timeInterval == Double(interval) {
                return
            }
        }
        
        print("准备定时 --\(interval)")
        let timerTask: (()->())? = {
            if let timer = self.speechTimer {
                timer.invalidate()
                self.speechTimer = nil
            }
            self.speechTimer = Timer.scheduledTimer(timeInterval: TimeInterval(interval), target: self, selector: #selector(self.startSpeaking(_:)), userInfo: names, repeats: true)
            self.speechTimer?.fire()
            print("计时器已设定")
        }
        
        if task1 == nil && task2 != nil {
            GCDTool.cancel(task2)
            task2 = nil
            task1 = GCDTool.delay(TimeInterval(delayTime), task: timerTask!)
        } else
        if task2 == nil && task1 != nil {
            GCDTool.cancel(task1)
            task1 = nil
            task2 = GCDTool.delay(TimeInterval(delayTime), task: timerTask!)
        }
    }
    
    @objc func startSpeaking(_ sender: Timer) {
        let names = sender.userInfo as! [[String]]
        let (m, _):(Int, Int) = Common.getMinute()
        print("即将播报---\(names[0])--\(names[1])--\(names[2])--\(names[3])--\(names[4])")
        var speechText: String = ""
        var emailText: String = ""
        let extraText: String = ",最新价格为,"
        if m % 3 == 0 {
            speechText.append(makeSpeechString(array: names[0], extraWords: extraText))
            emailText.append(makeEmailString(array: names[0]))
        }
        if m % 5 == 0 {
            speechText.append(makeSpeechString(array: names[1], extraWords: extraText))
            emailText.append(makeEmailString(array: names[1]))
        }
        if m % 15 == 0 {
            speechText.append(makeSpeechString(array: names[2], extraWords: extraText))
            emailText.append(makeEmailString(array: names[2]))
        }
        if m % 30 == 0 {
            speechText.append(makeSpeechString(array: names[3], extraWords: extraText))
            emailText.append(makeEmailString(array: names[3]))
        }
        if m % 60 == 0 {
            speechText.append(makeSpeechString(array: names[4], extraWords: extraText))
            emailText.append(makeEmailString(array: names[4]))
        }
        
        if !speechText.isEmpty {
            if isSpeechOpen {
                let speaker = Speech()
                speaker.text = speechText
                speaker.play()
            }
            
            if isEmailOpen {
                let lines = emailText.split { $0.isNewline }
                if lines.count == 2 {
                    emailText = String(lines[1])
                } else
                if lines.count == 3 {
                    emailText = String(lines[1]) + " - - - - - - - - " + String(lines[2])
                } else
                if lines.count  > 3 {
                    emailText = String(lines[1]) + " - - - - - - - - " + String(lines[2]) + "\n\n" + emailText
                }
                Common.autoSendEmail(String(lines[0]), emailText)
            }
        }
    }
    
    private func makeSpeechString(array: [String], extraWords: String) -> String {
        var priceString: String = ""
        var speechString: String = ""
        array.forEach { name in
            if tickers[name] != nil {
                var n = name
                let priceStr = makeAttributedString(ticker: tickers[n]!)
                priceString = priceStr.string
                priceString.removeFirst()
                n.removeLast(4)
                let text = n.addBlank(per: 1) + extraWords + priceString + ". "
                speechString.append(text)
            }
            
        }
        return speechString
    }
    
    private func makeEmailString(array: [String]) -> String {
        var priceString: String = ""
        var emailString: String = ""
        array.forEach { name in
            if tickers[name] != nil {
                var n = name
                let priceStr = makeAttributedString(ticker: tickers[n]!)
                priceString = priceStr.string
                priceString.removeFirst()
                n.removeLast(4)
                let text = n + " 最新价格为: " + priceString + "\n"
                emailString.append(text)
            }
            
        }
        return emailString
    }
    
// MARK: - 处理价格警报
    func initializeAlertItems() {
        var actived: [Int:Alert] = [:]
        for (index, elm) in coinsPriceAlerts.enumerated() {
            if elm.onOff == "ON" {
                actived.updateValue(elm, forKey: index)
            }
        }
        activeAlerts = actived
    }
    
    var realSpeaker: Speech! = Speech()
    var audioPlayer: AVAudioPlayer!
    
    func compareAlertPriceWithTheLatest() {
        print("--12激活的：\(activeAlerts)")
        var triggered: [String] = []
        for (key,alert) in activeAlerts {
            if let ticker = tickers[alert.name], !alert.min.isEmpty, !alert.max.isEmpty {
                let min = Double(alert.min) ?? 0.0000
                let max = Double(alert.max) ?? 999999
                if min <= Double(ticker.c)!, Double(ticker.c)! <= max {
                    if audioPlayer != nil, audioPlayer.isPlaying {
                        print("--speech的值：\(realSpeaker.isSpeaking())")
                        return
                    } else {
                        triggered.append(alert.name)
                        var temp = coinsPriceAlerts
                        var a: Alert = temp[key]
                        a.onOff = "OFF"
                        temp[key] = a
                        activeAlerts.removeValue(forKey: key)
                        coinsPriceAlerts = temp
                        popoverVC.turnOffTriggeredAlert(at: key)
                        print("--12：到达预警价格！\(a.name)")
                        realSpeaker.text = makeSpeechString(array: triggered, extraWords: ",到达预警价格!")
                        realSpeaker.play()
                        playAudioAsset("LiFeLine")
                    }
                    
                }
            }
        }
    }
    
    func playAudioAsset(_ assetName : String) {
          guard let audioData = NSDataAsset(name: assetName)?.data else {
              fatalError("Unable to find asset \(assetName)")
          }

          do {
              audioPlayer = try AVAudioPlayer(data: audioData)
              audioPlayer.play()
              audioPlayer.numberOfLoops = 4
             
          } catch {
              fatalError(error.localizedDescription)
        }
    }
    
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
