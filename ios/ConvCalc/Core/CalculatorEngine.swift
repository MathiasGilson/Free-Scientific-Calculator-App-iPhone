import Foundation
import Darwin

public enum AngleMode: String, CaseIterable, Sendable {
    case degrees
    case radians

    public func toRadians(_ value: Double) -> Double {
        switch self {
        case .degrees:
            return value * .pi / 180
        case .radians:
            return value
        }
    }

    public func fromRadians(_ value: Double) -> Double {
        switch self {
        case .degrees:
            return value * 180 / .pi
        case .radians:
            return value
        }
    }
}

public enum CalculatorEngineError: Error, Equatable, Sendable {
    case invalidInput
    case expectedClosingParenthesis
    case unknownIdentifier(String)
    case invalidFactorial
    case divisionByZero
}

public struct CalculatorEngine: Sendable {
    public static let maxExpressionLength = 1_000

    public var angleMode: AngleMode = .degrees

    public init(angleMode: AngleMode = .degrees) {
        self.angleMode = angleMode
    }

    public func evaluate(_ expression: String) throws -> Double {
        // The parser is recursive, so an enormous paste of "((((" must not exhaust the stack.
        guard expression.count <= Self.maxExpressionLength else { throw CalculatorEngineError.invalidInput }
        let parser = ExpressionParser(expression: expression, angleMode: angleMode)
        let result = try parser.parse()
        guard result.isFinite else { throw CalculatorEngineError.invalidInput }
        return Self.roundedResult(result)
    }

    public static func roundedResult(_ result: Double) -> Double {
        guard result.isFinite else { return result }
        if result == 0 { return 0 }
        if result.rounded(.towardZero) == result { return result }
        // Round to 12 significant digits rather than to a fixed number of decimal places.
        // This strips binary floating-point noise (e.g. 0.1 + 0.2 = 0.30000000000000004)
        // while preserving as many real decimals as the value actually has. Going through
        // decimal text avoids the noise that scaling by an inexact power of ten would add.
        guard abs(result) < 1e11 else { return result }
        return Double(String(format: "%.11e", result)) ?? result
    }
}

/// Converts between engine values and the text forms the calculator uses. Expressions
/// always hold locale-independent numbers; only what is shown on screen is localized.
public enum CalculatorNumberFormat {
    /// Locale-independent text the parser reads back without loss. Uppercase `E` keeps
    /// scientific notation distinct from the Euler's number key.
    public static func expressionValue(_ value: Double) -> String {
        if value.rounded(.towardZero) == value, abs(value) < 1e15 {
            return String(Int64(value))
        }
        let text = value.description.uppercased()
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }

    public static func display(_ value: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        let magnitude = abs(value)
        if magnitude != 0, magnitude >= 1e15 || magnitude < 1e-9 {
            formatter.numberStyle = .scientific
            formatter.maximumSignificantDigits = 12
        } else {
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 15
        }
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// A pasted number is read in the user's locale, so "1,000" is a thousand in the US
    /// and one in Germany. Anything else, such as an expression, passes through unchanged.
    public static func normalizedPaste(_ text: String, locale: Locale = .current) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        guard let number = formatter.number(from: trimmed) else { return trimmed }
        return expressionValue(number.doubleValue)
    }

    /// Drops fractional digits a currency cannot show, for when the active currency changes.
    public static func limitingFraction(of amount: String, to maximumDigits: Int) -> String {
        guard let dot = amount.firstIndex(of: ".") else { return amount }
        if maximumDigits == 0 { return String(amount[..<dot]) }
        let end = amount.index(dot, offsetBy: maximumDigits + 1, limitedBy: amount.endIndex) ?? amount.endIndex
        return String(amount[..<end])
    }

    /// Formats a number as it is being typed: the integer part is grouped, while the
    /// fractional digits stay literal so "1." and "1.0" remain visible mid-entry.
    public static func typedNumber(_ text: String, locale: Locale = .current) -> String {
        let isNegative = text.hasPrefix("-")
        let unsigned = isNegative ? String(text.dropFirst()) : text
        let parts = unsigned.split(separator: ".", omittingEmptySubsequences: false)
        guard
            parts.count <= 2,
            let integerPart = parts.first,
            !integerPart.isEmpty,
            parts.allSatisfy({ $0.allSatisfy(\.isASCIIDigit) })
        else {
            return text
        }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let grouped = formatter.string(from: NSDecimalNumber(string: String(integerPart))) ?? String(integerPart)
        let fraction = parts.count == 2 ? (formatter.decimalSeparator ?? ".") + parts[1] : ""
        return (isNegative ? "-" : "") + grouped + fraction
    }
}

private extension Character {
    var isASCIIDigit: Bool {
        isASCII && isNumber
    }
}

public struct CalculatorInputReducer: Sendable {
    public private(set) var expression = ""

