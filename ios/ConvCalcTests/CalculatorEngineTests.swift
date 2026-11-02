#if canImport(ConvCalcCore)
@testable import ConvCalcCore
#else
@testable import ConvCalc
#endif
import Foundation
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

    func testUnaryMinusBindsLooserThanPower() throws {
        let engine = CalculatorEngine()

        XCTAssertEqual(try engine.evaluate("-2^2"), -4)
        XCTAssertEqual(try engine.evaluate("(-2)^2"), 4)
        XCTAssertEqual(try engine.evaluate("2^-1"), 0.5)
    }

    func testImplicitMultiplication() throws {
        let engine = CalculatorEngine()

        XCTAssertEqual(try engine.evaluate("2(3)"), 6)
        XCTAssertEqual(try engine.evaluate("(2)(3)"), 6)
        XCTAssertEqual(try engine.evaluate("2pi"), CalculatorEngine.roundedResult(2 * .pi))
        XCTAssertEqual(try engine.evaluate("2sin(30)"), 1)
        XCTAssertEqual(try engine.evaluate("2e"), CalculatorEngine.roundedResult(2 * M_E))
        XCTAssertEqual(try engine.evaluate("-2pi"), CalculatorEngine.roundedResult(-2 * .pi))
    }

    func testPercentAppliesToLeftOperandOfAdditionAndSubtraction() throws {
        let engine = CalculatorEngine()

        XCTAssertEqual(try engine.evaluate("100+10%"), 110)
        XCTAssertEqual(try engine.evaluate("100-10%"), 90)
        XCTAssertEqual(try engine.evaluate("200*10%"), 20)
        XCTAssertEqual(try engine.evaluate("10%+5"), 5.1)
        XCTAssertEqual(try engine.evaluate("100+2*10%"), 100.2)
        XCTAssertEqual(try engine.evaluate("100+(10%)"), 100.1)
    }

    func testScientificNotationKeepsEulerKeyUnambiguous() throws {
        let engine = CalculatorEngine()

        XCTAssertEqual(try engine.evaluate("1E20"), 1e20)
        XCTAssertEqual(try engine.evaluate("1.5E-7"), 1.5e-7)
        XCTAssertEqual(try engine.evaluate("2E+3"), 2_000)
        XCTAssertEqual(try engine.evaluate("1e3"), 1_000)
        // Typed on the keypad as 2, e, +, 3: this is 2 times Euler's number, plus 3.
        XCTAssertEqual(try engine.evaluate("2e+3"), CalculatorEngine.roundedResult(2 * M_E + 3))
    }

    func testVerySmallResultsStayFinite() throws {
        XCTAssertEqual(try CalculatorEngine().evaluate("1/10^300"), 1e-300)
    }

    func testTrigRemovesFloatingPointNoiseAtExactAngles() throws {
        let degrees = CalculatorEngine(angleMode: .degrees)

        XCTAssertEqual(try degrees.evaluate("sin(180)"), 0)
        XCTAssertEqual(try degrees.evaluate("cos(90)"), 0)
        XCTAssertThrowsError(try degrees.evaluate("tan(90)"))
        XCTAssertThrowsError(try CalculatorEngine(angleMode: .radians).evaluate("tan(pi/2)"))
        XCTAssertEqual(try CalculatorEngine(angleMode: .radians).evaluate("sin(1E-20)"), 1e-20)
    }

    func testCommaIsNotSilentlyReadAsDecimalPoint() {
        XCTAssertThrowsError(try CalculatorEngine().evaluate("1,000"))
    }

    func testDecimalPointLooksOnlyAtTheCurrentNumber() {
        var reducer = CalculatorInputReducer(expression: "1.5^2")
        reducer.appendDecimalPoint()
        XCTAssertEqual(reducer.expression, "1.5^2.")

        reducer = CalculatorInputReducer(expression: "2^")
        reducer.appendDecimalPoint()
        XCTAssertEqual(reducer.expression, "2^0.")

        reducer = CalculatorInputReducer(expression: "1.5")
        reducer.appendDecimalPoint()
        XCTAssertEqual(reducer.expression, "1.5")
    }

    func testParenthesisAfterPowerOpens() {
        XCTAssertEqual(CalculatorInputReducer.nextParenthesis(for: "(2^"), "(")
    }

    func testAppendingFactorDoesNotMergeWithPreviousNumber() {
        var reducer = CalculatorInputReducer(expression: "5")
        reducer.appendFactor("1/")
        XCTAssertEqual(reducer.expression, "5*1/")

        reducer = CalculatorInputReducer(expression: "5+")
        reducer.appendFactor("1/")
        XCTAssertEqual(reducer.expression, "5+1/")

        reducer = CalculatorInputReducer()
        reducer.appendFactor("0.5")
        XCTAssertEqual(reducer.expression, "0.5")
    }

    func testExpressionValueRoundTripsThroughTheParser() throws {
        let engine = CalculatorEngine()
        for value in [0, 14, -5, 0.25, 1234.5, 1e20, 1.5e-7, 1e-300, 1e15] as [Double] {
            let text = CalculatorNumberFormat.expressionValue(value)
            XCTAssertEqual(try engine.evaluate(text), value, "\(text)")
        }
        XCTAssertEqual(CalculatorNumberFormat.expressionValue(14), "14")
        XCTAssertEqual(CalculatorNumberFormat.expressionValue(0.25), "0.25")
    }

    func testDisplayFollowsLocaleAndSwitchesToScientificAtExtremes() {
        let us = Locale(identifier: "en_US")
        let france = Locale(identifier: "fr_FR")

        XCTAssertEqual(CalculatorNumberFormat.display(1234.5, locale: us), "1,234.5")
        XCTAssertEqual(CalculatorNumberFormat.display(0.25, locale: france), "0,25")
        XCTAssertEqual(CalculatorNumberFormat.display(1.5e20, locale: us), "1.5E20")
        XCTAssertEqual(CalculatorNumberFormat.display(1.5e-20, locale: us), "1.5E-20")
    }

    func testPastedNumbersAreReadInTheUsersLocale() {
        let us = Locale(identifier: "en_US")
        let germany = Locale(identifier: "de_DE")

        XCTAssertEqual(CalculatorNumberFormat.normalizedPaste("1,000", locale: us), "1000")
        XCTAssertEqual(CalculatorNumberFormat.normalizedPaste("1,5", locale: germany), "1.5")
        XCTAssertEqual(CalculatorNumberFormat.normalizedPaste("1.234", locale: germany), "1234")
        XCTAssertEqual(CalculatorNumberFormat.normalizedPaste("2+3", locale: us), "2+3")
    }

    func testTypedNumberKeepsTrailingZerosAndGroupsIntegerPart() {
        let us = Locale(identifier: "en_US")
        let france = Locale(identifier: "fr_FR")

        XCTAssertEqual(CalculatorNumberFormat.typedNumber("1234.50", locale: us), "1,234.50")
        XCTAssertEqual(CalculatorNumberFormat.typedNumber("1.", locale: us), "1.")
        XCTAssertEqual(CalculatorNumberFormat.typedNumber("0.0", locale: france), "0,0")
        XCTAssertEqual(CalculatorNumberFormat.typedNumber("-12.", locale: us), "-12.")
        XCTAssertEqual(CalculatorNumberFormat.typedNumber("sin(90)", locale: us), "sin(90)")
    }

    func testOperatorsNeedSomethingOnTheirLeft() {
        var reducer = CalculatorInputReducer()
        reducer.append("*")
        reducer.append("%")
        XCTAssertEqual(reducer.expression, "")

        reducer.append("-")
        reducer.append("*")
        XCTAssertEqual(reducer.expression, "")

        reducer.replace(with: "(")
        reducer.append("/")
        XCTAssertEqual(reducer.expression, "(")
        reducer.append("-")
        XCTAssertEqual(reducer.expression, "(-")

        reducer.replace(with: "2^")
        reducer.append("+")
        XCTAssertEqual(reducer.expression, "2+")
    }

    func testValuesAfterConstantsMultiply() throws {
        var reducer = CalculatorInputReducer(expression: "pi")
        reducer.append("2")
        XCTAssertEqual(reducer.expression, "pi*2")

        reducer = CalculatorInputReducer(expression: "pi")
        reducer.appendFactor("e")
        XCTAssertEqual(reducer.expression, "pi*e")
        XCTAssertNoThrow(try CalculatorEngine().evaluate(reducer.expression))
    }

    func testDeeplyNestedInputDoesNotCrash() throws {
        let depth = CalculatorEngine.maxExpressionLength / 2
        let nested = String(repeating: "(", count: depth) + String(repeating: ")", count: depth)
        XCTAssertThrowsError(try CalculatorEngine().evaluate(nested))
        XCTAssertThrowsError(try CalculatorEngine().evaluate(String(repeating: "(", count: 500_000)))
        XCTAssertThrowsError(try CalculatorEngine().evaluate(String(repeating: "(", count: CalculatorEngine.maxExpressionLength)))
        XCTAssertThrowsError(try CalculatorEngine().evaluate(String(repeating: "-", count: CalculatorEngine.maxExpressionLength)))

        let inner = String(repeating: "(", count: 400) + "1" + String(repeating: ")", count: 400)
        XCTAssertEqual(try CalculatorEngine().evaluate(inner), 1)
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

    func testInterestFreeLoan() throws {
        let loan = try XCTUnwrap(ConverterCore.calculateLoan(principal: 1_200, rate: 0, years: 1))
        XCTAssertEqual(loan, LoanResult(monthly: 100, totalPaid: 1_200, totalInterest: 0))
    }

    func testLoanOverflowAndOversizedDiscountHaveNoResult() {
        XCTAssertNil(ConverterCore.calculateLoan(principal: 1_000, rate: 50, years: 999_999_999))
        XCTAssertNil(ConverterCore.calculateDiscount(price: 100, percent: 120))
        XCTAssertEqual(ConverterCore.calculateDiscount(price: 100, percent: 100)?.finalPrice, 0)
    }

    func testTinyCurrencyAmountsDoNotRoundToZero() {
        let us = Locale(identifier: "en_US")
        XCTAssertEqual(CurrencyRateStore.formatAmount(0.0000238, decimalDigits: 2, locale: us), "0.000024")
        XCTAssertEqual(CurrencyRateStore.formatAmount(1.256, decimalDigits: 2, locale: us), "1.26")
        XCTAssertEqual(CurrencyRateStore.formatAmount(158.4, decimalDigits: 0, locale: us), "158")
        XCTAssertEqual(CurrencyRateStore.formatAmount(0, decimalDigits: 2, locale: us), "0")
    }

    func testLimitingFractionForCurrencyChange() {
        XCTAssertEqual(CalculatorNumberFormat.limitingFraction(of: "1.50", to: 0), "1")
        XCTAssertEqual(CalculatorNumberFormat.limitingFraction(of: "1.555", to: 2), "1.55")
        XCTAssertEqual(CalculatorNumberFormat.limitingFraction(of: "1.5", to: 2), "1.5")
        XCTAssertEqual(CalculatorNumberFormat.limitingFraction(of: "12", to: 2), "12")
    }

    func testRatesRefreshWhenClockMovedBack() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let future = CurrencyRateSnapshot(rates: ["USD": 1], updatedAt: now.addingTimeInterval(86_400))
        XCTAssertTrue(CurrencyRateStore.shouldRefresh(future, now: now))
    }

    func testInfiniteConversionIsNotShownAsANumber() {
        XCTAssertEqual(ConverterCore.formatConversionResult(.infinity), "—")
    }

    func testConversionFormattingFollowsLocale() {
        XCTAssertEqual(ConverterCore.formatConversionResult(1234.5, locale: Locale(identifier: "en_US")), "1,234.5")
        XCTAssertEqual(ConverterCore.formatConversionResult(0.5, locale: Locale(identifier: "fr_FR")), "0,5")
        XCTAssertEqual(ConverterCore.formatNumber(0.5, locale: Locale(identifier: "de_DE")), "0,5")
    }

    func testDatesRejectOutOfRangeYears() {
        XCTAssertNil(ConverterCore.calculateAge(year: 999_999_999_999_999, month: 1, day: 1))
        XCTAssertNil(ConverterCore.calculateDateDiff(year1: 2024, month1: 1, day1: 1, year2: 999_999_999_999_999, month2: 1, day2: 1))
    }

    func testCurrencyConversionIsUnavailableWithoutBothRates() {
        let rates = ["USD": 1.0, "EUR": 0.5, "ZZZ": 0]

        XCTAssertEqual(CurrencyRateStore.convert(10, from: "USD", to: "EUR", rates: rates), 5)
        XCTAssertEqual(CurrencyRateStore.convert(10, from: "EUR", to: "USD", rates: rates), 20)
        XCTAssertNil(CurrencyRateStore.convert(10, from: "USD", to: "XAU", rates: rates))
        XCTAssertNil(CurrencyRateStore.convert(10, from: "XAU", to: "USD", rates: rates))
        XCTAssertNil(CurrencyRateStore.convert(10, from: "ZZZ", to: "USD", rates: rates))
    }

    private var gregorianUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

