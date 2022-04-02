//
//  ViewController.swift
//  PaymentApp
//
//  Created by Stany on 12/03/21.
//

import UIKit
import NimbblCheckoutSDK
import MBProgressHUD

typealias JSONObject = Dictionary<String,Any>

class ViewController: UIViewController, NimbblCheckoutDelegate {
    
    @IBOutlet weak var tblProducts: UITableView!
    
    var arrProducts = [ProductModal]()
    var environment: Setting.Environment = .dev
    
    fileprivate var nimbblChekout: NimbblCheckout!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        // access_key_1MwvMkKkweorz0ry
        initializeNimbblSDK()
        
        for i in 1...2{
            
            let title = i == 1 ? "Colourful Mandalas" : "Designer Triangles."
            let desc = i == 1 ? "Convert your dreary device into a bright happy place with this wallpaper by Speedy McVroom" : "Bold blue and deep black triangle designer wallpaper to give your device a hypnotic effect by  chenspec from Pixabay"
            let amount = i == 1 ? "2" : "4"
            
            let product = ProductModal(productId: i, title: title, desc: desc, amount: amount)
            arrProducts.append(product)
            
        }
        
        tblProducts.dataSource = self
        tblProducts.delegate = self
        
    }
    
    func initializeNimbblSDK() {
        
        nimbblChekout = NimbblCheckout(accessKey: Setting.accessKey,
                                       serviceURL: environment.apiURL,
                                       paymentURL: environment.paymentURL,
                                       delegate: self)
        //        nimbblChekout.enableUATEnvironment = true
    }
    
    fileprivate func openPaymentScreen(orderId: String) {
        let options = ["order_id": orderId]
        nimbblChekout.show(options: options, displayController: self)
    }
    
    @objc func createOrderAction(sender: UIButton){
        
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud.label.text = "Loading ..."
        hud.mode = .indeterminate
        
        let product = arrProducts[sender.tag]
        let parameters = "{ \"product_id\": \(product.productId) }"
        let postData = parameters.data(using: .utf8)

        let urlString = String(format: "%@orders/create", environment.baseURL)
        var request = URLRequest(url: URL(string: urlString)!)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = postData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
          guard let data = data else {
            print("API Error:",String(describing: error))
            return
          }
          print(String(data: data, encoding: .utf8)!)
            do{
                let jsonData = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? JSONObject ?? [:]
                guard let result = jsonData["result"] as? JSONObject else { return }
                
                let status = result["success"] as? Bool ?? false
                
                if status {
                    guard let item = result["item"] as? JSONObject else { return }
                    guard let orderId = item["order_id"] as? String else { return }
                    
                    DispatchQueue.main.async {
                        hud.hide(animated: true)
                        self.openPaymentScreen(orderId: orderId)
                    }
                }
            }
            catch {
                print("Error while parsing")
            }
         
        }

        task.resume()
    }
    
    func onPaymentSuccess(_ response: [AnyHashable : Any]) {
       
        let vc = storyboard?.instantiateViewController(withIdentifier: "ThankYouVC") as! ThankYouVC
        vc.orderid = response["order_id"] as? String ?? ""
        vc.trxId = response["transaction_id"] as? String ?? ""
        UIApplication.shared.keyWindow?.rootViewController = vc
        UIApplication.shared.keyWindow?.makeKeyAndVisible()
        
    }
   
    func onError(_ error: String) {
        print("Error:- ",error)
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return arrProducts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "product", for: indexPath) as! ProductTVC
        cell.populateData(product: arrProducts[indexPath.row])
        cell.mBtnBuyNow.tag = indexPath.row
        cell.mBtnBuyNow.addTarget(self, action: #selector(createOrderAction(sender:)), for: .touchUpInside)
        return cell
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard segue.identifier == "SETTIING_SEGUE" else { return }
        
        if let destinationController = segue.destination as? SettingsViewController {
            destinationController.currentEnvironment = environment
            destinationController.delegate = self
        }
    }
    
}

extension ViewController: SettingsViewControllerDelegate {
    
    func environmentChanged(_ environment: Setting.Environment) {
        self.environment = environment
        initializeNimbblSDK()
    }
}

class ProductTVC: UITableViewCell {
    
    @IBOutlet weak var imgProduct: UIImageView!
    
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblDesc: UILabel!
    @IBOutlet weak var lblAmount: UILabel!
    
    @IBOutlet weak var mViContent: UIView!
    
    @IBOutlet weak var mBtnBuyNow: UIButton!
    
    override func awakeFromNib() {
        mViContent.layer.cornerRadius = 10.0
        mViContent.layer.masksToBounds = true
    }
    
    func populateData(product: ProductModal){
        imgProduct.image = UIImage(named: "product_\(product.productId)")
        lblTitle.text = product.title
        lblDesc.text = product.desc
        lblAmount.text = "₹ \(product.amount)"
    }
    
}

struct ProductModal {
    let productId : Int
    let title: String
    let desc: String
    let amount: String
}
