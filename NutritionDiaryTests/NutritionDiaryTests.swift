import XCTest
@testable import NutritionDiary

final class NutritionDiaryTests: XCTestCase {
    func testReferenceTarget() throws {
        let t = try Target.calculate(Profile())
        XCTAssertEqual(t.ree!,1648.75,accuracy:0.0001)
        XCTAssertEqual(t.tdee!,2555.5625,accuracy:0.0001)
        XCTAssertEqual(t.nutrients.kcal,2172.228125,accuracy:0.0001)
        XCTAssertEqual(t.nutrients.protein,112,accuracy:0.0001)
        XCTAssertEqual(t.nutrients.fat,72.407604,accuracy:0.0001)
        XCTAssertEqual(t.nutrients.carbs,268.139922,accuracy:0.0001)
    }
    func testRestrictions() {
        var p = Profile(); p.age = 17; XCTAssertThrowsError(try Target.calculate(p))
        p = Profile(); p.weight = 45; XCTAssertThrowsError(try Target.calculate(p))
        p = Profile(); p.restricted = true; XCTAssertThrowsError(try Target.calculate(p))
        p = Profile(); p.height = .nan; XCTAssertThrowsError(try Target.calculate(p))
        p = Profile(); p.custom = true; p.customTarget.kcal = 100; XCTAssertThrowsError(try Target.calculate(p))
    }
    func testHouseholdPortions() {
        let r = MealParser.parse("一碗米饭、半盘番茄炒蛋、一杯牛奶")
        XCTAssertEqual(r.items.map(\.grams),[150,100,250]); XCTAssertTrue(r.unresolved.isEmpty)
        let unknown = MealParser.parse("披萨")
        XCTAssertTrue(unknown.items.isEmpty); XCTAssertEqual(unknown.unresolved,["披萨"])
    }
    func testAdjacentFoodsDoNotShareQuantities() {
        let a = MealParser.parse("米饭150克 鸡蛋2个")
        XCTAssertEqual(a.items.map(\.grams),[150,100]); XCTAssertTrue(a.unresolved.isEmpty)
        let b = MealParser.parse("一碗米饭两个鸡蛋")
        XCTAssertEqual(b.items.map(\.grams),[150,100]); XCTAssertTrue(b.unresolved.isEmpty)
        XCTAssertEqual(MealParser.parse("米饭2碗鸡蛋1个").items.map(\.grams),[300,50])
    }
    func testServingAndSnapshots() throws {
        var item = DraftItem(food:FoodBook.foods[0]); item.size = 1.5; item.eaten = 0.5
        XCTAssertEqual(item.grams,112.5); XCTAssertEqual(item.nutrients.kcal,146.25,accuracy:0.001)
        let entry = FoodEntry(date:Date(),meal:"午餐",name:item.food.name,grams:item.grams,nutrients:item.nutrients,serving:"大份·五成",source:item.food.source,basis:item.basis)
        let saved = try JSONDecoder().decode(FoodEntry.self,from:JSONEncoder().encode(entry))
        XCTAssertEqual(saved.nutrients,item.nutrients)
    }
    func testOlderDiaryDecodesWithoutWeightLogs() throws {
        let old = Data("{\"entries\":[],\"endpoint\":\"\"}".utf8)
        let migrated = try JSONDecoder().decode(SavedState.self,from:old)
        XCTAssertTrue(migrated.weightLogs.isEmpty)
        XCTAssertTrue(migrated.entries.isEmpty)
    }
    func testManualAllowsNonnegativeMacros() throws {
        var p = Profile(); p.custom = true
        p.customTarget = Nutrients(kcal:1000,protein:0,fat:0,carbs:250)
        XCTAssertEqual(try Target.calculate(p).nutrients.kcal,1000)
    }
}
