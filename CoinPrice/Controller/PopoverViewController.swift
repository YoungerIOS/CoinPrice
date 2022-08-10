//
//  PopoverViewController.swift
//  CoinPrice
//
//  Created by rbcoder on 2021/9/22.
//

import Cocoa
import ServiceManagement

class PopoverViewController: NSViewController, NSTextFieldDelegate, NSControlTextEditingDelegate {

    @IBOutlet weak var add: NSButton!
    @IBOutlet weak var setting: NSPopUpButton!
    @IBOutlet weak var tips: NSTextField!
    @IBOutlet weak var search: SearchTextField!
    @IBOutlet var settingMenu: NSMenu!
    @IBOutlet weak var tableview: NSTableView!
    @IBOutlet var rowMenu: NSMenu!
    @IBOutlet weak var tableSwitch: NSButton!
    @IBOutlet weak var alertButton: NSButton!
    
    
    enum TableType {
        case main
        case love
        case alert
    }
    
    var presentTable: TableType = .main {
        willSet(nValue) {
            switch nValue {
            case .alert:
                let offImg = "speaker.fill"
                let altImg = "speaker.slash.fill"
                alertButton.state = stateBool ? .on : .off
                alertButton.image = NSImage.init(systemSymbolName: offImg, accessibilityDescription: nil)
                alertButton.alternateImage = NSImage.init(systemSymbolName: altImg, accessibilityDescription: nil)
                tableSwitch.state = .on
                tableview.selectionHighlightStyle = .none
            default:
                alertButton.state = .on
                alertButton.alternateImage = NSImage.init(systemSymbolName: "bell.fill", accessibilityDescription: nil)
            }
        }
    }
    
    var datasource: [String] = []
    
    var alerts: [Alert] = mainController.coinsPriceAlerts
    var stateBool: Bool = UserDefaults.standard.bool(forKey: "ALERTSOUNDMAINSWITCH")
    
    var timer: Timer? = nil
    var allowToUpdate: Bool = true
    
    var sortedTags: [Bool] = [false, false, false, false]
    let dragType = NSPasteboard.PasteboardType("tickers.data")

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //配置自选列表
        tableview.target = self
        tableview.delegate = self
        tableview.dataSource = self
        tableview.usesAlternatingRowBackgroundColors = true
        tableview.registerForDraggedTypes([dragType])
        tableview.draggingDestinationFeedbackStyle = .gap
        tableview.menu = rowMenu
        tableview.menu!.delegate = self
        let inputCell = NSNib.init(nibNamed: "InputTableCell", bundle: nil)
        tableview.register(inputCell, forIdentifier: NSUserInterfaceItemIdentifier(CellIdentifiers.MinMaxCell))
        datasource = mainController.coinsOnTable
        
        //搜索功能
        search.delegate = self
        search.bezelStyle = .roundedBezel
        search.focusRingType = .none
        search.target = self
        search.action = #selector(searchEnterKeyDownHandler(_:))
        
        //添加币种功能
        add.target = self
        add.action = #selector(addButtonHandler(_:))
        
        //切换列表
        tableSwitch.target = self
        tableSwitch.action = #selector(switchTableList(_:))
        tableSwitch.state = presentTable == .main ? .off : .on
        
        //预警列表
        alertButton.target = self
        alertButton.action = #selector(showAlertList(_:))
        
        //setting按钮功能
        //是否开机启动
        let config = UserDefaults.standard.bool(forKey: "launchAtStartup")
        setting.insertItem(withTitle: "开机时启动", at: 1)
        setting.item(at: 1)?.state = config ? .on : .off
        setting.item(at: 1)?.target  = self
        setting.item(at: 1)?.action = #selector(startupWhenLogin(_:))
        setupSettingButtonRightClick()
        
        //语音播报
        let speech = UserDefaults.standard.bool(forKey: "OPENSPEECH")
        setting.insertItem(withTitle: "语音播报", at: 2)
        setting.item(at: 2)?.state = speech ? .on : .off
        setting.item(at: 2)?.target  = self
        setting.item(at: 2)?.action = #selector(speechService(_:))
        
