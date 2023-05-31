//
//  NimbblCheckout.swift
//  Nimbbl_SDK_2023
//
//  Created by Bushra on 25/05/23.
//

import Foundation
import UIKit
import Segment

let kitName = "iOS Kit"

@objc public protocol NimbblCheckoutDelegate: AnyObject {
    func onPaymentSuccess(_ response: [AnyHashable : Any])
    func onError(_ error: String)
}

@objc open class NimbblCheckout: NSObject {
    
    fileprivate var accessKey: String
    fileprivate var serviceURL: String
    fileprivate var paymentURL: String
    fileprivate var delegate: NimbblCheckoutDelegate
    @objc public var enableUATEnvironment: Bool = false
    
    @objc public init(accessKey: String,
                      serviceURL: String,
                      paymentURL: String,
                      delegate: NimbblCheckoutDelegate){
        self.accessKey = accessKey
        self.serviceURL = serviceURL
        self.paymentURL = paymentURL
        self.delegate = delegate
    }
    
    @objc public func show(options: [String:Any], displayController: UIViewController){
        let segmentKey = enableUATEnvironment ? "88Hwy5ego2sMQDMhE8LYiG0gmcGVANuR" : "1imBaXQkD7O287an3jSKTg9GP925HZgV"
        let configuration = AnalyticsConfiguration(writeKey: segmentKey)
        Analytics.setup(with: configuration)
        
        var initialData : [String : Any] = [:]
        initialData["order_id"] = options["order_id"]
        initialData["amount"] = options["amount"]
        initialData["merchant_id"] = options["merchant_id"]
        //initialData["merchant_name"] = ""
        initialData["kit_name"] = kitName
        //initialData["kit_version"] = ""
        
        Analytics.shared().track("Checkout Initialised", properties: initialData)
        
        var props = options
        props["accessKey"] = accessKey
        props["service_url"] = serviceURL
        props["payment_url"] = paymentURL
        let vc = NimbblCheckoutVC(options: props, delegate: self.delegate)
        vc.isUAT = enableUATEnvironment
        vc.modalPresentationStyle = .overFullScreen
        displayController.present(vc, animated: false, completion: nil)
    }
    
}