@MainActor
final class CurrencyRatesModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() async throws {
        suiteName = "ConvCalcRatesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private final class FetchCounter: @unchecked Sendable {
        var count = 0
        var error: Error?
    }

    private func makeModel(counter: FetchCounter, token: String? = "token") -> CurrencyRatesModel {
        let updatedAt = now
        return CurrencyRatesModel(defaults: defaults, token: { token }, fetch: { _ in
            counter.count += 1
            if let error = counter.error { throw error }
            return CurrencyRateSnapshot(rates: ["USD": 1, "BTC": 0.00001], updatedAt: updatedAt)
        })
    }

    private func storeSnapshot(age: TimeInterval) {
        CurrencyRateStore.save(CurrencyRateSnapshot(rates: ["USD": 1, "EUR": 0.5], updatedAt: now.addingTimeInterval(-age)), defaults: defaults)
    }

    func testFirstOpenFetchesAndPersists() async {
        let counter = FetchCounter()
        let model = makeModel(counter: counter)

        await model.refresh(now: now)

        XCTAssertEqual(counter.count, 1)
        XCTAssertEqual(model.rates["BTC"], 0.00001)
        XCTAssertEqual(CurrencyRateStore.load(defaults: defaults)?.rates["BTC"], 0.00001)
    }

    func testOpeningWithinTheHourDoesNotFetch() async {
        storeSnapshot(age: 59 * 60)
        let counter = FetchCounter()
        let model = makeModel(counter: counter)

        await model.refresh(now: now)

        XCTAssertEqual(counter.count, 0)
        XCTAssertEqual(model.rates["EUR"], 0.5)
    }

    func testOpeningAfterAnHourFetches() async {
        storeSnapshot(age: 60 * 60)
        let counter = FetchCounter()

        await makeModel(counter: counter).refresh(now: now)

        XCTAssertEqual(counter.count, 1)
    }

    func testManualRefreshIgnoresTheHour() async {
        storeSnapshot(age: 60)
        let counter = FetchCounter()

        await makeModel(counter: counter).refresh(force: true, now: now)

        XCTAssertEqual(counter.count, 1)
    }

    func testFailureKeepsRatesAndNextOpenRetries() async {
        storeSnapshot(age: 2 * 60 * 60)
        let counter = FetchCounter()
        counter.error = URLError(.notConnectedToInternet)
        let model = makeModel(counter: counter)

        await model.refresh(now: now)
        XCTAssertTrue(model.refreshFailed)
        XCTAssertEqual(model.rates["EUR"], 0.5)
        XCTAssertFalse(model.isRefreshing)

        counter.error = nil
        await model.refresh(now: now)
        XCTAssertEqual(counter.count, 2)
        XCTAssertFalse(model.refreshFailed)
        XCTAssertEqual(model.rates["BTC"], 0.00001)
    }

    func testMissingTokenReportsFailureWithoutFetching() async {
        let counter = FetchCounter()
        let model = makeModel(counter: counter, token: nil)

        await model.refresh(now: now)

        XCTAssertEqual(counter.count, 0)
        XCTAssertTrue(model.refreshFailed)
    }

    func testChosenCurrenciesPersistAndDuplicatesSwap() {
        let model = makeModel(counter: FetchCounter())

        model.setCurrency("CHF", at: 1)
        XCTAssertEqual(model.displayedCurrencies, ["USD", "CHF", "GBP", "JPY"])

        model.setCurrency("USD", at: 2)
        XCTAssertEqual(model.displayedCurrencies, ["GBP", "CHF", "USD", "JPY"])

        XCTAssertEqual(makeModel(counter: FetchCounter()).displayedCurrencies, ["GBP", "CHF", "USD", "JPY"])
    }
}

