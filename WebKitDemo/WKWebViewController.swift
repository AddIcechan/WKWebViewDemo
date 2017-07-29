//
//  WKWebViewController.swift
//  WebKitDemo
//
//  Created by ADDICE on 2017/7/25.
//  Copyright © 2017年 ADDICE. All rights reserved.
//

import UIKit
import WebKit

enum MessageHandlerNames: String {
    case test = "Test"
}

enum MessageActions: String {
    case test = "test"
}

class WKWebViewController: UIViewController {

    var wkWeb : WKWebView?
    var config : WKWebViewConfiguration?
    
    let userController = WKUserContentController()
    
    var urlStr : String = ""
    
    deinit {
        userController.removeScriptMessageHandler(forName: MessageHandlerNames.test.rawValue)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "WKWebViewController"
        
        // 确定 页面进行适配，等同于 html 中的 <meta name="viewport" content="width=device-width">
        let jsToScaleFit = "var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta);"
        
        let scaleToFitScript = WKUserScript(source: jsToScaleFit, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        
        userController.addUserScript(scaleToFitScript)
        
        // 资料显示，下面这句代码会造成 内存泄漏
        userController.add(self, name: MessageHandlerNames.test.rawValue)
        
        config = WKWebViewConfiguration()
        config?.userContentController = userController
        
        config?.userContentController.add(self, name: "test")
        
        wkWeb = WKWebView(frame: view.bounds, configuration: config!)
        wkWeb?.backgroundColor = .yellow
        wkWeb?.navigationDelegate = self
        wkWeb?.uiDelegate = self
        view.addSubview(wkWeb!)
        
        if urlStr.isEmpty {
            if let filePath = Bundle.main.path(forResource: "WKWebViewController", ofType: "html") {
                let url = URL(fileURLWithPath: filePath)
                wkWeb?.loadFileURL(url, allowingReadAccessTo: url)
            }
        } else {
            let url = URL(string: urlStr)
            wkWeb?.load(URLRequest(url: url!))
        }
        
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
}

extension WKWebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        guard let name = MessageHandlerNames(rawValue: message.name) else {
            return
        }
        
        switch name {
        case .test:
            /*
               网页代码： 爸爸约定俗成的。呐。看下面。很长喔。
             ------- 我是引用 ---------
             /*! @abstract Adds a script message handler.
             @param scriptMessageHandler The message handler to add.
             @param name The name of the message handler.
             @discussion Adding a scriptMessageHandler adds a function
             window.webkit.messageHandlers.<name>.postMessage(<messageBody>) for all
             frames.
             */
             open func add(_ scriptMessageHandler: WKScriptMessageHandler, name: String)
             -------- 我是引用 ---------
              所以 你懂的
     
             window.webkit.messageHandlers.Test.postMessage(message);
             
             message 类型没有规定，字符串也行， json 对象也行
             
                 比较 推荐 postMessage 里面的参数是 一个 协定好的 JSON ，比如
             { action: "xxx",
             params: {xx:xxx},
             callback: "addNum()" 比如 "addNum()"。如果遇到需要传参，那么可以 addNum(*),然后去把 "(*)" 替换成 "(实际参数)"
             }
            */
            print(message.body)
            if let dict = message.body as? [String: Any] {
                print(dict)
                guard let actionStr = dict["action"] as? String,
                    let action = MessageActions(rawValue: actionStr) else {
                    return
                }
                
                switch action {
                    case .test:
                        if let params = dict["params"] as? [String: Any] {
                            print(params)
                        }
                        
                        if let callback = dict["callback"] as? String {
                            // e.g. addNum(*) -> addNum(1000)
                            let newCallBack = callback.replacingOccurrences(of: "(*)", with: "(300)")
                            
                            wkWeb?.evaluateJavaScript(newCallBack, completionHandler: { (data, error) in
                                print(error?.localizedDescription ?? "执行正确")
                            })
                        }
                }
                
            }
        }
    }
}

extension WKWebViewController: WKNavigationDelegate {
    
    // 1、接受网页信息，决定是否加载还是取消。必须执行肥调 decisionHandler 。逃逸闭包的属性
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // 可进行 一些网页 点击的判断
        print("\(#function)")
        let request = navigationAction.request
        
        if let url = request.url {
            // 1、app store 跳转
            if url.host == "itunes.apple.com" {
                UIApplication.shared.openURL(url)
                decisionHandler(.cancel)
            } else {
                // 2、检测打开 <a href> 标签 。如果要打开一个 新web，那么需要 <a href="xx" target="_blank" >，若无 target="_blank"，则只会在原web基础上 reload
                if navigationAction.targetFrame == nil {
                    let _ = navigationAction.request
                    // 这里做 push 新的 webview 操作
                    let newWkWebView = WKWebViewController()
                    newWkWebView.urlStr = navigationAction.request.url?.absoluteString ?? ""
                    navigationController?.pushViewController(newWkWebView, animated: true)
                    
                    
                }
                decisionHandler(.allow)
            }
        }
    }
    
    // 2、开始加载
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("\(#function)")
    }
    
    // 3、接受到网页 response 后, 可以根据 statusCode 决定是否 继续加载。allow or cancel
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        print("\(#function)")
        guard let httpResponse = navigationResponse.response as? HTTPURLResponse else {
            decisionHandler(.allow)
            return
        }
        
        let policy : WKNavigationResponsePolicy = httpResponse.statusCode == 200 ? .allow : .cancel
        decisionHandler(policy)
        
    }
    
    // 4、加载成功
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("\(#function)")
        // 设置 网页 title
        title = webView.title
    }
    
    // 4、加载失败
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("\(#function)")
        print(error.localizedDescription)
    }
    
}

extension WKWebViewController: WKUIDelegate {
    // MARK: alert
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: "这是本地代码弹窗", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ok", style: .cancel, handler: { _ in
            // 必须加入这个 肥调，不然会闪 （逃
            completionHandler()
        }))
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: comfirm
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: "这是本地代码弹窗", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "❤️", style: .default, handler: { _ in
            completionHandler(true)
        }))
        alert.addAction(UIAlertAction(title: "不❤️", style: .default, handler: { _ in
            completionHandler(false)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    // MARK: prompt
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        
        let alert = UIAlertController(title: "这是本地代码弹窗", message: prompt, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = defaultText
        }
        alert.addAction(UIAlertAction(title: "ok", style: .default, handler: { _ in
            completionHandler(alert.textFields?.last?.text)
        }))
        present(alert, animated: true, completion: nil)
        
    }
}
