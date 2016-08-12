/*
 
 MenuKeyBindingManager.swift
 
 CotEditor
 https://coteditor.com
 
 Created by 1024jp on 2016-06-22.
 
 ------------------------------------------------------------------------------
 
 © 2004-2007 nakamuxu
 © 2014-2016 1024jp
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 
 */

import Cocoa

final class MenuKeyBindingManager: KeyBindingManager {
    
    // MARK: Public Properties
    
    static let shared = MenuKeyBindingManager()
    
    
    // MARK: Private Properties
    
    private let _defaultKeyBindingDict: [String: String]
    
    
    
    // MARK:
    // MARK: Lifecycle
    
    override private init() {
        
        guard let mainMenu = NSApp.mainMenu else {
            fatalError("MenuKeyBindingManager should be initialized after MainMenu.xib is loaded.")
        }
        
        _defaultKeyBindingDict = MenuKeyBindingManager.scanMenuKeyBindingRecurrently(menu: mainMenu)
        
        super.init()
    }
    
    
    
    // Key Binding Manager Methods
    
    /// name of file to save custom key bindings in the plist file form (without extension)
    override var settingFileName: String {
        
        return "MenuKeyBindings"
    }
    
    
    override var defaultKeyBindingDict: [String: String] {
        
        return _defaultKeyBindingDict
    }
    
    
    /// create a KVO-compatible dictionary for outlineView in preferences from the key binding setting
    /// - parameter usesDefaults:   `true` for default setting and `false` for the current setting
    override func outlineTree(defaults usesDefaults: Bool) -> [NSTreeNode] {
        
        return self.outlineTree(menu: NSApp.mainMenu!, defaults: usesDefaults)
    }
    
    
    /// save passed-in key binding settings
    override func saveKeyBindings(outlineTree: [NSTreeNode]) throws {
        
        try super.saveKeyBindings(outlineTree: outlineTree)
        
        // apply new settings to the menu
        self.applyKeyBindingsToMainMenu()
    }
    
    
    /// validate new key spec chars are settable
    override func validate(keySpecChars: String, oldKeySpecChars: String?) throws {
        
        do {
            try super.validate(keySpecChars: keySpecChars, oldKeySpecChars: oldKeySpecChars)
        }
        
        // command key existance check
        if !keySpecChars.contains(ModifierKey.command.keySpecChar) {  // "@"
            throw InvalidKeySpecCharactersError(kind: .lackingCommandKey, keySpecChars: keySpecChars)
        }
    }
    
    
    
    // Public Methods
    
    /// scan key bindings in main menu and store them as default values
    ///
    /// This method should be called before main menu is modified.
    func scanDefaultMenuKeyBindings() {
        
        // do nothing
        // -> Actually, `defaultMenuKeyBindings` is already scanned in `init`.
    }
    
    
    /// re-apply keyboard short cut to all menu items
    func applyKeyBindingsToMainMenu() {
        
        let mainMenu = NSApp.mainMenu!
        
        // at first, clear all current short cut sttings at first
        self.clearMenuKeyBindingRecurrently(menu: mainMenu)
        
        // then apply the latest settings
        self.applyMenuKeyBindingRecurrently(menu: mainMenu)
        mainMenu.update()
    }
    
    
    /// keyEquivalent and modifierMask for passed-in selector
    func shortcut(for action: Selector) -> Shortcut {
        
        let keySpecChars = self.keySpecChars(for: action, defaults: false)
        let shortcut = Shortcut(keySpecChars: keySpecChars)
        
        guard shortcut.modifierMask.contains(.command) else { return .none }
        
        return shortcut
    }
    
    
    
    // Public Methods

