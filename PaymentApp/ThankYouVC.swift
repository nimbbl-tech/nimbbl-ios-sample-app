//
//  ThankYouVC.swift
//  PaymentApp
//
//  Created by Stany on 24/03/21.
//

import UIKit

class ThankYouVC: UIViewController {
    
    @IBOutlet weak var lblOrderId: UILabel!
    @IBOutlet weak var lblTrxId: UILabel!
    
    var orderid = ""
    var trxId = ""
    

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        lblOrderId.text = orderid
        lblTrxId.text = trxId
    }
    
    @IBAction func onBtnDoneAction(_ sender: Any) {
        let vc = storyboard?.instantiateViewController(withIdentifier: "ViewController") as! ViewController
        UIApplication.shared.keyWindow?.rootViewController = vc
        UIApplication.shared.keyWindow?.makeKeyAndVisible()
    }
    
    
}
