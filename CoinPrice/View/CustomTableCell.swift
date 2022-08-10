//
//  CustomTableCell.swift
//  CoinPrice
//
//  Created by Joey Young on 2022/4/29.
//

import Foundation
import AppKit

class InputTableCell: NSTableCellView {
    
    @IBOutlet weak var inputField: AlertTextField!
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
}

class AlertTextField: NSTextField {
    var aRow: Int?
    var aCol: Int?
    
    //通过nib创建的View 初始化走这个方法
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        let textCell = VerticallyCenteredTextFieldCell(textCell: "")
        textCell.isEditable = true
        textCell.drawsBackground = true
        textCell.usesSingleLineMode  = true
        textCell.backgroundColor = .darkGray
        textCell.alignment = .center
        textCell.textColor = .green
        textCell.font = .boldSystemFont(ofSize: 12)
        cell = textCell
        
    }
}

class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    override init(textCell string: String) {
        super.init(textCell: "")
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        // call super to get its original rect
        var rect = super.titleRect(forBounds: rect)
        // shift down a little so the draw rect is vertically centered in cell frame
        rect.origin.y += (rect.height - cellSize.height) / 2
//        rect.origin.y += (rect.height - cellSize.height) * 0.7
        // finally return the new rect
        return rect
    }
    
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        // call super and pass in our modified frame
        super.drawInterior(withFrame: titleRect(forBounds: cellFrame), in: controlView)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        // call super and pass in our modified frame
        super.select(withFrame: titleRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
}
