//
//  NimbblCheckoutVC.swift
//  Nimbbl_SDK_2023
//
//  Created by Bushra on 22/05/23.
//

import UIKit
import WebKit
import Segment
import SafariServices

final class NimbblCheckoutVC: UIViewController {
    
    // Listeners
    fileprivate let upiListener = "upiListener"
    
    fileprivate let props: [String : Any]
    fileprivate let delegate: NimbblCheckoutDelegate
    
    fileprivate let webView = WKWebView()
    fileprivate var popupWebView: WKWebView?
    fileprivate var activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView()
    
    var isUAT = false
    var isUPIInjected = false
    
    fileprivate var serviceUrl: String = ""
    fileprivate var paymentUrl: String = ""
    
    fileprivate var orderData: [String:Any]!
    
    //MARK: init
    
    init(options: [String : Any], delegate: NimbblCheckoutDelegate) {
        self.props = options
        self.serviceUrl = self.props["service_url"] as? String ?? "https://api.nimbbl.tech/api/v2/"
        self.paymentUrl = self.props["payment_url"] as? String ?? "https://checkout.nimbbl.tech/"
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK:- Design
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        //        if isUAT {
        ////            print("Options:", props)
        //                        serviceUrl = "https://uatapi.nimbbl.tech/api/v2/"
        //                        paymentUrl = "https://uatcheckout.nimbbl.tech/"
        ////            serviceUrl = "https://devapi.nimbbl.tech/api/v2/"
        ////            paymentUrl = "https://devcheckout.nimbbl.tech/"
        //        } else {
        //            serviceUrl = "https://api.nimbbl.tech/api/v2/"
        //            paymentUrl = "https://checkout.nimbbl.tech/"
        //        }
        
        initViews()
        
        setWebView()
    //activityIndicatorStyle: .gray
        if #available(iOS 13.0, *) {
              //Note:- `medium` and `large` are only available after iOS 13.0
              activityIndicator = UIActivityIndicatorView(style: .large)
           } else {
              activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
           }

        activityIndicator.startAnimating()
        