        //邮件通知
        let email = UserDefaults.standard.bool(forKey: "NOTIFYBYEMAIL")
        setting.insertItem(withTitle: "邮件通知", at: 3)
        setting.item(at: 3)?.state = email ? NSControl.StateValue.on : NSControl.StateValue.off
        setting.item(at: 3)?.target  = self
        setting.item(at: 3)?.action = #selector(sendPriceViaEmail(_:))
        
        //手动刷新
        setting.item(at: 4)?.target = self
        setting.item(at: 4)?.action = #selector(refreshTableManually(_:))
        
        //退出功能
        setting.item(at: 5)?.target = self
        setting.item(at: 5)?.action = #selector(quitButtonHandler(_:))
        
        //定期刷新数据显示
        timer = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(self.updateDataForTable(_:)), userInfo: nil, repeats: true)
        
    }
    
    override func viewWillDisappear() {
        tips.stringValue = ""
        search.stringValue = ""
        
    }
    
    //定期刷新列表数据
    @objc func updateDataForTable(_ sender: AnyObject) {
        if !allowToUpdate {
            return
        }
        
        DispatchQueue.main.async {
            self.tableview.reloadData()
        }
    }
    
// MARK: - 搜索框和各按钮点击事件
    @objc func searchEnterKeyDownHandler(_ sender: AnyObject) {
        if checkTheInput() {
            add.performClick(nil)
        }
    }
    
    //处理add按钮事件
    @objc func addButtonHandler(_ sender: AnyObject) {
        if checkTheInput() {
            
            mainController.addFavouriteCoin(name: search.stringValue) { success, message in
                DispatchQueue.main.async {
                    self.tips.stringValue = message
                    
                    if success {
                        self.alreadyAdded(moveTo: mainController.coinsOnTable.count-1)
                    }
                }
            }
        }
    }
    
    private func checkTheInput() -> Bool {
        if search.stringValue.count == 0 {
            return false
        }
        
        if mainController.coinsOnTable.contains(search.stringValue.uppercased()) {
            tips.stringValue = "您已经添加过此交易对!"
            if let index = mainController.coinsOnTable.firstIndex(of: search.stringValue.uppercased()) {
                alreadyAdded(moveTo: index)
            }
            
            return false
        }
        
        return true
    }
    
    //已添加 则转到该行
    private func alreadyAdded(moveTo row: Int) {
        presentTable = .main
        datasource = mainController.coinsOnTable
        tableview.reloadData()
        tableview.scrollRowToVisible(row)
        tableview.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
    }
    
    //处理setting按钮事件
    //配置右击刷新
    func setupSettingButtonRightClick() {
        let rClick = NSClickGestureRecognizer(target: self, action: #selector(refreshTableManually(_:)))
        rClick.buttonMask = 0x2 //左键代码 0x1 ，右键代码 0x2
        setting.addGestureRecognizer(rClick)
        
    }
    //退出
    @objc func quitButtonHandler(_ sender: AnyObject) {
        NSApplication.shared.terminate(self)
        
    }
    //刷新
    @objc func refreshTableManually(_ sender: AnyObject) {
        setting.startAnimtion()
        mainController.refreshAllCoins()
    }
    //邮件通知
    @objc func sendPriceViaEmail(_ sender: NSMenuItem) {
        let shouldSendEmail: Bool
        if sender.state == NSControl.StateValue.off {
            sender.state = NSControl.StateValue.on
            shouldSendEmail = true
        }else {
            sender.state = NSControl.StateValue.off
            shouldSendEmail = false
        }
        
        mainController.isEmailOpen = shouldSendEmail
        UserDefaults.standard.set(shouldSendEmail, forKey: "NOTIFYBYEMAIL")
        UserDefaults.standard.synchronize()
    }
    
    //语音播报
    @objc func speechService(_ sender: NSMenuItem) {
        let shouldSpeech: Bool
        if sender.state == NSControl.StateValue.off {
            sender.state = NSControl.StateValue.on
            shouldSpeech = true
        }else {
            sender.state = NSControl.StateValue.off
            shouldSpeech = false
        }
        mainController.isSpeechOpen = shouldSpeech
        UserDefaults.standard.set(shouldSpeech, forKey: "OPENSPEECH")
        UserDefaults.standard.synchronize()
    }
    
    //设置开机时启动
    @objc func startupWhenLogin(_ sender: NSMenuItem) {
        let shouldLaunch: Bool
        if sender.state == NSControl.StateValue.off {
            sender.state = NSControl.StateValue.on
            shouldLaunch = true
        }else {
            sender.state = NSControl.StateValue.off
            shouldLaunch = false
        }
        
        SMLoginItemSetEnabled("com.coinprice.MainAppHelper" as CFString, shouldLaunch)
        UserDefaults.standard.set(shouldLaunch, forKey: "launchAtStartup")
        UserDefaults.standard.synchronize()
    }
    
    //预警列表
    @objc func showAlertList(_ button: NSButton) {
        print("--00：\(button.state)")
        switch presentTable {
        case .alert:
            if let player = mainController.audioPlayer {
                if player.isPlaying {
                    player.stop()
                }
            }
            
            stateBool = !stateBool
            UserDefaults.standard.set(stateBool, forKey: "ALERTSOUNDMAINSWITCH")
            
//            let newAlerts =  alerts.map { alert -> Alert in
//                var a = alert
//                a.onOff = button.state == .on ? "ON" : "OFF"
//                return a
//            }
//            alerts = newAlerts
//            mainController.coinsPriceAlerts = alerts
//            tableview.reloadData()
        default:
            presentTable = .alert
            allowToUpdate = false
            tableview.reloadData()
            
        }
        
//        alertButton.state = computeAlertSwitchButtonState()
        
    }
    
    //警报总开关的显示状态
    func computeAlertSwitchButtonState() -> NSControl.StateValue {
        let result = alerts.filter({$0.onOff == "ON"})
        return result.count > 0 ? .on : .off
    }
    
    //切换列表
    @objc func switchTableList(_ sender: NSButton) {
        allowToUpdate = true
        
        if sender.state == .on {
            presentTable = .love
            datasource = mainController.coinsOnStatusBar
            tableview.reloadData()
        } else {
            presentTable = .main
            datasource = mainController.coinsOnTable
            tableview.reloadData()
        }
        
    }
    
}

