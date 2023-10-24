import Foundation
import VietMapCoreNavigation
import VietMapNavigation
import MapboxDirections
import CoreLocation

public class CustomUINavigationController: UIViewController, MGLMapViewDelegate {
    private var navigationViewController: NavigationViewController!
    private var routes: [Route]?
    public var delegate: SpotARNavigationUIDelegate?
    private var currentLocation: CLLocation!
    private var isFirstRender: Bool = false
    let url = Bundle.main.object(forInfoDictionaryKey: "VietMapURL") as! String
    
    // MARK: variable
    var userRoute: Route?
    var simulateLocation = false
    var routeController: RouteController!

    private var bottomSheetTopConstraint: NSLayoutConstraint!
    private var bottomSheetBottomConstraint: NSLayoutConstraint!

    private var isBottomSheetVisible = false

    private var bottomSheetInitialY: CGFloat = 0
    private var bottomSheetHeight: CGFloat = 300
    private var totalDistanceKM: CGFloat = 0
    
    typealias StepSection = [RouteStep]
    var sections = [StepSection]()
    var previousLegIndex: Int = NSNotFound
    var previousStepIndex: Int = NSNotFound
    var arrivel: CLLocationCoordinate2D?
    var marker: MGLPointAnnotation?
    let currentTime = Date()
    let calendar = Calendar.current
    var maneuverView = ManeuverView()
    static let maneuverViewSize = CGSize(width: 45, height: 45)
    var test: CGFloat = 0.0;
    var voiceController = RouteVoiceController()
    var muted : Bool = false
    var clickRencenter : Bool = false
    var clickOverview : Bool = false
    var isLoadingFinshied : Bool = false
    let distanceFormatter = DistanceFormatter(approximate: true)
    let dateComponentsFormatter = DateComponentsFormatter()
    
    // MARK: - IBOutlets
    @IBOutlet weak var mapView: NavigationMapView!
    @IBOutlet weak var bottomSheetView: UIView!
    @IBOutlet weak var cancelNavigation: UIImageView!
    @IBOutlet weak var direction: UIImageView!
    @IBOutlet weak var distance: UILabel!
    @IBOutlet weak var street: UILabel!
    @IBOutlet weak var time: UILabel!
    @IBOutlet weak var totalDistance: UILabel!
    @IBOutlet weak var timeRemain: UILabel!
    @IBOutlet weak var sound: UIImageView!
    @IBOutlet weak var speed: UILabel!
    @IBOutlet weak var inProgressNavigation: UIProgressView!
    @IBOutlet weak var currentStreet: UILabel!
    @IBOutlet weak var recenter: UIButton!
    @IBOutlet weak var overView: UIButton!

    public override func viewDidLoad() {
        super.viewDidLoad()
//        if simulateLocation {
//            overView.isHidden = true
//        }
        recenter.isHidden = false
        inProgressNavigation.progress = 0
        bottomSheetInitialY = bottomSheetView.frame.origin.y
        
        let locationManager = simulateLocation ? SimulatedLocationManager(route: userRoute!) : NavigationLocationManager()
        routeController = RouteController(along: userRoute!, locationManager: locationManager)
        routeController.delegate = self
        customStyleMap()
        mapView.recenterMap()
        
        marker = MGLPointAnnotation()
        marker?.coordinate = arrivel!
        marker?.title = "Điểm đến của bạn"
        
        // Add action button
        cancelNavigation.isUserInteractionEnabled = true
        recenter.isUserInteractionEnabled = true
        overView.isUserInteractionEnabled = true
        sound.isUserInteractionEnabled = true
        cancelNavigation.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cancelNavi(tap:))))
        recenter.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(recenterMap(tap:))))
        overView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(overViewMap(tap:))))
        sound.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(soundController(tap:))))
        
        // Add listeners for progress updates
        resumeNotifications()