#if !canImport(ConvCalcCore)
final class CalculatorViewModelTests: XCTestCase {
    func testSelectedOperatorIsReplacedAndDigitsNeverMergeNumbers() {
        let model = CalculatorViewModel()
        model.setExpression("1+2")
        model.selectChunk(1)
        model.press("*")
        XCTAssertEqual(model.expression, "1*2")
        XCTAssertNil(model.selectedChunkIndex)

        model.setExpression("1+2")
        model.selectChunk(1)
        model.press("5")
        XCTAssertEqual(model.expression, "1+25")
        XCTAssertNil(model.selectedChunkIndex)
    }

    func testOperatorsDisplayAsMathSymbols() {
        let model = CalculatorViewModel()
        XCTAssertEqual(model.formatChunk("*"), "×")
        XCTAssertEqual(model.formatChunk("/"), "÷")
    }

    private func makeHistory() -> (CalculationHistoryStore, () -> Void) {
        let suiteName = "ConvCalcViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (CalculationHistoryStore(userDefaults: defaults), { defaults.removePersistentDomain(forName: suiteName) })
    }

    func testResultStaysLocaleIndependentAcrossCalculations() {
        let (history, cleanup) = makeHistory()
        defer { cleanup() }
        let model = CalculatorViewModel()

        model.setExpression("1/4")
        model.calculate(historyStore: history)
        XCTAssertEqual(model.expression, "0.25")
        XCTAssertEqual(history.entries.first?.result, "0.25")

        model.setExpression("1000*1000")
        model.calculate(historyStore: history)
        XCTAssertEqual(model.expression, "1000000")
    }

