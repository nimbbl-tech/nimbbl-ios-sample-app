//
//  NimbblCheckoutViewController.swift
//  NimbblCheckoutSDK
//
//  Created by Stany on 09/07/21.
//

import UIKit
import WebKit

final class NimbblCheckoutViewController: UIViewController {
    
    fileprivate let props: [String : Any]
    fileprivate let delegate: NimbblCheckoutDelegate
    
    fileprivate let webView = WKWebView()
    fileprivate var popupWebView: WKWebView?
    fileprivate var activityIndicator: UIActivityIndicatorView = UIActivityIndicatorView(style: .gray)
    
    var isUAT = false
    
    fileprivate var serviceUrl: String = ""
    fileprivate var paymentUrl: String = ""
    
    //MARK: init
    
    init(options: [String : Any], delegate: NimbblCheckoutDelegate) {
        self.props = options
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
        
        
        if isUAT {
            serviceUrl = "https://uatapi.nimbbl.tech/api/v2/"
            paymentUrl = "https://uatcheckout.nimbbl.tech/"
        }
        else{
            serviceUrl = "https://api.nimbbl.tech/api/v2/"
            paymentUrl = "https://checkout.nimbbl.tech/"
        }
        
        initViews()
        
        setWebView()
        
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
        webView.translatesAutoresizingMaskIntoConstraints = false
        
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
            if isUAT { print("observe url:", webView.url) }
            
            if let url = webView.url {
                
                if url.absoluteString.contains("\(paymentUrl)mobile/redirect?response="){
                    
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
                                catch{}
                            }
                        }

                    }

                    showError(message)
                    return
                }
            }
            
        }
    }
    
    //MARK:- API
    
    fileprivate func checkAccess(){
        
        let accessKey = props["accessKey"] as? String ?? ""
        
        let postData = ["access_key":accessKey,"domain_name":"iossdk.nimbbl.tech"]
        
        sendRequest(requestUrl: "\(serviceUrl)verify-access-key", requestType: "POST", requestData: postData){ result in
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
                    
                    self.showError(msg)
                }
                
                break
                
            case .failure(let error):
                self.showError(error)
                break
            }
        }
    }
    
    fileprivate func updateOrder(){
        
        let postData = ["callback_mode":"callback_mobile","callback_url":nil]
        
        let orderId = props["orderID"] as? String ?? ""
        
        sendRequest(requestUrl: "\(serviceUrl)update-order/\(orderId)", requestType: "PUT", requestData: postData ){ result in
            switch result {
            case .success( _):
                self.activityIndicator.stopAnimating()
                self.activityIndicator.isHidden = true
                let url = URL(string: "\(self.paymentUrl)?modal=false&order_id=" + orderId)
                let request = URLRequest(url: url!)
                self.webView.load(request)
                break
            case .failure(let error):
                self.showError(error)
                break
            }
        }
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

extension String : Error {
    
}
