// Copyright 2016 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Cocoa


class Document: NSDocument {

    /*
    override var windowNibName: String? {
        // Override returning the nib file name of the document
        // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
        return "Document"
    }
    */
    
    var dispatcher: Dispatcher?
    var tabName: String?
    var editView: EditView?
    
    var filename: String? {
        didSet {
            if let filename = filename {
                let url = URL(fileURLWithPath: filename)
                let lastComponent = url.lastPathComponent;
                for controller in windowControllers {
                    controller.window?.title = lastComponent
                }
            }
        }
    }
    
    override init() {
        super.init()
        
        dispatcher = (NSApplication.shared().delegate as? AppDelegate)?.dispatcher
    }
    
    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: "Document Window Controller") as! NSWindowController
        tabName = Events.NewTab().dispatch(dispatcher!)
        let editViewController = windowController.contentViewController as? EditViewController
        editViewController?.editView.document = self
        self.editView = editViewController?.editView
        windowController.window?.delegate = editViewController
        //FIXME: some saner way of positioning new windows. maybe based on current window size, with some checks to not completely obscure an existing window?
        // also awareness of multiple screens (prefer to open on currently active screen)
        let screenHeight = windowController.window?.screen?.frame.height ?? 800
        let windowHeight: CGFloat = 800
        windowController.window?.setFrame(NSRect(x: 200, y: screenHeight - windowHeight - 200, width: 700, height: 800), display: true)

        if let filename = filename {
            open(filename)
        }

        self.addWindowController(windowController)
    }
    
    override func read(from url: URL, ofType typeName: String) throws {
        filename = url.path
    }
    
    override func save(to url: URL, ofType typeName: String, for saveOperation: NSSaveOperationType, completionHandler: @escaping (Error?) -> Void) {
        self.filename = url.path
        save(url.path)
        
        // An RPC Call received to indicate Save can be used to call this completion
        completionHandler(nil)
    }
    
    override func close() {
        super.close()
        
        guard let tabName = tabName
            else { return }

        Events.DeleteTab(tabId: tabName).dispatch(dispatcher!)
    }
    
    override var isEntireFileLoaded: Bool {
        return false
    }
    
    override class func autosavesInPlace() -> Bool {
        return false
    }

    fileprivate func open(_ filename: String) {
        sendRpcAsync("open", params: ["filename": filename])
    }
    
    fileprivate func save(_ filename: String) {
        sendRpcAsync("save", params: ["filename": filename])
    }
    
    
    func sendRpcAsync(_ method: String, params: Any) {
        let inner = ["method": method as AnyObject, "params": params, "tab": tabName! as AnyObject] as [String : Any]
        dispatcher?.coreConnection.sendRpcAsync("edit", params: inner)
    }
    
    func sendRpc(_ method: String, params: Any) -> Any? {
        let inner = ["method": method as AnyObject, "params": params, "tab": tabName! as AnyObject] as [String : Any]
        return dispatcher?.coreConnection.sendRpc("edit", params: inner)
    }
    
    func update(_ content: [String: AnyObject]) {
        for windowController in windowControllers {
            (windowController.contentViewController as? EditViewController)?.editView.updateSafe(update: content)
        }
    }

}