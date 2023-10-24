import XCTest
import FBSnapshotTestCase
import MapboxDirections
@testable import VietMapNavigation
@testable import VietMapCoreNavigation


class ManeuverViewTests: FBSnapshotTestCase {

    let maneuverView = ManeuverView(frame: CGRect(origin: .zero, size: CGSize(width: 50, height: 50)))

    override func setUp() {
        super.setUp()
        maneuverView.backgroundColor = .white
        recordMode = false
        agnosticOptions = [.OS, .device]
        usesDrawViewHierarchyInRect = true

        let window = UIWindow(frame: maneuverView.bounds)
        window.addSubview(maneuverView)
    }

    func maneuverInstruction(_ maneuverType: ManeuverType, _ maneuverDirection: ManeuverDirection, _ drivingSide: DrivingSide, _ degrees: CLLocationDegrees = 180) -> VisualInstruction {
        let component = VisualInstructionComponent(type: .delimiter, text: "", imageURL: nil, abbreviation: nil, abbreviationPriority: 0)
        return VisualInstruction(text: "", maneuverType: maneuverType, maneuverDirection: maneuverDirection, components: [component], degrees: degrees)
    }

    func testStraightRoundabout() {
        maneuverView.visualInstruction = maneuverInstruction(.takeRoundabout, .straightAhead, .right)
        verify(maneuverView.layer)
    }

    func testTurnRight() {
        maneuverView.visualInstruction = maneuverInstruction(.turn, .right, .right)
        verify(maneuverView.layer)
    }

    func testTurnSlightRight() {
        maneuverView.visualInstruction = maneuverInstruction(.turn, .slightRight, .right)
        verify(maneuverView.layer)
    }

    func testMergeRight() {
        maneuverView.visualInstruction = maneuverInstruction(.merge, .right, .right)
        verify(maneuverView.layer)
    }

    func testRoundaboutTurnLeft() {
        maneuverView.visualInstruction = maneuverInstruction(.takeRoundabout, .right, .right, CLLocationDegrees(270))
        verify(maneuverView.layer)
    }
    
    func testRoundabout() {
        let incrementer: CGFloat = 45
        let size = CGSize(width: maneuverView.bounds.width * (360 / incrementer), height: maneuverView.bounds.height)
        let views = UIView(frame: CGRect(origin: .zero, size: size))

        for bearing in stride(from: CGFloat(0), to: CGFloat(360), by: incrementer) {
            let position = CGPoint(x: maneuverView.bounds.width * (bearing / incrementer), y: 0)
            let view = ManeuverView(frame: CGRect(origin: position, size: maneuverView.bounds.size))
            view.backgroundColor = .white
            view.visualInstruction = maneuverInstruction(.takeRoundabout, .right, .right, CLLocationDegrees(bearing))
            views.addSubview(view)
        }

        verify(views.layer)
    }

    // TODO: Figure out why the flip transformation do not render in a snapshot so we can test left turns and left side rule of the road.
}