// MARK: - 列表数据源和代理
extension PopoverViewController: NSTableViewDelegate, NSTableViewDataSource {
    
    fileprivate enum CellIdentifiers {
        static let NameCell = "NameCellID"
        static let PriceCell = "PriceCellID"
        static let ChangeCell = "ChangeCellID"
        static let PercentCell = "PercentCellID"
        static let MinMaxCell = "MinMaxCellID"
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        switch presentTable {
        case .alert:
            return alerts.count
        default:
            return datasource.count
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if presentTable == .main || presentTable == .love {
            var text: NSAttributedString = NSAttributedString(string: "")
            var cellIdentifier: String = ""
            
            //拿到模型中的数据存到item中
            let item = datasource[row]
            guard let ticker = mainController.tickers[item] else { return nil }
            
            tableColumn?.headerCell.alignment = .center
            
            //判断所在列
            switch tableColumn {
            case tableview.tableColumns[0]:
                let font = NSFont.boldSystemFont(ofSize: 12)
                text = NSAttributedString(string: item, attributes: [.font: font])
                cellIdentifier = CellIdentifiers.NameCell
                tableColumn?.headerCell.alignment = .left
                
            case tableview.tableColumns[1]:
                tableColumn?.title = "Price"
                text = makeAttributedString(column: 1, ticker: ticker)
                cellIdentifier = CellIdentifiers.PriceCell
                
            case tableview.tableColumns[2]:
                tableColumn?.title = "Change"
                text = makeAttributedString(column: 2, ticker: ticker)
                cellIdentifier = CellIdentifiers.ChangeCell
                
            case tableview.tableColumns[3]:
                tableColumn?.title = "%"
                text = makeAttributedString(column: 3, ticker: ticker)
                cellIdentifier = CellIdentifiers.PercentCell
                
            default:
                break
            }
            
            //这个方法通过identifier来创建或复用一个cell，然后使用之前提供的数据来填充它
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
                //tips:
                //attributedString的字体,颜色,对齐方式等属性应该在其attributes中设置
                cell.textField?.attributedStringValue = text
                cell.textField?.usesSingleLineMode  = true
                cell.textField?.isEditable = false
                if let switcher = cell.subviews.first(where: {$0 is NSSwitch}) {
                    cell.textField?.isHidden = false
                    switcher.isHidden = true
                }
                
                return cell
            }
            
        } else
        if presentTable == .alert {
            var cellIdentifier: String = ""
            let item = alerts[row] as Alert

            
            tableColumn?.headerCell.alignment = .center
            switch tableColumn {
            case tableview.tableColumns[0]:
                let font = NSFont.boldSystemFont(ofSize: 12)
                let text = NSAttributedString(string: item.name, attributes: [.font: font])
                cellIdentifier = CellIdentifiers.NameCell
                tableColumn?.headerCell.alignment = .left
                
                if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
                    cell.textField?.attributedStringValue = text
                    cell.textField?.usesSingleLineMode  = true
                    cell.textField?.isEditable = false
                    return cell
                }
                
            case tableview.tableColumns[1]:
                cellIdentifier = CellIdentifiers.MinMaxCell
                tableColumn?.title = "Min"
//                text = attributedAlertString(number: item.min)
//                let frame = NSRect(x: 0, y: 0, width: 76, height: 18)
//                let cell = InputTableCell(frame: frame)
//                cell.textField?.stringValue = "000000"
                return makeViewForInputCell(cellId: cellIdentifier, column: 1, value: item.min)
                
            case tableview.tableColumns[2]:
                cellIdentifier = CellIdentifiers.MinMaxCell
                tableColumn?.title = "Max"
//                text = attributedAlertString(number: item.max)
                return makeViewForInputCell(cellId: cellIdentifier, column: 2, value: item.max)
                
            case tableview.tableColumns[3]:
                cellIdentifier = CellIdentifiers.PercentCell
                tableColumn?.title = "On/Off"
                
                if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
                    let switcher: AlertSwitch = AlertSwitch.init(frame: CGRect(x: 4, y: 1, width: 44, height: 23), originalState: item.onOff == "ON" ? .on : .off)
                    switcher.aRow = row
                    switcher.target = self
                    switcher.action = #selector(alertSwitchWasClicked(_:))
                    cell.subviews.removeAll(where: {$0 is NSSwitch})
                    cell.addSubview(switcher)
                    cell.textField?.isHidden = true
                    return cell
                }
                
            default:
                break
            }
            
