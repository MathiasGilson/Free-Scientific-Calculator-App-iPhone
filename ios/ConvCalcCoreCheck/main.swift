import ConvCalcCore
import Foundation

enum CheckFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw CheckFailure.failed(message)
    }
}

func expectEqual(_ lhs: Double, _ rhs: Double, accuracy: Double = 0.00001, _ message: String) throws {
    if abs(lhs - rhs) > accuracy {
        throw CheckFailure.failed("\(message): expected \(rhs), got \(lhs)")
    }
}

func expectThrows(_ body: () throws -> Void, _ message: String) throws {
    do {
        try body()
    } catch {
        return
    }
    throw CheckFailure.failed(message)
}

let engine = CalculatorEngine()
try expectEqual(try engine.evaluate("2+3*4"), 14, "operator precedence")
try expectEqual(try engine.evaluate("(2+3)^2"), 25, "parentheses and powers")
try expectEqual(try engine.evaluate("5!"), 120, "factorial")
try expectEqual(try engine.evaluate("50%"), 0.5, "percent")
try expectEqual(try engine.evaluate("sqrt(81)+log10(100)"), 11, "sqrt and log10")
try expectEqual(try engine.evaluate("sin(90)"), 1, "degree sine")
try expectEqual(try engine.evaluate("asin(1)"), 90, "degree inverse sine")
try expectEqual(try CalculatorEngine(angleMode: .radians).evaluate("sin(pi/2)"), 1, "radian sine")
try expectThrows({ _ = try engine.evaluate("1/0") }, "division by zero should throw")

var reducer = CalculatorInputReducer()
reducer.append("1")
reducer.append("+")
reducer.append("*")
try expect(reducer.expression == "1*", "operator replacement")
reducer.appendDecimalPoint()
try expect(reducer.expression == "1*0.", "decimal insertion")
reducer.replace(with: "sqrt(")
reducer.backspace()
try expect(reducer.expression.isEmpty, "function token backspace")

let length = ConverterTool.all.first { $0.key == "length" }!
let lengthResults = ConverterCore.convertToAll(value: 1, fromIndex: 3, units: length.units)
try expectEqual(lengthResults.first { $0.label == "m" }!.value, 1_000, "kilometer to meter")

let temperature = ConverterTool.all.first { $0.key == "temperature" }!
let temperatureResults = ConverterCore.convertToAll(value: 32, fromIndex: 1, units: temperature.units)
try expectEqual(temperatureResults.first { $0.label == "°C" }!.value, 0, "fahrenheit to celsius")

try expect(ConverterCore.calculateBMI(heightCm: 170, weightKg: 70) == BMIResult(bmi: 24.2, category: "Normal"), "BMI")
try expect(ConverterCore.calculateDiscount(price: 100, percent: 20) == DiscountResult(savings: 20, finalPrice: 80), "discount")

var gregorianUTC = Calendar(identifier: .gregorian)
gregorianUTC.timeZone = TimeZone(secondsFromGMT: 0)!
let dateDiff = ConverterCore.calculateDateDiff(year1: 2024, month1: 1, day1: 1, year2: 2025, month2: 1, day2: 1, calendar: gregorianUTC)!
try expect(dateDiff.totalDays == 366, "date difference total days")

let loan = ConverterCore.calculateLoan(principal: 200_000, rate: 5, years: 30)!
try expectEqual(loan.monthly, 1_073.64, accuracy: 0.01, "loan monthly")
try expectEqual(loan.totalInterest, 186_511.57, accuracy: 0.01, "loan interest")

var nowComponents = DateComponents()
nowComponents.calendar = gregorianUTC
nowComponents.year = 2024
nowComponents.month = 3
nowComponents.day = 5
let age = ConverterCore.calculateAge(year: 1990, month: 1, day: 1, now: gregorianUTC.date(from: nowComponents)!, calendar: gregorianUTC)!
try expect(age == AgeResult(years: 34, months: 2, days: 4), "age")

print("ConvCalcCoreCheck passed")
