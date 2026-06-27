#if canImport(ConvCalcCore)
@testable import ConvCalcCore
#else
@testable import ConvCalc
#endif
import XCTest

final class CalculatorEngineTests: XCTestCase {
    func testArithmeticPrecedenceParenthesesAndPowers() throws {
        let engine = CalculatorEngine()

        XCTAssertEqual(try engine.evaluate("2+3*4"), 14)
        XCTAssertEqual(try engine.evaluate("(2+3)^2"), 25)
        XCTAssertEqual(try engine.evaluate("18/3+4*2"), 14)
    }

    func testScientificOperatorsAndConstants() throws {
        let engine = CalculatorEngine()

        XCTAssertEqual(try engine.evaluate("5!"), 120)
        XCTAssertEqual(try engine.evaluate("50%"), 0.5)
        XCTAssertEqual(try engine.evaluate("sqrt(81)+log10(100)"), 11)
        XCTAssertEqual(try engine.evaluate("log(e)"), 1, accuracy: 0.00001)
    }

    func testTrigUsesSelectedAngleMode() throws {
        let degreeEngine = CalculatorEngine(angleMode: .degrees)
        let radianEngine = CalculatorEngine(angleMode: .radians)

        XCTAssertEqual(try degreeEngine.evaluate("sin(90)"), 1, accuracy: 0.00001)
        XCTAssertEqual(try degreeEngine.evaluate("asin(1)"), 90, accuracy: 0.00001)
        XCTAssertEqual(try radianEngine.evaluate("sin(pi/2)"), 1, accuracy: 0.00001)
    }

    func testReducerMatchesCalculatorInputBehavior() {
        var reducer = CalculatorInputReducer()

        reducer.append("1")
        reducer.append("+")
        reducer.append("*")
        XCTAssertEqual(reducer.expression, "1*")

        reducer.appendDecimalPoint()
        XCTAssertEqual(reducer.expression, "1*0.")

        reducer.replace(with: "sqrt(")
        reducer.backspace()
        XCTAssertEqual(reducer.expression, "")
    }

    func testInvalidInputThrows() {
        XCTAssertThrowsError(try CalculatorEngine().evaluate("2//3"))
        XCTAssertThrowsError(try CalculatorEngine().evaluate("(-1)!"))
        XCTAssertThrowsError(try CalculatorEngine().evaluate("1/0"))
    }
}

final class ConverterCoreTests: XCTestCase {
    func testUnitConversions() throws {
        let length = try XCTUnwrap(ConverterTool.all.first { $0.key == "length" })
        let lengthResults = ConverterCore.convertToAll(value: 1, fromIndex: 3, units: length.units)
        XCTAssertEqual(lengthResults.first { $0.label == "m" }?.value ?? 0, 1_000, accuracy: 0.00001)

        let temperature = try XCTUnwrap(ConverterTool.all.first { $0.key == "temperature" })
        let temperatureResults = ConverterCore.convertToAll(value: 32, fromIndex: 1, units: temperature.units)
        XCTAssertEqual(temperatureResults.first { $0.label == "°C" }?.value ?? -1, 0, accuracy: 0.00001)
    }

    func testSpecialCalculators() throws {
        XCTAssertEqual(ConverterCore.calculateBMI(heightCm: 170, weightKg: 70), BMIResult(bmi: 24.2, category: "Normal"))
        XCTAssertEqual(ConverterCore.calculateDiscount(price: 100, percent: 20), DiscountResult(savings: 20, finalPrice: 80))

        let diff = try XCTUnwrap(ConverterCore.calculateDateDiff(year1: 2024, month1: 1, day1: 1, year2: 2025, month2: 1, day2: 1, calendar: gregorianUTC))
        XCTAssertEqual(diff.totalDays, 366)
        XCTAssertEqual(diff.weeks, 52)

        let loan = try XCTUnwrap(ConverterCore.calculateLoan(principal: 200_000, rate: 5, years: 30))
        XCTAssertEqual(loan.monthly, 1_073.64, accuracy: 0.01)
        XCTAssertEqual(loan.totalInterest, 186_511.57, accuracy: 0.01)
    }

    func testAgeCalculationUsesCalendarDates() throws {
        var components = DateComponents()
        components.calendar = gregorianUTC
        components.year = 2024
        components.month = 3
        components.day = 5
        let now = try XCTUnwrap(gregorianUTC.date(from: components))

        let age = try XCTUnwrap(ConverterCore.calculateAge(year: 1990, month: 1, day: 1, now: now, calendar: gregorianUTC))
        XCTAssertEqual(age, AgeResult(years: 34, months: 2, days: 4))
    }

    func testCurrencyRateSnapshotDecodesLegacyMillisecondsTimestamp() throws {
        let data = Data("""
        {"rates":{"USD":1,"EUR":0.93},"updatedAt":1700000000000}
        """.utf8)
        let snapshot = try JSONDecoder().decode(CurrencyRateSnapshot.self, from: data)

        XCTAssertEqual(snapshot.rates["EUR"], 0.93)
        XCTAssertEqual(snapshot.updatedAt.timeIntervalSince1970, 1_700_000_000, accuracy: 0.001)
    }

    func testCurrencyRateShouldRefreshWhenMissingOrStale() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertTrue(CurrencyRateStore.shouldRefresh(nil, now: now))