            func makeViewForInputCell(cellId: String, column: Int, value: String) -> InputTableCell? {
                if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellId), owner: self) as? InputTableCell {
//                    let inputField: AlertTextField = AlertTextField.init(frame: CGRect(x: 0, y: 3, width: cell.textField?.frame.size.width ?? 75, height: 18))
//                    inputField.stringValue = value
//                    inputField.usesSingleLineMode  = true
//                    inputField.alignment = .center
//                    inputField.isEditable = true
//                    inputField.drawsBackground = true
//                    inputField.backgroundColor = .darkGray
//                    inputField.font = .boldSystemFont(ofSize: 12)
//                    inputField.textColor = .green
//
//                    inputField.delegate = self
//                    inputField.aRow = row
//                    inputField.aCol = column
//                    cell.addSubview(inputField)
//                    cell.textField?.isHidden = true
                    
                    cell.inputField.stringValue = value

                    cell.inputField.delegate = self
                    cell.inputField.aRow = row
                    cell.inputField.aCol = column

                    return cell
                }
                return nil
            }
            
        }
    
        return nil
    }
    
    //点击列头排序
    func tableView(_ tableView: NSTableView, mouseDownInHeaderOf tableColumn: NSTableColumn) {
        guard presentTable == .main else { return }
        
        switch tableColumn {
        case tableview.tableColumns[0]:
            let tag = sortedTags[0]
            sortedTags = [!tag, false, false ,false]
            if sortedTags[0] {
                datasource = datasource.sorted(by: {$0 < $1})
            }else {
                datasource = datasource.sorted(by: {$0 > $1})
            }
        case tableview.tableColumns[1]:
            let tag = sortedTags[1]
            sortedTags = [false, !tag, false ,false]
            var dic: [(key: String, value: Ticker)]
            var keys: [String]
            if sortedTags[1] {
                dic = mainController.tickers.sorted(by: {Float($0.1.c) ?? 0 > Float($1.1.c) ?? 0})
            }else {
                dic = mainController.tickers.sorted(by: {Float($0.1.c) ?? 0 < Float($1.1.c) ?? 0})
            }
            keys = dic.map { (key: String, value: Ticker) in
                return key
            }
            datasource = keys
        case tableview.tableColumns[2]:
            let tag = sortedTags[2]
            sortedTags = [false, false, !tag ,false]
            var dic: [(key: String, value: Ticker)]
            var keys: [String]
            if sortedTags[2] {
                dic = mainController.tickers.sorted(by: {Float($0.1.p) ?? 0 > Float($1.1.p) ?? 0})
            }else {
                dic = mainController.tickers.sorted(by: {Float($0.1.p) ?? 0 < Float($1.1.p) ?? 0})
            }
            keys = dic.map { (key: String, value: Ticker) in
                return key
            }
            datasource = keys
            
        case tableview.tableColumns[3]:
            let tag = sortedTags[3]
            sortedTags = [false, false, false ,!tag]
            var dic: [(key: String, value: Ticker)]
            var keys: [String]
            if sortedTags[3] {
                dic = mainController.tickers.sorted(by: {Float($0.1.P) ?? 0 > Float($1.1.P) ?? 0})
            }else {
                dic = mainController.tickers.sorted(by: {Float($0.1.P) ?? 0 < Float($1.1.P) ?? 0})
            }
            keys = dic.map { (key: String, value: Ticker) in
                return key
            }
            datasource = keys
            
        default:
            break
        }
        
        tableView.reloadData()
    }
    
    //拖拽排序
    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        do {
            let indexes  = rowIndexes.compactMap({NSNumber(integerLiteral: $0)})
            let data = try NSKeyedArchiver.archivedData(withRootObject: indexes, requiringSecureCoding: false)
            let item = NSPasteboardItem()
            item.setData(data, forType: dragType)
            pboard.writeObjects([item])
            
            return true
        } catch {
            return false
        }
        
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        guard let source = info.draggingSource as? NSTableView, source == tableView else {
            return []
        }
        if dropOperation == .above || dropOperation == .on {
            return .move
        }
        return []
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
            let pb = info.draggingPasteboard
            if let itemData = pb.pasteboardItems?.first?.data(forType: dragType),
               let indexes = try? NSKeyedUnarchiver.unarchivedArrayOfObjects(ofClass: NSNumber.self, from: itemData) as? [Int] {
                
                for index in indexes {
                    guard index < datasource.count, row < datasource.count else {
                        continue
                    }
                    (datasource[index], datasource[row]) = (datasource[row], datasource[index])
                    tableView.moveRow(at: index, to: row)
                }
                
                if presentTable == .love {
                    //保存数据源,防止切换另一列表再切回时row顺序复原
                    mainController.coinsOnStatusBar = datasource
                    //保存用户操作
                    mainController.prefered?.barItems = mainController.coinsOnStatusBar
                    Common.saveUserPreference(object: mainController.prefered!)
                }else
                if presentTable == .main {
                    mainController.coinsOnTable = datasource
                    if var favs = mainController.prefered?.favs  {
                        for index in indexes {
                            guard index < favs.count, row < favs.count else {
                                continue
                            }
                            (favs[index], favs[row]) = (favs[row], favs[index])
                        }
                        mainController.prefered?.favs = favs
                        Common.saveUserPreference(object: mainController.prefered!)
                    }
                }
                
                return true
            }
            return false
        }
    
    // MARK: - 警报页面的TextField的Delegate实现，以及Switch按钮事件处理
    func controlTextDidEndEditing(_ obj: Notification) {
        if let textField: AlertTextField = obj.object as? AlertTextField {
            print("--4：\(String(describing: textField.aRow))--\(String(describing: textField.aCol))")
            var alert: Alert = alerts[textField.aRow!]
            switch textField.aCol {
            case 1:
                if textField.stringValue.isEmpty {
                    textField.stringValue = "0.0000"
                }
                alert.min = textField.stringValue
            case 2:
                if textField.stringValue.isEmpty {
                    textField.stringValue = "999999"
                }
                alert.max = textField.stringValue
            default:
                break
            }
            alerts[textField.aRow!] = alert
            mainController.coinsPriceAlerts = alerts
            
        }else {
            return
        }
    }
    
    func controlTextDidChange(_ obj: Notification) {
        if let textfield = obj.object as? AlertTextField {
            var stringValue = textfield.stringValue
            
            // First step : Only '1234567890.' - @Clifton Labrum solution
            let charSet = NSCharacterSet(charactersIn: "1234567890.").inverted
            let chars = stringValue.components(separatedBy: charSet)
            stringValue = chars.joined()

            // Second step : only one '.'
            let comma = NSCharacterSet(charactersIn: ".")
            let chuncks = stringValue.components(separatedBy: comma as CharacterSet)
            switch chuncks.count {
            case 0:
                stringValue = ""
            case 1:
                stringValue = "\(chuncks[0])"
            default:
                stringValue = "\(chuncks[0]).\(chuncks[1])"
            }

            // replace string
            textfield.stringValue = stringValue

        }
    }
    
    @objc func alertSwitchWasClicked(_ button: AlertSwitch) {
        var alert: Alert = alerts[button.aRow!]
        alert.onOff = button.state == .on ? "ON" : "OFF"
        alerts[button.aRow!] = alert
        mainController.coinsPriceAlerts = alerts
        
        alertButton.state = computeAlertSwitchButtonState()
        
    }
    
    public func turnOffTriggeredAlert(at row:Int) {
        var alert: Alert = alerts[row]
        alert.onOff = "OFF"
        alerts[row] = alert
        if presentTable == .alert {
            tableview.reloadData()
        }
    }
    
    private func attributedAlertString(number: String) -> NSMutableAttributedString {
        let redColor = NSColor.init(red: 220/255, green: 20/255, blue: 60/255, alpha: 1)
        let titleParagraphStyle = NSMutableParagraphStyle()
        titleParagraphStyle.alignment = .center
        
        let numberString = NSMutableAttributedString(string: number,
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 13),
                .paragraphStyle: titleParagraphStyle,
                .foregroundColor: redColor
            ])
        
        return numberString
    }
    
    private func makeAttributedString(column: Int, ticker: Ticker) -> NSMutableAttributedString {
        
        var number = ""
        switch column {
        case 1:
            number = ticker.c
        case 2:
            number = ticker.p
        case 3:
            number = ticker.P
        default:
            break
        }
        
        if let cc = Float(number) {
            if column == 3 {
                number = String(format: "%.2f%@", cc, "%")
            }else {
                switch abs(cc) {
                case 10... :
                    number = String(format: "%.2f", cc)
                case 1..<10 :
                    number = String(format: "%.3f", cc)
                case 0.0001..<1 :
                    number = String(format: "%.4f", cc)
                case 0..<0.0001 :
                    number = String(format: "%.6f", cc)
                default:
                    break
                }
            }
        }
        
        let redColor = NSColor.init(red: 220/255, green: 20/255, blue: 60/255, alpha: 1)
        let greenColor = NSColor.init(red: 50/255, green: 205/255, blue: 50/255, alpha: 1)
        let titleParagraphStyle = NSMutableParagraphStyle()
        titleParagraphStyle.alignment = .right
        
        let numberString = NSMutableAttributedString(string: number,
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 13),
                .paragraphStyle: titleParagraphStyle,
                .foregroundColor: Double(ticker.p) ?? 0 >= 0 ? greenColor : redColor
            ])
        
        
        return numberString
    }
}

