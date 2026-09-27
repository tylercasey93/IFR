import XCTest
@testable import IFRCore

final class GymIDTests: XCTestCase {
    func testCircuitOrderMatchesSpec() {
        XCTAssertEqual(GymID.allCases, [
            .humanFactors, .instrumentsAndSystems, .regulations, .navigation,
            .chartsAndPlanning, .weather, .emergencies, .approaches,
        ])
    }

    func testNextChainsEndInNil() {
        var current: GymID? = .humanFactors
        var visited: [GymID] = []
        while let gym = current {
            visited.append(gym)
            current = gym.next
        }
        XCTAssertEqual(visited, GymID.allCases)
        XCTAssertNil(GymID.approaches.next)
    }

    func testEveryGymIDMapsToItsCategory() {
        XCTAssertEqual(GymID.humanFactors.category, IFRCore.Category.humanFactors)
        XCTAssertEqual(GymID.instrumentsAndSystems.category, IFRCore.Category.instrumentsAndSystems)
        XCTAssertEqual(GymID.regulations.category, IFRCore.Category.regulations)
        XCTAssertEqual(GymID.navigation.category, IFRCore.Category.navigation)
        XCTAssertEqual(GymID.chartsAndPlanning.category, IFRCore.Category.chartsAndPlanning)
        XCTAssertEqual(GymID.weather.category, IFRCore.Category.weather)
        XCTAssertEqual(GymID.emergencies.category, IFRCore.Category.emergencies)
        XCTAssertEqual(GymID.approaches.category, IFRCore.Category.approaches)
    }

    func testGymIDCategoriesCoverAllEightCategoriesOnce() {
        let categories = Set(GymID.allCases.map(\.category))
        XCTAssertEqual(categories, Set(IFRCore.Category.allCases))
    }
}