        let fresh = CurrencyRateSnapshot(rates: ["USD": 1], updatedAt: now.addingTimeInterval(-30 * 60))
        XCTAssertFalse(CurrencyRateStore.shouldRefresh(fresh, now: now))

        let stale = CurrencyRateSnapshot(rates: ["USD": 1], updatedAt: now.addingTimeInterval(-61 * 60))
        XCTAssertTrue(CurrencyRateStore.shouldRefresh(stale, now: now))
    }

    func testFallbackCurrencyRatesKeepConversionUsable() {
        let rates = CurrencyRateStore.fallbackRates
        let usd = rates["USD"] ?? 1
        let eur = rates["EUR"] ?? 0
        let jpy = rates["JPY"] ?? 0

        XCTAssertGreaterThan(eur / usd, 0)
        XCTAssertGreaterThan(jpy / usd, 0)
    }

    func testPublicExchangeRateResponseDecodes() throws {
        let data = Data("""
        {"result":"success","time_last_update_unix":1700000000,"rates":{"USD":1,"EUR":0.92,"JPY":150}}
        """.utf8)
        let response = try JSONDecoder().decode(PublicExchangeRateResponse.self, from: data)

        XCTAssertEqual(response.result, "success")
        XCTAssertEqual(response.timeLastUpdateUnix, 1_700_000_000)
        XCTAssertEqual(response.rates["JPY"], 150)
    }

    private var gregorianUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

#if !canImport(ConvCalcCore)
final class AppStatePersistenceTests: XCTestCase {
    func testPinnedToolsPersistAndRespectLimit() {
        let suiteName = "ConvCalcAppStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = ConvCalcAppState(userDefaults: defaults)
        XCTAssertEqual(state.screenOrder, ["_calculator", "currency"])
        XCTAssertFalse(state.pin("currency"))

        XCTAssertTrue(state.pin("length"))
        XCTAssertTrue(state.pin("area"))
        XCTAssertTrue(state.pin("mass"))
        XCTAssertTrue(state.pin("volume"))
        XCTAssertFalse(state.pin("speed"))
        XCTAssertEqual(state.pinnedToolKeys, ["currency", "length", "area", "mass", "volume"])

        state.unpin("area")
        XCTAssertEqual(state.pinnedToolKeys, ["currency", "length", "mass", "volume"])

        let reloaded = ConvCalcAppState(userDefaults: defaults)
        XCTAssertEqual(reloaded.screenOrder, ["_calculator", "currency", "length", "mass", "volume"])
    }

    func testUnpinWorksWhenToolbarIsFull() {
        let suiteName = "ConvCalcAppStateFullTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = ConvCalcAppState(userDefaults: defaults)
        _ = state.pin("length")
        _ = state.pin("area")
        _ = state.pin("mass")
        _ = state.pin("volume")
        XCTAssertFalse(state.canPinMoreTools)
        XCTAssertTrue(state.isToolPinned("currency"))

        state.unpin("currency")
        XCTAssertTrue(state.canPinMoreTools)
        XCTAssertEqual(state.pinnedToolKeys, ["length", "area", "mass", "volume"])
        XCTAssertFalse(state.pin("speed"))
        XCTAssertEqual(state.pinnedToolKeys, ["length", "area", "mass", "volume"])
    }

    func testToolAndShortcutReorderingPersist() {
        let suiteName = "ConvCalcReorderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = ConvCalcAppState(userDefaults: defaults)
        state.moveTool("pressure", before: "currency")
        XCTAssertEqual(state.orderedTools.first?.key, "pressure")

        state.moveTool("pressure", to: 3)
        XCTAssertEqual(state.orderedTools.map(\.key).prefix(4), ["currency", "length", "area", "pressure"])

        XCTAssertTrue(state.placePinnedTool("length", before: "currency"))
        XCTAssertTrue(state.placePinnedTool("mass", before: "_converter"))
        XCTAssertEqual(state.screenOrder, ["_calculator", "length", "currency", "mass"])

        let reloaded = ConvCalcAppState(userDefaults: defaults)
        XCTAssertEqual(reloaded.orderedTools.map(\.key).prefix(4), ["currency", "length", "area", "pressure"])
        XCTAssertEqual(reloaded.screenOrder, ["_calculator", "length", "currency", "mass"])
    }

    func testHistoryStorePersistsLimitsAndClears() {
        let suiteName = "ConvCalcHistoryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = CalculationHistoryStore(userDefaults: defaults)
        for index in 0..<105 {
            store.save(expression: "\(index)+1", result: "\(index + 1)")
        }

        XCTAssertEqual(store.entries.count, 100)
        XCTAssertEqual(store.entries.first?.expression, "104+1")
        XCTAssertEqual(store.entries.last?.expression, "5+1")

        let reloaded = CalculationHistoryStore(userDefaults: defaults)
        XCTAssertEqual(reloaded.entries.count, 100)
        XCTAssertEqual(reloaded.entries.first?.result, "105")

        reloaded.clear()
        XCTAssertTrue(reloaded.entries.isEmpty)
        XCTAssertTrue(CalculationHistoryStore(userDefaults: defaults).entries.isEmpty)
    }
}
#endif