    func testRepeatedEqualsAndEmptyEqualsRecordNothing() {
        let (history, cleanup) = makeHistory()
        defer { cleanup() }
        let model = CalculatorViewModel()

        model.calculate(historyStore: history)
        XCTAssertEqual(model.error, "")

        model.setExpression("2+3")
        model.calculate(historyStore: history)
        model.calculate(historyStore: history)
        XCTAssertEqual(history.entries.count, 1)
        XCTAssertEqual(model.sessionHistory.count, 1)
    }

    func testDecimalPointEditsTheSelectedChunk() {
        let model = CalculatorViewModel()
        model.setExpression("12+34")
        model.selectChunk(0)

        model.decimalPoint()
        XCTAssertEqual(model.expression, "0.+34")
        model.press("5")
        XCTAssertEqual(model.expression, "0.5+34")
    }

    func testBackspaceClearsSelectionWhenChunkIsEmptied() {
        let model = CalculatorViewModel()
        model.setExpression("1+2")
        model.selectChunk(2)

        model.backspace()
        XCTAssertEqual(model.expression, "1+")
        XCTAssertNil(model.selectedChunkIndex)
    }

    func testScientificResultStaysOneChunk() {
        let model = CalculatorViewModel()
        model.setExpression("1E+20+1")
        XCTAssertEqual(model.formattedChunks(), ["1E+20", "+", "1"])
    }
}

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

        XCTAssertTrue(state.pin("speed"))
        XCTAssertFalse(state.pin("pressure"))
        XCTAssertEqual(state.pinnedToolKeys, ["length", "area", "mass", "volume", "speed"])
    }

    func testToolAndShortcutReorderingPersist() {
        let suiteName = "ConvCalcReorderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = ConvCalcAppState(userDefaults: defaults)
        state.moveTool("pressure", to: 0)
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

    func testCalculatorTabKeepsItsPositionWhenPinningAndReloading() {
        let suiteName = "ConvCalcCalculatorPositionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = ConvCalcAppState(userDefaults: defaults)
        state.moveToolbarTab("_calculator", to: 1)
        XCTAssertEqual(state.screenOrder, ["currency", "_calculator"])

        XCTAssertTrue(state.pin("length"))
        XCTAssertEqual(state.screenOrder, ["currency", "_calculator", "length"])
        XCTAssertEqual(ConvCalcAppState(userDefaults: defaults).screenOrder, ["currency", "_calculator", "length"])
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
