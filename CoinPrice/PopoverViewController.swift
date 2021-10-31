//
//  PopoverViewController.swift
//  CoinPrice
//
//  Created by rbcoder on 2021/9/22.
//

import Cocoa
import ServiceManagement

class PopoverViewController: NSViewController, NSTextFieldDelegate {

    @IBOutlet weak var add: NSButton!
    @IBOutlet weak var setting: NSPopUpButton!
    @IBOutlet weak var tips: NSTextField!
    @IBOutlet weak var search: TextField!
    @IBOutlet var settingMenu: NSMenu!
    @IBOutlet weak var tableview: NSTableView!
    @IBOutlet var rowMenu: NSMenu!
    
    var timer: Timer? = nil
    var allowToUpdate: Bool = true
    var datasource: [String] = []
    
    var sortedTags: [Bool] = [false, false, false, false]
    let dragType = NSPasteboard.PasteboardType("tickers.data")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //配置自选列表
        tableview.target = self
        tableview.delegate = self
        tableview.dataSource = self
        tableview.menu = rowMenu
        rowMenu.delegate = self
        tableview.usesAlternatingRowBackgroundColors = true
        tableview.registerForDraggedTypes([dragType])
        tableview.draggingDestinationFeedbackStyle = .gap
        datasource = barButton.coinsOnTable
        
        //搜索功能
        search.delegate = self
        search.bezelStyle = .roundedBezel
        search.focusRingType = .none
        search.target = self
        search.action = #selector(searchEnterKeyDownHandler(_:))
        
        //添加币种功能
        add.target = self
        add.action = #selector(addButtonHandler(_:))
        
        
        //setting按钮功能
        //状态栏详情
        setting.insertItem(withTitle: "状态栏详情", at: 1)
        setting.item(at: 1)?.state = NSControl.StateValue.off
        setting.item(at: 1)?.target  = self
        setting.item(at: 1)?.action = #selector(statusBarDetail(_:))
        
        //是否开机启动
        let config = UserDefaults.standard.bool(forKey: "launchAtStartup")
        setting.insertItem(withTitle: "开机时启动", at: 2)
        setting.item(at: 2)?.state = config ? NSControl.StateValue.on : NSControl.StateValue.off
        setting.item(at: 2)?.target  = self
        setting.item(at: 2)?.action = #selector(startupWhenLogin(_:))
        
        //手动刷新
        setting.item(at: 3)?.target = self
        setting.item(at: 3)?.action = #selector(refreshTableManually(_:))
        
        //退出功能
        setting.item(at: 4)?.target = self
        setting.item(at: 4)?.action = #selector(quitButtonHandler(_:))
        
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
    
// MARK: - 处理搜索框和各按钮点击事件
    @objc func searchEnterKeyDownHandler(_ sender: AnyObject) {
        if checkTheInput() {
            add.performClick(nil)
        }
    }
    
    //处理add按钮事件
    @objc func addButtonHandler(_ sender: AnyObject) {
        if checkTheInput() {
            
            barButton.addFavouriteCoin(name: search.stringValue) { success, message in
                DispatchQueue.main.async {
                    self.tips.stringValue = message
                    
                    if success {
                        self.alreadyAdded(moveTo: barButton.coinsOnTable.count-1)
                    }
                }
            }
        }
    }
    
    private func checkTheInput() -> Bool {
        if search.stringValue.count == 0 {
            return false
        }
        
        if barButton.coinsOnTable.contains(search.stringValue.uppercased()) {
            tips.stringValue = "您已经添加过此交易对!"
            if let index = barButton.coinsOnTable.firstIndex(of: search.stringValue.uppercased()) {
                alreadyAdded(moveTo: index)
            }
            
            return false
        }
        
        return true
    }
    
    //已添加 则转到该行
    private func alreadyAdded(moveTo row: Int) {
        datasource = barButton.coinsOnTable
        tableview.reloadData()
        tableview.scrollRowToVisible(row)
        tableview.selectRowIndexes(IndexSet([row]), byExtendingSelection: false)
        
        let state = setting.item(at: 1)?.state
        if state == NSControl.StateValue.on {
            setting.item(at: 1)?.state = NSControl.StateValue.off
        }
    }
    //处理setting按钮事件
    //退出
    @objc func quitButtonHandler(_ sender: AnyObject) {
        NSApplication.shared.terminate(self)
        
    }
    //刷新
    @objc func refreshTableManually(_ sender: AnyObject) {
        barButton.refreshAllCoins()
    }
    
    //设置开机时启动
    @objc func startupWhenLogin(_ sender: NSMenuItem) {
        let shouldLaunch = sender.state == NSControl.StateValue.off
        if shouldLaunch {
            sender.state = NSControl.StateValue.on
        }else {
            sender.state = NSControl.StateValue.off
        }
        
        SMLoginItemSetEnabled("com.coinprice.MainAppHelper" as CFString, shouldLaunch)
        UserDefaults.standard.set(shouldLaunch, forKey: "launchAtStartup")
        
    }