    public init(expression: String = "") {
        self.expression = expression
    }

    public mutating func append(_ value: String) {
        if isOperator(value), let last = expression.last, isOperator(String(last)) {
            expression.removeLast()
            append(value)
            return
        }
        // "-" can start a number, but other operators need something on their left.
        if value != "-", isOperator(value) || value == "%" || value == "!" {
            guard let last = expression.last, last != "(", !isOperator(String(last)) else { return }
        }
        // "pi2" would read as an unknown name, so a digit after a constant multiplies it.
        if value.first?.isASCIIDigit == true, expression.last?.isLowercase == true {
            expression += "*"
        }
        expression += value
    }

    public mutating func appendDecimalPoint() {
        expression = Self.addingDecimalPoint(to: expression)
    }

    /// Appends a value that starts a new number, inserting a multiplication when it would
    /// otherwise merge into the number before it ("5" then "1/" must not become "51/").
    public mutating func appendFactor(_ value: String) {
        if let last = expression.last, last.isASCIIDigit || last.isLowercase || ".)!%".contains(last) {
            expression += "*"
        }
        expression += value
    }

    public mutating func appendNextParenthesis() {
        append(Self.nextParenthesis(for: expression))
    }

    public mutating func clear() {
        expression = ""
    }

    public mutating func replace(with value: String) {
        expression = value
    }

    public mutating func backspace() {
        expression = Self.removingLastToken(from: expression)
    }

    public static func addingDecimalPoint(to text: String) -> String {
        let currentNumber = text.reversed().prefix { $0.isASCIIDigit || $0 == "." }
        if currentNumber.isEmpty { return text + "0." }
        return currentNumber.contains(".") ? text : text + "."
    }

    public static func nextParenthesis(for input: String) -> String {
        guard let last = input.last else { return "(" }
        if ["+", "-", "/", "*", "^", "("].contains(last) { return "(" }

        var openCount = 0
        var closeCount = 0
        for character in input {
            if character == "(" {
                openCount += 1
            } else if character == ")" {
                closeCount += 1
            }
        }

        return openCount > closeCount ? ")" : "("
    }

    public static func removingLastToken(from text: String) -> String {
        guard !text.isEmpty else { return "" }

        let tokens = [
            "asinh(", "acosh(", "atanh(",
            "asin(", "acos(", "atan(",
            "sinh(", "cosh(", "tanh(",
            "sin(", "cos(", "tan(",
            "sqrt(", "log10(", "log(",
            "pi"
        ]

        if let token = tokens.first(where: { text.hasSuffix($0) }) {
            return String(text.dropLast(token.count))
        }

        return String(text.dropLast())
    }

    private func isOperator(_ value: String) -> Bool {
        ["+", "-", "*", "/", "^"].contains(value)
    }
}

private final class ExpressionParser {
    private let characters: [Character]
    private let angleMode: AngleMode
    private var index = 0
    /// Position just past the most recent `%`, while it can still apply to a left operand.
    private var percentEnd: Int?
    private var lastTermIsPercent = false

    init(expression: String, angleMode: AngleMode) {
        self.characters = expression
            .filter { !$0.isWhitespace }
            .map { $0 }
        self.angleMode = angleMode
    }

    func parse() throws -> Double {
        guard !characters.isEmpty else { throw CalculatorEngineError.invalidInput }
        let value = try parseExpression()
        guard isAtEnd else { throw CalculatorEngineError.invalidInput }
        return value
    }

    private var isAtEnd: Bool {
        index >= characters.count
    }

    private var current: Character? {
        isAtEnd ? nil : characters[index]
    }

    private func match(_ character: Character) -> Bool {
        guard current == character else { return false }
        index += 1
        return true
    }

    private func parseExpression() throws -> Double {
        var value = try parseTerm()

        while let character = current, character == "+" || character == "-" {
            index += 1
            let rhs = try parseTerm()
            // "100+10%" means 10% of 100, which is what calculators and mathjs both do.
            let operand = lastTermIsPercent ? value * rhs : rhs
            value = character == "+" ? value + operand : value - operand
        }

        return value
    }

    private func parseTerm() throws -> Double {
        var value = try parseUnary()
        var isSingleFactor = true

        while let character = current {
            if character == "*" || character == "/" {
                index += 1
                let rhs = try parseUnary()
                if character == "/" && rhs == 0 {
                    throw CalculatorEngineError.divisionByZero
                }
                value = character == "*" ? value * rhs : value / rhs
            } else if startsImplicitFactor(character) {
                value *= try parseUnary()
            } else {
                break
            }
            isSingleFactor = false
        }

        lastTermIsPercent = isSingleFactor && percentEnd == index
        return value
    }

    private func startsImplicitFactor(_ character: Character) -> Bool {
        character == "(" || character == "." || character.isNumber || character.isLetter
    }