//        self.voiceController = MapboxVoiceController()
        // Start navigation
        routeController.resume()
        
        setupView()
        setupLayout()
    }
    
    func setupView() {
        maneuverView.backgroundColor = .clear
        maneuverView.translatesAutoresizingMaskIntoConstraints = false
        maneuverView.primaryColor = hexStringToUIColor(hex: "#3385ff")
        bottomSheetView.addSubview(maneuverView)
    }
    
    func setupLayout() {
        let firstColumnWidth = CustomUINavigationController.maneuverViewSize.width + 16 * 3
        // Turn arrow view
        maneuverView.heightAnchor.constraint(equalToConstant: CustomUINavigationController.maneuverViewSize.height).isActive = true
        maneuverView.widthAnchor.constraint(equalToConstant: CustomUINavigationController.maneuverViewSize.width).isActive = true
        maneuverView.topAnchor.constraint(equalTo: bottomSheetView.topAnchor, constant: 16).isActive = true
        maneuverView.centerXAnchor.constraint(equalTo: bottomSheetView.leadingAnchor, constant: firstColumnWidth / 2).isActive = true
    }
    
    public func mapViewDidFinishLoadingMap(_ mapView: MGLMapView) {
            // Xử lý sự kiện tại đây
        print("Bản đồ đã hoàn thành tải và hiển thị.")
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NightStyle().apply()
    }
    
    deinit {
        suspendNotifications()
    }

    private func customStyleMap() {
        mapView.delegate = self
        mapView.compassView.isHidden = true
        mapView.styleURL = URL(string: url);
        mapView.routeLineColor = UIColor.yellow
        mapView.userTrackingMode = .follow
        mapView.tracksUserCourse = true
        mapView.showsUserLocation = true
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        routeController.reroutesProactively = true
    }

    func resumeNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_ :)), name: .routeControllerProgressDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(rerouted(_:)), name: .routeControllerDidReroute, object: nil)
    }

    func suspendNotifications() {
        NotificationCenter.default.removeObserver(self, name: .routeControllerProgressDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .routeControllerWillReroute, object: nil)
    }
    
    // Notifications sent on all location updates
    @objc func progressDidChange(_ notification: NSNotification) {
        let routeProgress = notification.userInfo![RouteControllerNotificationUserInfoKey.routeProgressKey] as! RouteProgress
        let location = notification.userInfo![RouteControllerNotificationUserInfoKey.locationKey] as! CLLocation
        handleRoute(routeProgress)
        // Update the user puck
        let camera = MGLMapCamera(lookingAtCenter: location.coordinate, altitude: 120, pitch: 60, heading: location.course)
        mapView.updateCourseTracking(location: location, camera: camera, animated: true)
        
    }
    
    func handleRoute(_ routeProgress: RouteProgress) {
        // Add maneuver arrow
        addManeuverArrow(routeProgress)
        handleProgressRoute(routeProgress)
        let step = sections.first?.first
        street.text = step?.instructions
        distance.text = distanceFormatter.string(from: routeProgress.currentLegProgress.currentStepProgress.distanceRemaining)

        // caculate time arrival
        guard let arrivalDate = NSCalendar.current.date(byAdding: .second, value: Int(routeProgress.durationRemaining), to: Date()) else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        time.text = dateFormatter.string(from: arrivalDate)
        totalDistance.text = distanceFormatter.string(from: routeProgress.distanceRemaining)
        if (totalDistanceKM.isZero) {
            totalDistanceKM = routeProgress.distanceRemaining
        }
        dateComponentsFormatter.unitsStyle = routeProgress.durationRemaining < 3600 ? .short : .abbreviated

        if let hardcodedTime = dateComponentsFormatter.string(from: 61), routeProgress.durationRemaining < 60 {
            let arrText = String.localizedStringWithFormat(NSLocalizedString("LESS_THAN", value: "<%@", comment: "Format string for a short distance or time less than a minimum threshold; 1 = duration remaining"), hardcodedTime).components(separatedBy: ",")
            timeRemain.text = arrText[0]
        } else {
            var arrText = dateComponentsFormatter.string(from: routeProgress.durationRemaining)?.components(separatedBy: " ")
            if (arrText ?? []).count == 4 && arrText?[1].last == ","{
                arrText?[1].removeLast()
            }
            timeRemain.text = (arrText?[0] ?? "") + " " + (arrText?[1] ?? "")
        }
        speed.text = "\(String(format: "%.f", check(mapView.userLocation?.location?.speed ?? 0.0))) m/s"
        if let instructions = routeProgress.currentLegProgress.currentStepProgress.step.instructionsDisplayedAlongStep?.last {
            maneuverView.visualInstruction = instructions.primaryInstruction
            maneuverView.drivingSide = instructions.drivingSide
            maneuverView.isStart = true
        }

        self.currentStreet.text = routeProgress.currentLegProgress.currentStep.names?.first

        
        let progress: CGFloat = CGFloat(routeProgress.distanceRemaining) as CGFloat
        inProgressNavigation.setProgress(Float(1.0 - (progress/totalDistanceKM)), animated: true)
    }
    
    func check(_ value: Double) -> Double {
        return value < 0 ? 0.0 : value
    }
    
    func convertMettoKilomet(_ value: Double) -> Double {
        return value/1000
    }
    
    func handleProgressRoute(_ routeProgress: RouteProgress) {

        let legIndex = routeProgress.legIndex
        let stepIndex = routeProgress.currentLegProgress.stepIndex
        let didProcessCurrentStep = previousLegIndex == legIndex && previousStepIndex == stepIndex

        guard !didProcessCurrentStep else { return }

        sections.removeAll()

        let currentLeg = routeProgress.currentLeg

        // Add remaining steps for current leg
        var section = [RouteStep]()
        for (index, step) in currentLeg.steps.enumerated() {
            guard index > stepIndex else { continue }
            // Don't include the last step, it includes nothing
            guard index < currentLeg.steps.count - 1 else { continue }
            section.append(step)
        }

        if !section.isEmpty {
            sections.append(section)
        }

        // Include all steps on any future legs
        if !routeProgress.isFinalLeg {
            routeProgress.route.legs.suffix(from: routeProgress.legIndex + 1).forEach {
                var steps = $0.steps
                // Don't include the last step, it includes nothing
                _ = steps.popLast()
                sections.append(steps)
            }
        }

        previousStepIndex = stepIndex
        previousLegIndex = legIndex
    }
    
    @objc func rerouted(_ notification: NSNotification) {
        if let userInfo = notification.object as? RouteController {
            self.totalDistanceKM = userInfo.routeProgress.distanceRemaining
            self.previousStepIndex = 0
            self.previousLegIndex = 0
            handleRoute(userInfo.routeProgress)
            addManeuverArrow(userInfo.routeProgress)
        }
        self.mapView.showRoutes([routeController.routeProgress.route])
        self.mapView.tracksUserCourse = true
        self.mapView.recenterMap()
    }

    private func addManeuverArrow(_ routeProgress: RouteProgress) {
        if routeProgress.currentLegProgress.followOnStep != nil {
            self.mapView.addArrow(route: routeProgress.route, legIndex: routeProgress.legIndex, stepIndex: routeProgress.currentLegProgress.stepIndex + 1)
        } else {
            self.mapView.removeArrow()
        }
    }

    private func toggleBottomSheet() {
        isBottomSheetVisible = !isBottomSheetVisible

        let newY = isBottomSheetVisible ? (view.frame.height - bottomSheetHeight) : bottomSheetInitialY

        UIView.animate(withDuration: 0.3) {
            self.bottomSheetView.frame.origin.y = newY
        }
    }
    
    public func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        self.mapView.showRoutes([routeController.routeProgress.route])
        self.mapView.addAnnotation(marker!)
        self.isLoadingFinshied = true
    }
    
    public func mapView(_ mapView: MGLMapView, regionDidChangeAnimated animated: Bool) {
//        if (isLoadingFinshied) {
//            self.mapView.tracksUserCourse = false
//            if (clickRencenter == true) {
//                self.mapView.tracksUserCourse = true
//                clickRencenter = false
//            }
//            print("move map")
//        }
    }
    
    private func getNavigationLocationManager(simulated: Bool) -> NavigationLocationManager {
        guard let route = routes?.first else { return NavigationLocationManager() }
        let simulatedLocationManager = SimulatedLocationManager(route: route)
        simulatedLocationManager.speedMultiplier = 2
        return simulated ? simulatedLocationManager : NavigationLocationManager()
    }
    
    // MARK: - action button
    @objc func cancelNavi(tap: UITapGestureRecognizer) {
        self.dismiss(animated: true, completion: nil)
        routeController.endNavigation()
    }
    
    @objc func recenterMap(tap: UITapGestureRecognizer) {
        clickRencenter = true
        mapView.trackUpdateCourse = true
        mapView.tracksUserCourse = true
//        mapView.userTrackingMode = .follow
        updateCameraAltitude(for: routeController.routeProgress)
    }
    
    func updateCameraAltitude(for routeProgress: RouteProgress) {
        guard mapView.tracksUserCourse else { return } //only adjust when we are actively tracking user course

        let zoomOutAltitude = mapView.zoomedOutMotorwayAltitude
        let defaultAltitude: CLLocationDistance = 500.0
        let isLongRoad = routeProgress.distanceRemaining >= mapView.longManeuverDistance
        let currentStep = routeProgress.currentLegProgress.currentStep
        let upComingStep = routeProgress.currentLegProgress.upComingStep

        //If the user is on a motorway, not exiting, and their segment is sufficently long, the map should zoom out to the motorway altitude.
        //otherwise, zoom in if it's the last instruction on the step.
        let currentStepIsMotorway = currentStep.isMotorway
        let nextStepIsMotorway = upComingStep?.isMotorway ?? false
        if currentStepIsMotorway, nextStepIsMotorway, isLongRoad {
            updateCamera(defaultAltitude: zoomOutAltitude)
        } else {
            updateCamera(defaultAltitude: defaultAltitude)
        }
    }
    
    private func updateCamera(defaultAltitude: CLLocationDistance) {
        if let location = routeController.locationManager.location {
            let camera = MGLMapCamera(
                lookingAtCenter: location.coordinate,
                acrossDistance: defaultAltitude,
                pitch: 45,
                heading: location.course
            )
            self.mapView.setCamera(camera, withDuration: 1, animationTimingFunction: nil)
        }
    }
    
    @objc public var overheadInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 20, left: 20, bottom: bottomSheetView.bounds.height, right: 20)
    }

    
    @objc func overViewMap(tap: UITapGestureRecognizer) {
        clickOverview = true
        self.mapView.tracksUserCourse = false
        if let coordinates = routeController?.routeProgress.route.coordinates, let userLocation = routeController?.locationManager.location?.coordinate {
            mapView.setOverheadCameraView(from: userLocation, along: coordinates, for: overheadInsets)
        }
    }
    
    @objc func soundController(tap: UITapGestureRecognizer) {
        muted = !muted
        
        if (muted == true) {
            sound.image = UIImage(systemName:"speaker.slash")
        } else {
            sound.image = UIImage(systemName:"speaker")
        }
        NavigationSettings.shared.voiceMuted = muted
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
}

extension CustomUINavigationController: NavigationViewControllerDelegate {
    public func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) -> Bool {
        delegate?.didArrive(viewController: navigationViewController)
        return true
    }

    public func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        delegate?.didCancel()
    }
}

extension CustomUINavigationController: RouteControllerDelegate {
    public func routeController(_ routeController: RouteController, didArriveAt waypoint: Waypoint) -> Bool {
        let alert = UIAlertController(title: "Thông báo", message: "Bạn đã đến nơi", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            switch action.style{
                case .default:
                print("default")
                
                case .cancel:
                print("cancel")
                
                case .destructive:
                print("destructive")
                
            @unknown default:
                print("default")
            }
        }))
        self.present(alert, animated: true, completion: nil)
        return false
    }
}