// MARK: - 列表每行右键菜单代理
extension PopoverViewController: NSMenuDelegate {
    var speechSubMenu: NSMenu {
        let menu = NSMenu()
        let titles = [3, 5, 15, 30, 60]
        for n in 0...4 {
            var title = "\(titles[n])分钟"
            if n == 4 { title = "1小时"}
            let i = NSMenuItem(title: title, action: #selector(TimingToSpeech), keyEquivalent: "")
            i.tag = n
            i.state = NSControl.StateValue.off
            i.onStateImage = NSImage(named: "NSMenuOnStateTemplate")
            menu.addItem(i)
        }
        return menu
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if tableview.clickedRow == -1 {
            return
        }else {
            switch presentTable {
                case .main, .love:
                    //是否在状态栏显示
                    let item1 = NSMenuItem(title: "在状态栏显示", action: #selector(hideOrShowOnStatusBar), keyEquivalent: "")
                    let name = datasource[tableview.clickedRow]
                    if mainController.coinsOnStatusBar.contains(name) {
                        item1.state = NSControl.StateValue.on
                        item1.onStateImage = NSImage(named: "NSMenuOnStateTemplate")
                    }else {
                        item1.state = NSControl.StateValue.off
                    }
                    menu.addItem(item1)
                    
                    //定时播报
                    let item2 = NSMenuItem()
                    item2.title = "定时播报"
                    
                    let subMenu = speechSubMenu
                    var interval = 0.0
                    for c:Coin in mainController.coinsNeedSpeech {
                        if c.name == datasource[tableview.clickedRow] {
                            interval = c.speakTimeInterval
                        }
                    }
                    let itemIndex = [3, 5, 15, 30, 60].firstIndex(of: interval/60)
                    if itemIndex != nil {
                        if let i = subMenu.item(at: itemIndex!) {
                            i.state = NSControl.StateValue.on
                        }
                    }
                    
                    print("打印发音数组：\(mainController.coinsNeedSpeech)")

                    item2.submenu = subMenu
                    menu.addItem(item2)
                    
                    //价格预警
                    menu.addItem(withTitle: "添加警报", action: #selector(addPriceAlert), keyEquivalent: "")
                    
                    //删除
                    menu.addItem(withTitle: "删除", action: #selector(deleteCoinFromTable), keyEquivalent: "")
                case .alert:
                    //删除
                    menu.addItem(withTitle: "删除", action: #selector(deletePriceAlert), keyEquivalent: "")
            
            }
            
        }
        
    }
    
    @objc func hideOrShowOnStatusBar(_ sender: NSMenuItem) {
        sender.state = sender.state == NSControl.StateValue.off ? NSControl.StateValue.on : NSControl.StateValue.off
        
        //获取当前点击的行,得到币种名称
        let coinName = datasource[tableview.clickedRow]
        if sender.state == NSControl.StateValue.on {
            
            if !mainController.coinsOnStatusBar.contains(coinName) {
                //添加到状态栏数组
                mainController.coinsOnStatusBar.append(coinName)
                //保存用户的修改
                mainController.prefered?.barItems  = mainController.coinsOnStatusBar
                Common.saveUserPreference(object: mainController.prefered!)
                
            }
            
        }else {
            if mainController.coinsOnStatusBar.contains(coinName) {
                mainController.coinsOnStatusBar.removeAll(where: {coinName.contains($0)})
                mainController.prefered?.barItems = mainController.coinsOnStatusBar
                Common.saveUserPreference(object: mainController.prefered!)
                
                //如果此时展示的是状态栏详情列表,应当从列表中删除此行
                if presentTable == .love {
                    datasource = mainController.coinsOnStatusBar
                    tableview.reloadData()
                }
                
            }
            
            //此处是为了让 statusItem 的 button 刷新frame
            mainController.statusItem?.button?.image = NSImage(named: "StatusIcon")
        }
        
    }
    
    @objc func TimingToSpeech(_ sender: NSMenuItem) {
        let interval:Double = [3, 5, 15, 30, 60][sender.tag]
        //获取当前点击的行,得到币种名称
        let name = datasource[tableview.clickedRow]
        
        if !mainController.coinsNeedSpeech.contains(where: {$0.name == name}) {
            //走这里说明所选币种还未开启播报
            sender.state = NSControl.StateValue.on
            //添加到播报数组
            mainController.coinsNeedSpeech.append(Coin.init(name: name, speakTimeInterval: interval*60))
        } else {
            //走这里说明所选币种已经开启播报，用户可 修改播报间隔 或 取消播报
            sender.state = sender.state == NSControl.StateValue.off ? NSControl.StateValue.on : NSControl.StateValue.off
            if sender.state == NSControl.StateValue.on {
                //修改播报间隔
                guard mainController.coinsNeedSpeech.count >= 1 else { return }
                for c in 0..<mainController.coinsNeedSpeech.count {
                    if mainController.coinsNeedSpeech[c].name == name {
                        mainController.coinsNeedSpeech[c].speakTimeInterval = interval*60
                    }
                }
            }else {
                //取消播报
                mainController.coinsNeedSpeech.removeAll(where: {$0.name == name})
            }
            
        }
        
        //保存用户的修改
        mainController.prefered?.speakable  = mainController.coinsNeedSpeech
        Common.saveUserPreference(object: mainController.prefered!)
        
        //执行语音播报计划
        mainController.prepareForSpeaking()
    }
    
    @objc func deleteCoinFromTable() {
        let coinName = datasource[tableview.clickedRow]
        datasource.remove(at: tableview.clickedRow)
        tableview.reloadData()
        mainController.deleteFavouriteCoin(name: coinName)
    }
    
    @objc func addPriceAlert() {
        presentTable = .alert
        allowToUpdate = false
        let coinName = datasource[tableview.clickedRow]
        let alert = Alert.init(name: coinName, min: "", max: "", onOff: "ON")
        alerts.append(alert)
        self.tableview.reloadData()
        
        mainController.coinsPriceAlerts = alerts
        
    }
    
    @objc func deletePriceAlert() {
        alerts.remove(at: tableview.clickedRow)
        tableview.reloadData()
        mainController.coinsPriceAlerts = alerts
    }
    
}

extension PopoverViewController {
    static func freshController() -> PopoverViewController {
        //获取Main.storyboard引用
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let storyboardId = NSStoryboard.SceneIdentifier("PopoverViewController")
        
        guard let viewController = storyboard.instantiateController(withIdentifier: storyboardId) as? PopoverViewController else
        {
            fatalError("Something Wrong with Main.storyboard")
            
        }
        
        return viewController
    }
    
}

class SearchTextField: NSTextField {
    
    override func textDidChange(_ notification: Notification) {
        let pop = self.delegate as! PopoverViewController
        guard pop.presentTable != .alert else {
            return
        }
        print("--00：\(pop.presentTable)")
        pop.allowToUpdate = false
        pop.tips.stringValue = ""
        print("--0011：\(pop.presentTable)")
        let characters = pop.search.stringValue.uppercased()
        if characters.count >= 1 {
            //1. 过滤出所有包含了输入框内字符row
            let arr1 = pop.datasource.filter({$0.contains(characters)})
            if arr1.count > 0 {
                //2. 先隐藏所有row
                pop.tableview.hideRows(at: IndexSet(integersIn: 0..<pop.datasource.count), withAnimation: .slideUp)
                
                //3. 将过滤出的元素的下标保存在新数组中
                let arr2: [Int] = arr1.map({pop.datasource.firstIndex(of: $0)!})
                
                //4.对过滤出的row取消隐藏,并滑到和选中
                pop.tableview.unhideRows(at: IndexSet(arr2), withAnimation: .slideUp)
                pop.tableview.scrollRowToVisible(arr2.first ?? 0)
                pop.tableview.selectRowIndexes(IndexSet(arr2), byExtendingSelection: false)
                
                return

            }
        }
        
        pop.allowToUpdate = true
        
    }
}

class AlertSwitch: NSSwitch {
    var aRow: Int?
    
    required init(frame: NSRect, originalState: NSControl.StateValue) {
            super.init(frame: frame)
            self.state = originalState
        }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