    private func parseUnary() throws -> Double {
        if match("+") {
            return try parseUnary()
        }
        if match("-") {
            return -(try parseUnary())
        }
        return try parsePower()
    }

    private func parsePower() throws -> Double {
        let base = try parsePostfix()
        if match("^") {
            // The exponent goes through parseUnary so that "2^-1" works and "2^3^2" is
            // right-associative, while "-2^2" still negates the whole power.
            let exponent = try parseUnary()
            percentEnd = nil
            return pow(base, exponent)
        }
        return base
    }

    private func parsePostfix() throws -> Double {
        var value = try parsePrimary()

        while let character = current, character == "!" || character == "%" {
            index += 1
            if character == "!" {
                value = try factorial(value)
            } else {
                value /= 100
                percentEnd = index
            }
        }

        return value
    }

    private func parsePrimary() throws -> Double {
        if match("(") {
            let value = try parseExpression()
            guard match(")") else { throw CalculatorEngineError.expectedClosingParenthesis }
            return value
        }

        if let character = current, character.isNumber || character == "." {
            return try parseNumber()
        }

        if let character = current, character.isLetter {
            return try parseIdentifier()
        }

        throw CalculatorEngineError.invalidInput
    }

    private func parseNumber() throws -> Double {
        let start = index
        var decimalCount = 0

        while let character = current, character.isNumber || character == "." {
            if character == "." {
                decimalCount += 1
                guard decimalCount <= 1 else { throw CalculatorEngineError.invalidInput }
            }
            index += 1
        }
        consumeExponent()

        let value = String(characters[start..<index])
        guard let number = Double(value) else { throw CalculatorEngineError.invalidInput }
        return number
    }

    /// `E` may carry a sign, but `e` may not: on the keypad "2e+3" means 2 times Euler's
    /// number, plus 3. "1e5" has no such reading, so it is accepted for pasted values.
    private func consumeExponent() {
        guard let marker = current, marker == "E" || marker == "e" else { return }
        var next = index + 1
        if marker == "E", next < characters.count, "+-".contains(characters[next]) {
            next += 1
        }
        guard next < characters.count, characters[next].isASCIIDigit else { return }
        index = next
        while let character = current, character.isASCIIDigit {
            index += 1
        }
    }

    private func parseIdentifier() throws -> Double {
        let start = index
        while let character = current, character.isLetter || character.isNumber {
            index += 1
        }

        let identifier = String(characters[start..<index])
        switch identifier {
        case "pi":
            return .pi
        case "e":
            return Darwin.M_E
        default:
            guard match("(") else { throw CalculatorEngineError.unknownIdentifier(identifier) }
            let argument = try parseExpression()
            guard match(")") else { throw CalculatorEngineError.expectedClosingParenthesis }
            return try evaluateFunction(identifier, argument: argument)
        }
    }

    private func evaluateFunction(_ name: String, argument: Double) throws -> Double {
        switch name {
        case "sin":
            return trigResult(sin(angleMode.toRadians(argument)), argument: argument)
        case "cos":
            return trigResult(cos(angleMode.toRadians(argument)), argument: argument)
        case "tan":
            let radians = angleMode.toRadians(argument)
            // tan(90°) is undefined, but floating point only gets close and returns 1.6E16.
            guard abs(cos(radians)) > Self.trigNoise else { throw CalculatorEngineError.invalidInput }
            return trigResult(tan(radians), argument: argument)
        case "asin":
            return angleMode.fromRadians(asin(argument))
        case "acos":
            return angleMode.fromRadians(acos(argument))
        case "atan":
            return angleMode.fromRadians(atan(argument))
        case "sinh":
            return sinh(argument)
        case "cosh":
            return cosh(argument)
        case "tanh":
            return tanh(argument)
        case "asinh":
            return asinh(argument)
        case "acosh":
            return acosh(argument)
        case "atanh":
            return atanh(argument)
        case "sqrt":
            return sqrt(argument)
        case "log":
            return log(argument)
        case "log10":
            return log10(argument)
        default:
            throw CalculatorEngineError.unknownIdentifier(name)
        }
    }

    private static let trigNoise = 1e-14

    /// Snaps floating-point residue to zero, so that sin(180°) is 0 and not 1.2E-16. Tiny
    /// arguments are left alone because their small results are genuine.
    private func trigResult(_ result: Double, argument: Double) -> Double {
        abs(result) < Self.trigNoise && abs(angleMode.toRadians(argument)) > 1e-6 ? 0 : result
    }

    private func factorial(_ value: Double) throws -> Double {
        guard value >= 0, value.rounded(.towardZero) == value else {
            throw CalculatorEngineError.invalidFactorial
        }
        if value == 0 { return 1 }
        if value > 170 { throw CalculatorEngineError.invalidFactorial }
        return (1...Int(value)).map(Double.init).reduce(1, *)
    }
}