    /// return key bindings for selector
    private func keySpecChars(for action: Selector, defaults usesDefaults: Bool) -> String {
        
        let selectorString = NSStringFromSelector(action)
        let dict = usesDefaults ? self.defaultKeyBindingDict : self.keyBindingDict
        let definition = dict.first { (key, value) in value == selectorString }
        
        return definition?.key ?? ""
    }
    
    
    /// whether shortcut of menu item is allowed to modify
    private static func allowsModifying(_ menuItem: NSMenuItem) -> Bool {
        
        // specific item types
        if menuItem.isSeparatorItem ||
           menuItem.isAlternate ||
           menuItem.title.isEmpty {
            return false
        }
        
        // specific tags
        if let tag = MainMenu.MenuItemTag(rawValue: menuItem.tag) {
            switch tag {
            case .services,
                 .sharingService:
                return false
            default: break
            }
        }
        
        // specific selectors
        if let action = menuItem.action {
            switch action {
            case #selector(EncodingHolder.changeEncoding),
                 #selector(SyntaxHolder.changeSyntaxStyle),
                 #selector(ThemeHolder.changeTheme),
                 #selector(EditorWrapper.changeTabWidth),
                 #selector(EditorTextView.biggerFont),
                 #selector(EditorTextView.smallerFont),
                 #selector(ScriptManager.launchScript),
                 #selector(AppDelegate.openHelpAnchor),
                 #selector(NSWindow.makeKeyAndOrderFront),
                 #selector(NSApplication.orderFrontCharacterPalette):  // = "Emoji & Symbols"
                return false
            default: break
            }
        }
        
        return true
    }
    
    
    /// scan all key bindings as well as selector name in passed-in menu
    private class func scanMenuKeyBindingRecurrently(menu: NSMenu) -> [String: String] {
        
        var dictionary = [String: String]()
        
        for menuItem in menu.items {
            guard self.allowsModifying(menuItem) else { continue }
            
            if let submenu = menuItem.submenu {
                for (key, value) in self.scanMenuKeyBindingRecurrently(menu: submenu) {
                    dictionary[key] = value
                }
                
            } else {
                guard let action = menuItem.action else { continue }
                
                let key = Shortcut(modifierMask: menuItem.keyEquivalentModifierMask,
                                   keyEquivalent: menuItem.keyEquivalent).keySpecChars
                
                if !key.isEmpty {
                    dictionary[key] = NSStringFromSelector(action)
                }
            }
        }
        
        return dictionary
    }
    
    
    /// clear keyboard short cuts in the passed-in menu
    private func clearMenuKeyBindingRecurrently(menu: NSMenu) {
        
        for menuItem in menu.items {
            guard self.dynamicType.allowsModifying(menuItem) else { continue }
            
            if let submenu = menuItem.submenu {
                self.clearMenuKeyBindingRecurrently(menu: submenu)
                
            } else {
                menuItem.keyEquivalent = ""
                menuItem.keyEquivalentModifierMask = []
            }
        }
    }
    
    
    /// apply current keyboard short cut settings to the passed-in menu
    private func applyMenuKeyBindingRecurrently(menu: NSMenu) {
        
        for menuItem in menu.items {
            guard self.dynamicType.allowsModifying(menuItem) else { continue }
            
            if let submenu = menuItem.submenu {
                self.applyMenuKeyBindingRecurrently(menu: submenu)
                
            } else {
                guard let action = menuItem.action else { continue }
                
                let shortcut = self.shortcut(for: action)
                
                // apply only if keyEquivalent exists and the Command key is included
                if shortcut.modifierMask.contains(.command) {
                    menuItem.keyEquivalent = shortcut.keyEquivalent
                    menuItem.keyEquivalentModifierMask = shortcut.modifierMask
                }
            }
        }
    }
    
    
    /// read key bindings from the menu and create an array data for outlineView in preferences
    private func outlineTree(menu: NSMenu, defaults usesDefaults: Bool) -> [NSTreeNode] {
        
        var tree = [NamedTreeNode]()
        
        for menuItem in menu.items {
            guard self.dynamicType.allowsModifying(menuItem) else { continue }
            
            let node: NamedTreeNode
            if let submenu = menuItem.submenu {
                node = NamedTreeNode(name: menuItem.title, representedObject: nil)
                node.mutableChildren.addObjects(from: self.outlineTree(menu: submenu, defaults: usesDefaults))
                
            } else {
                guard let action = menuItem.action else { continue }
                
                let keySpecChars = usesDefaults
                    ? self.keySpecChars(for: action, defaults: true)
                    : Shortcut(modifierMask: menuItem.keyEquivalentModifierMask, keyEquivalent: menuItem.keyEquivalent).keySpecChars
                
                let item = KeyBindingItem(selector: NSStringFromSelector(action), keySpecChars: keySpecChars)
                node = NamedTreeNode(name: menuItem.title, representedObject: item)
            }
            tree.append(node)
        }
        
        return tree
    }
    
}