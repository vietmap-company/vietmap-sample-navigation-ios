import XCTest
import VietMapCoreNavigation

class NavigationLocationManagerTests: XCTestCase {
    
    func testNavigationLocationManagerDefaultAccuracy() {
        let locationManager = NavigationLocationManager()
        XCTAssertEqual(locationManager.desiredAccuracy, kCLLocationAccuracyBest)
    }
}
