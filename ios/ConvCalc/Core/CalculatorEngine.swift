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
    public var angleMode: AngleMode = .degrees

    public init(angleMode: AngleMode = .degrees) {
        self.angleMode = angleMode
    }

    public func evaluate(_ expression: String) throws -> Double {
        let parser = ExpressionParser(expression: expression, angleMode: angleMode)
        let result = try parser.parse()
        guard result.isFinite else { throw CalculatorEngineError.invalidInput }
        return Self.roundedResult(result)
    }

    public static func roundedResult(_ result: Double) -> Double {
        guard result.isFinite else { return result }
        if result == 0 { return 0 }
        if result.rounded(.towardZero) == result { return result }
        // Round at the edge of Double's precision (12 significant digits) rather
        // than to a fixed number of decimal places. This strips binary
        // floating-point noise (e.g. 0.1 + 0.2 = 0.30000000000000004) while
        // preserving as many real decimals as the value actually has.
        let exponent = floor(log10(abs(result)))
        let decimals = 12 - Int(exponent) - 1
        guard decimals > 0 else { return result }
        let factor = pow(10.0, Double(decimals))
        return (result * factor).rounded() / factor
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
            expression += value
            return
        }
        expression += value
    }

    public mutating func appendDecimalPoint() {
        if expression.isEmpty || expression.last.map({ "+-*/(".contains($0) }) == true {
            append("0.")
            return
        }

        let lastNumber = expression
            .split(whereSeparator: { "+-*/()".contains($0) })
            .last
            .map(String.init) ?? ""

        if lastNumber.isEmpty {
            append("0.")
        } else if !lastNumber.contains(".") {
            append(".")
        }
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

    public static func nextParenthesis(for input: String) -> String {
        guard let last = input.last else { return "(" }
        if ["+", "-", "/", "*", "("].contains(last) { return "(" }

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
        ["+", "-", "*", "/"].contains(value)
    }
}

private final class ExpressionParser {
    private let characters: [Character]
    private let angleMode: AngleMode
    private var index = 0

    init(expression: String, angleMode: AngleMode) {
        self.characters = expression
            .replacingOccurrences(of: ",", with: ".")
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
            value = character == "+" ? value + rhs : value - rhs
        }

        return value
    }

    private func parseTerm() throws -> Double {
        var value = try parsePower()

        while let character = current, character == "*" || character == "/" {
            index += 1
            let rhs = try parsePower()
            if character == "/" && rhs == 0 {
                throw CalculatorEngineError.divisionByZero
            }
            value = character == "*" ? value * rhs : value / rhs
        }

        return value
    }

    private func parsePower() throws -> Double {
        let base = try parseUnary()
        if match("^") {
            let exponent = try parsePower()
            return pow(base, exponent)
        }
        return base
    }

    private func parseUnary() throws -> Double {
        if match("+") {
            return try parseUnary()
        }
        if match("-") {
            return -(try parseUnary())
        }
        return try parsePostfix()
    }

    private func parsePostfix() throws -> Double {
        var value = try parsePrimary()

        while let character = current, character == "!" || character == "%" {
            index += 1
            if character == "!" {
                value = try factorial(value)
            } else {
                value /= 100
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

        let value = String(characters[start..<index])
        guard let number = Double(value) else { throw CalculatorEngineError.invalidInput }
        return number
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
            return sin(angleMode.toRadians(argument))
        case "cos":
            return cos(angleMode.toRadians(argument))
        case "tan":
            return tan(angleMode.toRadians(argument))
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

    private func factorial(_ value: Double) throws -> Double {
        guard value >= 0, value.rounded(.towardZero) == value else {
            throw CalculatorEngineError.invalidFactorial
        }
        if value == 0 { return 1 }
        if value > 170 { throw CalculatorEngineError.invalidFactorial }
        return (1...Int(value)).map(Double.init).reduce(1, *)
    }
}