        checkAccess()
    }
    
    fileprivate func initViews(){
        view.backgroundColor = .black
        
        view.addSubview(webView)
        view.addSubview(activityIndicator)
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        let width = view.frame.width / 2
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            activityIndicator.heightAnchor.constraint(equalToConstant: width),
            activityIndicator.widthAnchor.constraint(equalToConstant: width)
        ])
        
    }
    
    
    fileprivate func setWebView(){
        
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true
        webView.configuration.preferences = preferences
        webView.configuration.userContentController.add(self, name: upiListener)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.addObserver(self, forKeyPath: "URL", options: .new, context: nil)
        
        let safeAreaLayout = self.view.safeAreaLayoutGuide
        
        NSLayoutConstraint(item: webView, attribute: .leading, relatedBy: .equal, toItem: safeAreaLayout, attribute: .leading, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: webView, attribute: .trailing, relatedBy: .equal, toItem: safeAreaLayout, attribute: .trailing, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: webView, attribute: .top, relatedBy: .equal, toItem: safeAreaLayout, attribute: .top, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: webView, attribute: .bottom, relatedBy: .equal, toItem: safeAreaLayout, attribute: .bottom, multiplier: 1.0, constant: 0).isActive = true
    }
    
    fileprivate func showError(_ error: String){
        self.dismiss(animated: false, completion: {
            self.delegate.onError(error)
        })
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(WKWebView.url) {
            // Whenever URL changes, it can be accessed via WKWebView instance
            if isUAT { print("observe url:", webView.url as Any) }
            
            if let url = webView.url {
                //commented by bushra
                let tempPayUrl = "\(paymentUrl)mobile/redirect?response="
                if url.absoluteString.contains(tempPayUrl){
                    
                    var message = "Invalid payment response"
                    
                    if let components = URLComponents(string: url.absoluteString){
                        if let items = components.queryItems{
                            if let response = items[0].value {
                                let decodeData = Data(base64Encoded: response)
                                do {
                                    let jsonData = try JSONSerialization.jsonObject(with: decodeData!, options: .allowFragments) as? [String : Any] ?? [:]
                                    if isUAT { print("Nimbbl response: ", jsonData) }
                                    
                                    let payload = jsonData["payload"] as? [String : Any] ?? [:]
                                    
                                    let status = payload["status"] as? String ?? ""
                                    
                                    var initialData : [String : Any] = [:]
                                    initialData["order_id"] = payload["order_id"]
                                    initialData["amount"] = props["amount"]
                                    initialData["merchant_id"] = props["merchant_id"]
                                    initialData["status"] = status
                                    initialData["kit_name"] = kitName
                                    initialData["transaction_id"] = payload["transaction_id"]
                                    
                                    Analytics.shared().track("Response Received", properties: initialData)
                                    
                                    if status.lowercased() == "success" {
                                        self.dismiss(animated: false, completion: {
                                            self.delegate.onPaymentSuccess(payload)
                                        })
                                        return
                                    }
                                    else if let reason = payload["reason"] as? String{
                                        message = reason
                                    }
                                }
                                catch{
                                    debugPrint("Catch block: \(error.localizedDescription)")
                                }
                            }
                        }
                        
                    }
                    
                    showError(message)
                    return
                }
            }
        }
    }
    
    fileprivate func trackEvent(_ eventName: String){
        var initialData : [String : Any] = [:]
        initialData["order_id"] = orderData["order_id"]
        initialData["amount"] = orderData["total_amount"]
        initialData["merchant_id"] = orderData["sub_merchant_id"]
        // initialData["merchant_name"] = ""
        initialData["kit_name"] = kitName
        //initialData["kit_version"] = ""
        
        Analytics.shared().track(eventName, properties: initialData)
    }
    
    //MARK:- API
    
    fileprivate func checkAccess(){
        
        let url = "\(serviceUrl)verify-access-key"
        
        let accessKey = props["accessKey"] as? String ?? ""
        
        let postData = ["access_key":accessKey,"domain_name":"demo.nimbbl.tech"]
        //        let postData = ["access_key":accessKey,"domain_name":"devdemo.nimbbl.tech"]
        
        if isUAT {
            print("Url", url)
            print("Body", postData)
        }
        
        
        sendRequest(requestUrl: url, requestType: "POST", requestData: postData){ result in
            switch result {
            case .success(let data):
                let access_key_allowed = data["access_key_allowed"] as? Bool ?? false
                let domain_name_allowed = data["domain_name_allowed"] as? Bool ?? false
                
                if access_key_allowed && domain_name_allowed {
                    self.updateOrder()
                }
                else {
                    let error = data["error"] as? [String:Any] ?? [:]
                    
                    var msg = "Access not allowed"
                    
                    if let message = error[""] as? String {
                        msg = message
                    }
                    
                    self.showError("Verify api: \(msg)")
                }
                
                break
                
            case .failure(let error):
                self.showError(error)
                break
            }
        }
    }
    
    fileprivate func updateOrder(){
        
        let orderId = props["order_id"] as? String ?? ""
        let url = "\(serviceUrl)update-order/\(orderId)"
        
        let postData = ["callback_mode":"callback_mobile","callback_url":nil]
        
        if isUAT {
            print("Url", url)
            print("Body", postData)
        }
        
        sendRequest(requestUrl: url, requestType: "PUT", requestData: postData ){ result in
            switch result {
            case .success(let data):
                if self.isUAT { print("Update Response:\n", data) }
                
                self.orderData = data
                
                self.activityIndicator.stopAnimating()
                self.activityIndicator.isHidden = true
                let urlStr = "\(self.paymentUrl)?modal=false&order_id=" + orderId
                let url = URL(string: urlStr)
                //                self.openSafari(urlString : "\(self.paymentUrl)?modal=false&order_id=" + orderId)
                let request = URLRequest(url: url!)
                self.webView.load(request)

                self.trackEvent("Checkout Launched")
                break
            case .failure(let error):
                self.showError(error)
                break
            }
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
         let request = navigationAction.request
         if let host = navigationAction.request.url?.host {
             if host == "checkout.nimbbl.tech" {
                 if let headers = request.allHTTPHeaderFields {
                     print("Header Fields: \(headers)")
                 } else {
                     print("Nope, sir")
                 }
             }
         }
         decisionHandler(.allow)
     }
    
    func openSafari(urlString : String){
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            return
        }
        let safariViewController = SFSafariViewController(url: url, configuration: config)
        present(safariViewController, animated: true, completion: nil)
    }
    
    fileprivate func sendRequest(requestUrl: String, requestType: String, requestData: Any, completionHandler: @escaping (Result<[String:Any], String>) -> Void){
        let postData: Data = try! JSONSerialization.data(withJSONObject: requestData, options: .prettyPrinted)
        var request = URLRequest(url: URL(string: requestUrl)!)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = requestType
        request.httpBody = postData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            
            if error != nil{
                let errStr = String(describing: error)
                DispatchQueue.main.async {
                    completionHandler(.failure(errStr))
                }
                return
            }
            if let httpResponse = response as? HTTPURLResponse{
                if 200...299 ~= httpResponse.statusCode {
                    print(String(data: data!, encoding: .utf8)!)
                    do{
                        let jsonData = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? [String : Any] ?? [:]
                        DispatchQueue.main.async {
                            completionHandler(.success(jsonData))
                        }
                    }
                    catch {
                        DispatchQueue.main.async {
                            completionHandler(.failure("Invalid response"))
                        }
                    }
                    return
                }
            }
            DispatchQueue.main.async {
                completionHandler(.failure("Invalid response"))
            }
            return
        }
        task.resume()
    }
}