    //状态栏详情
    @objc func statusBarDetail(_ sender: NSMenuItem) {
        sender.state = sender.state == NSControl.StateValue.off ? NSControl.StateValue.on : NSControl.StateValue.off
        if sender.state == NSControl.StateValue.on {
            datasource = barButton.coinsOnStatusBar
            tableview.reloadData()
        }else {
            datasource = barButton.coinsOnTable
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
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return datasource.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    
        var text: NSAttributedString = NSAttributedString(string: "")
        var cellIdentifier: String = ""
        
        //拿到模型中的数据存到item中
        let item = datasource[row]
        guard let ticker = barButton.tickers[item] else { return nil }
        
        //判断所在列
        switch tableColumn {
        case tableview.tableColumns[0]:
            let font = NSFont.boldSystemFont(ofSize: 12)
            text = NSAttributedString(string: item, attributes: [.font: font])
            cellIdentifier = CellIdentifiers.NameCell
            
        case tableview.tableColumns[1]:
            text = makeAttributedString(column: 1, ticker: ticker)
            cellIdentifier = CellIdentifiers.PriceCell
            
        case tableview.tableColumns[2]:
            text = makeAttributedString(column: 2, ticker: ticker)
            cellIdentifier = CellIdentifiers.ChangeCell
            
        case tableview.tableColumns[3]:
            text = makeAttributedString(column: 3, ticker: ticker)
            cellIdentifier = CellIdentifiers.PercentCell
            
        default:
            break
        }

        tableColumn?.headerCell.alignment = .center
        
        //调用 makeView(withIdentifier:owner:) 来得到一个cell。
        //这个方法通过那个identifier来创建或复用一个cell，然后使用之前提供的数据来填充它
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            //tips:
            //attributedString的字体,颜色,对齐方式等属性应该在其attributes中设置
            cell.textField?.attributedStringValue = text
            cell.textField?.usesSingleLineMode  = true
            
            return cell
        }
        
        return nil
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
    
    //点击列头排序
    func tableView(_ tableView: NSTableView, mouseDownInHeaderOf tableColumn: NSTableColumn) {
        guard setting.item(at: 1)?.state == NSControl.StateValue.off else { return }
        
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
                dic = barButton.tickers.sorted(by: {Float($0.1.c) ?? 0 > Float($1.1.c) ?? 0})
            }else {
                dic = barButton.tickers.sorted(by: {Float($0.1.c) ?? 0 < Float($1.1.c) ?? 0})
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
                dic = barButton.tickers.sorted(by: {Float($0.1.p) ?? 0 > Float($1.1.p) ?? 0})
            }else {
                dic = barButton.tickers.sorted(by: {Float($0.1.p) ?? 0 < Float($1.1.p) ?? 0})
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
                dic = barButton.tickers.sorted(by: {Float($0.1.P) ?? 0 > Float($1.1.P) ?? 0})
            }else {
                dic = barButton.tickers.sorted(by: {Float($0.1.P) ?? 0 < Float($1.1.P) ?? 0})
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
                    (datasource[index], datasource[row]) = (datasource[row], datasource[index])
                    tableView.moveRow(at: index, to: row)
                }
                
                let state = self.setting.item(at: 1)?.state
                if state == NSControl.StateValue.on {
                    //保存数据源,防止切换另一列表再切回时row顺序复原
                    barButton.coinsOnStatusBar = datasource
                    //保存用户操作
                    barButton.prefered?.barItems = barButton.coinsOnStatusBar
                    Common.saveUserPreference(object: barButton.prefered!)
                }else {
                    barButton.coinsOnTable = datasource
                    if var favs = barButton.prefered?.favs  {
                        for index in indexes {
                            (favs[index], favs[row]) = (favs[row], favs[index])
                        }
                        barButton.prefered?.favs = favs
                        Common.saveUserPreference(object: barButton.prefered!)
                    }
                }
                
                return true
            }
            return false
        }
    
    
}

// MARK: - 列表每行右键菜单代理
extension PopoverViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if tableview.clickedRow == -1 {
            return
        }else {
            let item1 = NSMenuItem(title: "在状态栏显示", action: #selector(hideOrShowOnStatusBar), keyEquivalent: "")
            let name = datasource[tableview.clickedRow]
            if barButton.coinsOnStatusBar.contains(name) {
                item1.state = NSControl.StateValue.on
                item1.onStateImage = NSImage(named: "NSMenuOnStateTemplate")
            }else {
                item1.state = NSControl.StateValue.off
            }
            menu.addItem(item1)

            menu.addItem(withTitle: "删除", action: #selector(deleteFromTable), keyEquivalent: "")
        }
        
    }
    
    @objc func hideOrShowOnStatusBar(_ sender: NSMenuItem) {
        sender.state = sender.state == NSControl.StateValue.off ? NSControl.StateValue.on : NSControl.StateValue.off
        
        //获取当前点击的行,得到币种名称
        let coinName = datasource[tableview.clickedRow]
        if sender.state == NSControl.StateValue.on {
            if !barButton.coinsOnStatusBar.contains(coinName) {
                //添加到状态栏数组
                barButton.coinsOnStatusBar.append(coinName)
                //保存用户的修改
                barButton.prefered?.barItems  = barButton.coinsOnStatusBar
                Common.saveUserPreference(object: barButton.prefered!)
                
            }
            
        }else {
            if barButton.coinsOnStatusBar.contains(coinName) {
                barButton.coinsOnStatusBar.removeAll(where: {coinName.contains($0)})
                barButton.prefered?.barItems = barButton.coinsOnStatusBar
                Common.saveUserPreference(object: barButton.prefered!)
                
                //如果此时展示的是状态栏详情列表,应当从列表中删除此行
                let state = self.setting.item(at: 1)?.state
                if state == NSControl.StateValue.on {
                    datasource = barButton.coinsOnStatusBar
                    tableview.reloadData()
                }
                
            }
            
            //此处是为了让 statusItem 的 button 刷新frame
            barButton.statusItem?.button?.image = NSImage(named: "StatusIcon")
        }
        
    }
    
    @objc func deleteFromTable() {
        let coinName = datasource[tableview.clickedRow]
        datasource.remove(at: tableview.clickedRow)
        tableview.reloadData()
        barButton.deleteFavouriteCoin(name: coinName)
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

class TextField: NSTextField {
    override func textDidChange(_ notification: Notification) {
        let pop = self.delegate as! PopoverViewController
        pop.allowToUpdate = false
        pop.tips.stringValue = ""
        
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
