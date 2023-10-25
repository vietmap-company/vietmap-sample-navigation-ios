import UIKit
import SearchTextField
import CoreLocation


class ViewController: UIViewController, UITableViewDataSource {
    // MARK: - IBOutlets
    @IBOutlet weak var resultTableView: UITableView!
    @IBOutlet weak var searchLocation: SearchTextField!
    
    let url = "https://maps.vietmap.vn/api"
    let keySearch = Bundle.main.object(forInfoDictionaryKey: "VietMapAccessToken") as! String
    
    // MARK: Properties
    
    var responseSearch: [Response]?

    // MARK: Directions Request Handlers

    var alertController: UIAlertController!
    
    var tableViewData = Array(repeating: "", count: 0)
    
    let manager = CLLocationManager()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configSearch()
        let textAttributes = [NSAttributedString.Key.foregroundColor:UIColor.systemBlue]
        navigationController?.navigationBar.titleTextAttributes = textAttributes
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { _,_ in
                DispatchQueue.main.async {
                    // request location here
//                    CLLocationManager().requestWhenInUseAuthorization()
                    self.manager.requestWhenInUseAuthorization()
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        resultTableView.register(UITableViewCell.self,
                              forCellReuseIdentifier: "TableViewCell")
        resultTableView.dataSource = self
    }
    
    func showLoading() {
        let alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)

        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = UIActivityIndicatorView.Style.medium
        loadingIndicator.startAnimating();

        alert.view.addSubview(loadingIndicator)
        present(alert, animated: true, completion: nil)
    }
    
    func hideLoading() {
        dismiss(animated: false, completion: nil)
    }
    
    @objc func backButtonTapped() {
        searchLocation.resignFirstResponder()
    }
    
    func configSearch() {
        searchLocation.delegate = self
        searchLocation.theme.fontColor = UIColor.white
        searchLocation.theme.subtitleFontColor = UIColor.white
        searchLocation.theme.font = UIFont.systemFont(ofSize: 16)
        searchLocation.theme.separatorColor = UIColor (red: 0.9, green: 0.9, blue: 0.9, alpha: 0.5)
        searchLocation.theme.bgColor = hexStringToUIColor(hex: "#4d4d4d")
        searchLocation.theme.cellHeight = 50
        searchLocation.highlightAttributes = [NSAttributedString.Key.backgroundColor: UIColor.gray, NSAttributedString.Key.font:UIFont.boldSystemFont(ofSize: 16)]
        searchLocation.startVisible = true
        searchLocation.forceNoFiltering = true

        // add sub button
        searchLocation.clearButtonMode = .whileEditing
        searchLocation.tintColor = UIColor.white
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "arrow.backward"), for: .normal)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        searchLocation.leftView = backButton
        searchLocation.leftViewMode = .whileEditing

        // handle with route
        searchLocation.itemSelectionHandler = { filteredResults, itemPosition in
            self.showLoading()
            // Just in case you need the item position
            let item = filteredResults[itemPosition]
            // Do whatever you want with the picked item
            self.searchLocation.text = item.title
            self.loadLatLong(self.responseSearch?[itemPosition].refID ?? "") { results in
                if results != nil {
                    // handle select item search
                    self.searchLocation.hideResultsList()
                    self.refresh(data: results!)
                }
                self.hideLoading()
            }
            self.searchLocation.keyboardIsShowing = false
            self.view.endEditing(true)
        }
        
        searchLocation.userStoppedTypingHandler = {
            if let location = self.searchLocation.text {
                // Show the loading indicator
                if location.count > 1 {
                    self.searchLocation.showLoadingIndicator()
                    
                    self.loadLocation(location) { results in
                        self.searchLocation.filterItems(results)
                        self.searchLocation.stopLoadingIndicator()
                    }
                }
            }
        } as (() -> Void)
    }

    @objc func didSwipe(swipe: UISwipeGestureRecognizer) {
    }
    
    func hexStringToUIColor (hex:String) -> UIColor {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }

        if ((cString.count) != 6) {
            return UIColor.gray
        }

        var rgbValue:UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
    
    // MARK: Autocomplete
    fileprivate func loadLocation(_ location: String, callback: @escaping ((_ results: [SearchTextFieldItem]) -> Void)) {
        let userLocation: CLLocationCoordinate2D? = manager.location?.coordinate
        var urlString = "\(url)/autocomplete/v3?apikey=\(keySearch)&text=\(location)"
        if let latlongLocation = userLocation {
            urlString += "&focus=\(latlongLocation.latitude),\(latlongLocation.longitude)"
        }
        print(urlString)
        let search = urlString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
        let url = URL(string:search!)

        if let url = url {
            let task = URLSession.shared.dataTask(with: url, completionHandler: {(data, response, error) in
                do {
                    if let data = data {
                        let decoder = JSONDecoder()
                        self.responseSearch = try decoder.decode([Response].self, from: data)
                        var results = [SearchTextFieldItem]()
                        for result in self.responseSearch ?? [] {
                            results.append(SearchTextFieldItem(title: result.name, subtitle: result.display))
                        }
                        DispatchQueue.main.async {
                            callback(results)
                        }
                    } else {
                        DispatchQueue.main.async {
                            callback([])
                        }
                    }
                }
                catch {
                    print("Network error: \(error)")
                    DispatchQueue.main.async {
                        callback([])
                    }
                }
            })
            
            task.resume()
        }
    }
    
    fileprivate func loadLatLong(_ refID: String, callback: @escaping ((_ results: LocationVM?) -> Void)) {
        let urlString = "\(url)/place/v3?apikey=\(keySearch)&refid=\(refID)"
        let search = urlString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
        let url = URL(string:search!)
        
        if let url = url {
            let task = URLSession.shared.dataTask(with: url, completionHandler: {(data, response, error) in
                do {
                    if let data = data {
                        let decoder = JSONDecoder()
                        let response = try decoder.decode(LocationVM.self, from: data)
                        DispatchQueue.main.async {
                            callback(response)
                        }
                    } else {
                        DispatchQueue.main.async {
                            callback(nil)
                        }
                    }
                }
                catch {
                    print("Network error: \(error)")
                    DispatchQueue.main.async {
                        callback(nil)
                    }
                }
            })
            
            task.resume()
        }
    }
    
    func refresh(data: LocationVM) {
        print(data)
        tableViewData = ["Tên: \(data.name)", "Địa chỉ: \(data.display)", "latidue: \(data.latitude)", "longitude: \(data.longitude)", "Dữ liệu từ api: \(data)"]
        self.resultTableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.tableViewData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TableViewCell",
                                                     for: indexPath)
        cell.selectionStyle = .none
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.text = "\(self.tableViewData[indexPath.row])"
        return cell
    }
}

// MARK: - Extension
extension ViewController: UITextFieldDelegate {
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        return true
    }
}