extension NimbblCheckoutVC: WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        configuration.setValue(true, forKey: "_allowUniversalAccessFromFileURLs")
        popupWebView = WKWebView(frame: view.bounds, configuration: configuration)
        popupWebView!.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        popupWebView!.navigationDelegate = self
        popupWebView!.uiDelegate = self
        view.addSubview(popupWebView!)
        self.trackEvent("Payment Intermediate Opened")
        return popupWebView!
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        webView.removeFromSuperview()
        popupWebView = nil
        self.trackEvent("Payment Intermediate Closed")
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        //        print(message.body)
        //        let dict = message.body as? Dictionary<String, String>
        //        print(dict)
        
        if message.name == upiListener,
           let upiString = message.body as? String {
            self.handleUPIEvent(upiString)
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        //        webView.evaluateJavaScript(self.getJSForUPIApps(), completionHandler: { (_ , _) in
        //
        //        })
    }
}

// MARK: UPI Listener
extension NimbblCheckoutVC {
    //By Bushra: updated to resolve non optional value error
    func handleUPIEvent(_ string: String) {
        if let data = string.data(using: .utf8){
            do {
                if let dictionary = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [String : String] {
                    let url = dictionary["url"]
                    let packagename = dictionary["packagename"]
                    let updateURL = url!.replacingOccurrences(of: "upi:/", with: "upi")
                    let urlStringWithScheme = String(format: "%@://%@", packagename!, updateURL)
                    
                    if let intentURL = URL(string: urlStringWithScheme) {
                        openIntent(intentURL)
                    }
                }
            }catch {
                print("JSON serialization failed")
            }
        }
    }
    
    func openIntent(_ url: URL) {
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

extension String : Error {
    
}

// MARK: JS to inject
extension NimbblCheckoutVC {
    
    func getJSForUPIApps() -> String {
        
        let upiApps = NimbblUpiSupport.getInstalledApps()
        let appsString: [String] = upiApps.map { String(format: "{\\\"name\\\" : \\\"%@\\\", \\\"packagename\\\" : \\\"%@\\\"}", $0.name, $0.scheme) }
        let jsonString = String(format: "{\\\"UPIApps\\\" : [%@]}", appsString.joined(separator: ","))
        return String(format: "javascript:nimbbl_web.UPIIntentAvailable(\"%@\")", jsonString)
    }
}

