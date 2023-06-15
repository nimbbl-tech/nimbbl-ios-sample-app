//
//  NimbblUpiSupport.swift
//  Nimbbl_SDK_2023
//
//  Created by Bushra on 25/05/23.
//

import Foundation
import UIKit

struct NimbblUpiSupport {
    
    let name: String
    let scheme: String
    
    var url: URL {
        
        let urlString = String(format: "%@://", self.scheme)
        let url = URL(string: urlString)!
        return url
    }
}


extension NimbblUpiSupport {
    
    static func getAllUPIApps() -> [NimbblUpiSupport] {
        
        return [NimbblUpiSupport(name: "GPay", scheme: "gpay"),
                NimbblUpiSupport(name: "Phone Pe", scheme: "phonepe"),
                NimbblUpiSupport(name: "Paytm", scheme: "paytmmp")]
    }
    
    static func getInstalledApps() -> [NimbblUpiSupport] {
        
        let apps: [NimbblUpiSupport] = getAllUPIApps().filter {
            
            if UIApplication.shared.canOpenURL($0.url) {
                return true
            } else {
                return false
            }
        }
        
        return apps
    }
}
