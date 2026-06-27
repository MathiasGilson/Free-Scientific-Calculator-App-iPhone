import Foundation

public struct UnitDefinition: Sendable {
    public let label: String
    public let name: String
    public let toBase: @Sendable (Double) -> Double
    public let fromBase: @Sendable (Double) -> Double

    public init(
        label: String,
        name: String,
        toBase: @escaping @Sendable (Double) -> Double,
        fromBase: @escaping @Sendable (Double) -> Double
    ) {
        self.label = label
        self.name = name
        self.toBase = toBase
        self.fromBase = fromBase
    }
}

public enum ConverterToolKind: Sendable {
    case unit
    case calculator
}

public struct ConverterTool: Identifiable, Equatable, Sendable {
    public let key: String
    public let label: String
    public let symbolName: String
    public let kind: ConverterToolKind
    public let units: [UnitDefinition]
    public let fields: [String]

    public var id: String { key }

    public init(key: String, label: String, symbolName: String, kind: ConverterToolKind, units: [UnitDefinition], fields: [String]) {
        self.key = key
        self.label = label
        self.symbolName = symbolName
        self.kind = kind
        self.units = units
        self.fields = fields
    }

    public static func == (lhs: ConverterTool, rhs: ConverterTool) -> Bool {
        lhs.key == rhs.key
    }
}

public struct ConversionResult: Identifiable, Equatable, Sendable {
    public let label: String
    public let name: String
    public let value: Double

    public var id: String { label }
}

public struct BMIResult: Equatable, Sendable {
    public let bmi: Double
    public let category: String

    public init(bmi: Double, category: String) {
        self.bmi = bmi
        self.category = category
    }
}

public struct AgeResult: Equatable, Sendable {
    public let years: Int
    public let months: Int
    public let days: Int

    public init(years: Int, months: Int, days: Int) {
        self.years = years
        self.months = months
        self.days = days
    }
}

public struct DateDifferenceResult: Equatable, Sendable {
    public let totalDays: Int
    public let weeks: Int
    public let months: Double
    public let years: Double

    public init(totalDays: Int, weeks: Int, months: Double, years: Double) {
        self.totalDays = totalDays
        self.weeks = weeks
        self.months = months
        self.years = years
    }
}

public struct LoanResult: Equatable, Sendable {
    public let monthly: Double
    public let totalPaid: Double
    public let totalInterest: Double

    public init(monthly: Double, totalPaid: Double, totalInterest: Double) {
        self.monthly = monthly
        self.totalPaid = totalPaid
        self.totalInterest = totalInterest
    }
}

public struct DiscountResult: Equatable, Sendable {
    public let savings: Double
    public let finalPrice: Double

    public init(savings: Double, finalPrice: Double) {
        self.savings = savings
        self.finalPrice = finalPrice
    }
}

public enum ConverterCore {
    public static func convertToAll(value: Double, fromIndex: Int, units: [UnitDefinition]) -> [ConversionResult] {
        guard units.indices.contains(fromIndex) else { return [] }
        let baseValue = units[fromIndex].toBase(value)
        return units.enumerated().map { index, unit in
            ConversionResult(
                label: unit.label,
                name: unit.name,
                value: index == fromIndex ? value : unit.fromBase(baseValue)
            )
        }
    }

    public static func formatConversionResult(_ value: Double) -> String {
        if value == 0 { return "0" }
        let absolute = abs(value)
        if absolute >= 1e12 || (absolute < 1e-6 && absolute > 0) {
            return String(format: "%.4e", value)
        }

        let integerDigits = absolute >= 1 ? Int(floor(log10(absolute))) + 1 : 1
        let maximumFractionDigits = max(0, 8 - integerDigits)
        let rounded = Double(String(format: "%.\(maximumFractionDigits)f", value)) ?? value
        return NumberFormatter.compactDecimal(maximumFractionDigits: maximumFractionDigits).string(from: NSNumber(value: rounded)) ?? "\(rounded)"
    }

    public static func formatNumber(_ value: Double, decimals: Int = 2) -> String {
        NumberFormatter.compactDecimal(maximumFractionDigits: decimals).string(from: NSNumber(value: value)) ?? "\(value)"
    }

    public static func calculateBMI(heightCm: Double, weightKg: Double) -> BMIResult? {
        guard heightCm > 0, weightKg > 0 else { return nil }
        let heightM = heightCm / 100
        let bmi = weightKg / (heightM * heightM)
        let category: String
        if bmi < 18.5 {
            category = "Underweight"
        } else if bmi < 25 {
            category = "Normal"
        } else if bmi < 30 {
            category = "Overweight"
        } else {
            category = "Obese"
        }
        return BMIResult(bmi: (bmi * 10).rounded() / 10, category: category)
    }

    public static func calculateAge(
        year: Int,
        month: Int,
        day: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AgeResult? {
        guard let birth = makeDate(year: year, month: month, day: day, calendar: calendar), birth <= now else {
            return nil
        }

        let start = calendar.startOfDay(for: birth)
        let end = calendar.startOfDay(for: now)
        let components = calendar.dateComponents([.year, .month, .day], from: start, to: end)

        guard
            let years = components.year,
            let months = components.month,
            let days = components.day
        else {
            return nil
        }

        return AgeResult(years: years, months: months, days: days)
    }

    public static func calculateDateDiff(
        year1: Int,
        month1: Int,
        day1: Int,
        year2: Int,
        month2: Int,
        day2: Int,
        calendar: Calendar = .current
    ) -> DateDifferenceResult? {
        guard
            let date1 = makeDate(year: year1, month: month1, day: day1, calendar: calendar),
            let date2 = makeDate(year: year2, month: month2, day: day2, calendar: calendar)
        else {
            return nil
        }

        let start = calendar.startOfDay(for: min(date1, date2))
        let end = calendar.startOfDay(for: max(date1, date2))
        guard let totalDays = calendar.dateComponents([.day], from: start, to: end).day else { return nil }

        let weeks = totalDays / 7
        let months = (Double(totalDays) / 30.4375 * 10).rounded() / 10
        let years = (Double(totalDays) / 365.25 * 100).rounded() / 100
        return DateDifferenceResult(totalDays: totalDays, weeks: weeks, months: months, years: years)
    }

    public static func calculateLoan(principal: Double, rate: Double, years: Double) -> LoanResult? {
        guard principal > 0, rate > 0, years > 0 else { return nil }
        let monthlyRate = rate / 100 / 12
        let numberOfPayments = years * 12
        let monthly = principal * (monthlyRate * pow(1 + monthlyRate, numberOfPayments)) / (pow(1 + monthlyRate, numberOfPayments) - 1)
        let totalPaid = monthly * numberOfPayments
        let totalInterest = totalPaid - principal
        return LoanResult(
            monthly: roundCurrency(monthly),
            totalPaid: roundCurrency(totalPaid),
            totalInterest: roundCurrency(totalInterest)
        )
    }

    public static func calculateDiscount(price: Double, percent: Double) -> DiscountResult? {
        guard price >= 0, percent >= 0 else { return nil }
        let savings = price * (percent / 100)
        return DiscountResult(savings: roundCurrency(savings), finalPrice: roundCurrency(price - savings))
    }

    private static func roundCurrency(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    private static func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        var components = DateComponents()
        components.calendar = calendar
        components.year = year
        components.month = month
        components.day = day
        guard let date = calendar.date(from: components) else { return nil }
        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == year, resolved.month == month, resolved.day == day else { return nil }
        return date
    }
}

extension NumberFormatter {
    public static func compactDecimal(maximumFractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter
    }
}

private func linear(_ factor: Double) -> @Sendable (Double) -> Double {
    { $0 * factor }
}

private func inverseLinear(_ factor: Double) -> @Sendable (Double) -> Double {
    { $0 / factor }
}

private func unit(_ label: String, _ name: String, factor: Double) -> UnitDefinition {
    UnitDefinition(label: label, name: name, toBase: linear(factor), fromBase: inverseLinear(factor))
}

extension ConverterTool {
    public static let all: [ConverterTool] = [
        ConverterTool(key: "currency", label: "Currency", symbolName: "dollarSign", kind: .calculator, units: [], fields: []),
        ConverterTool(key: "length", label: "Length", symbolName: "ruler", kind: .unit, units: [
            unit("mm", "Millimeter", factor: 0.001),
            unit("cm", "Centimeter", factor: 0.01),
            unit("m", "Meter", factor: 1),
            unit("km", "Kilometer", factor: 1_000),
            unit("in", "Inch", factor: 0.0254),
            unit("ft", "Foot", factor: 0.3048),
            unit("yd", "Yard", factor: 0.9144),
            unit("mi", "Mile", factor: 1_609.344)
        ], fields: []),
        ConverterTool(key: "area", label: "Area", symbolName: "grid2X2", kind: .unit, units: [
            unit("m²", "Square Meter", factor: 1),
            unit("ft²", "Square Foot", factor: 0.092903),
            unit("km²", "Square Kilometer", factor: 1e6),
            unit("mi²", "Square Mile", factor: 2_589_988.11),
            unit("acres", "Acre", factor: 4_046.8564),
            unit("ha", "Hectare", factor: 10_000)
        ], fields: []),
        ConverterTool(key: "mass", label: "Mass", symbolName: "scale", kind: .unit, units: [
            unit("mg", "Milligram", factor: 0.000001),
            unit("g", "Gram", factor: 0.001),
            unit("kg", "Kilogram", factor: 1),
            unit("dr", "Dram", factor: 0.001771845195),
            unit("oz", "Ounce", factor: 0.028349523),
            unit("lb", "Pound", factor: 0.45359237),
            unit("st", "Stone", factor: 6.35029318),
            unit("slug", "Slug", factor: 14.593903),
            unit("short tn", "Short Ton", factor: 907.18474),
            unit("long tn", "Long Ton", factor: 1_016.0469088),
            unit("t", "Metric Ton", factor: 1_000)
        ], fields: []),
        ConverterTool(key: "volume", label: "Volume", symbolName: "testTubes", kind: .unit, units: [
            unit("ml", "Milliliter", factor: 0.001),
            unit("L", "Liter", factor: 1),
            unit("gal", "Gallon", factor: 3.785411784),
            unit("qt", "Quart", factor: 0.946352946),
            unit("pt", "Pint", factor: 0.473176473),
            unit("cup", "Cup", factor: 0.2365882365),
            unit("fl oz", "Fluid Ounce", factor: 0.029573529)
        ], fields: []),
        ConverterTool(key: "speed", label: "Speed", symbolName: "gauge", kind: .unit, units: [
            unit("m/s", "Meter per Second", factor: 1),
            unit("km/h", "Kilometer per Hour", factor: 1 / 3.6),
            unit("mph", "Mile per Hour", factor: 0.44704),
            unit("knots", "Knot", factor: 0.514444)
        ], fields: []),
        ConverterTool(key: "pressure", label: "Pressure", symbolName: "arrowDownToLine", kind: .unit, units: [
            unit("Pa", "Pascal", factor: 1),
            unit("kPa", "Kilopascal", factor: 1_000),
            unit("bar", "Bar", factor: 100_000),
            unit("atm", "Atmosphere", factor: 101_325),
            unit("PSI", "Pound per Sq Inch", factor: 6_894.757293168),
            unit("inHg", "Inch of Mercury", factor: 3_386.389),
            unit("Torr", "Torr", factor: 133.3223684211)
        ], fields: []),
        ConverterTool(key: "power", label: "Power", symbolName: "bolt", kind: .unit, units: [
            unit("W", "Watt", factor: 1),
            unit("kW", "Kilowatt", factor: 1_000),
            unit("hp", "Horsepower", factor: 745.69987158),
            unit("BTU/min", "BTU per Minute", factor: 17.584264)
        ], fields: []),
        ConverterTool(key: "temperature", label: "Temp", symbolName: "thermometer", kind: .unit, units: [
            UnitDefinition(label: "°C", name: "Celsius", toBase: { $0 }, fromBase: { $0 }),
            UnitDefinition(label: "°F", name: "Fahrenheit", toBase: { ($0 - 32) * 5 / 9 }, fromBase: { $0 * 9 / 5 + 32 }),
            UnitDefinition(label: "K", name: "Kelvin", toBase: { $0 - 273.15 }, fromBase: { $0 + 273.15 })
        ], fields: []),
        ConverterTool(key: "angle", label: "Angle", symbolName: "triangle", kind: .unit, units: [
            unit("rad", "Radian", factor: 1),
            unit("mrad", "Milliradian", factor: 0.001),
            unit("µrad", "Microradian", factor: 0.000001),
            unit("°", "Degree", factor: .pi / 180),
            unit("arcmin", "Arcminute", factor: .pi / 10_800),
            unit("arcsec", "Arcsecond", factor: .pi / 648_000),
            unit("mas", "Milliarcsecond", factor: .pi / 648_000_000),
            unit("µas", "Microarcsecond", factor: .pi / 648_000_000_000)
        ], fields: []),
        ConverterTool(key: "energy", label: "Energy", symbolName: "flame", kind: .unit, units: [
            unit("J", "Joule", factor: 1),
            unit("kJ", "Kilojoule", factor: 1_000),
            unit("cal", "Calorie", factor: 4.184),
            unit("kcal", "Kilocalorie", factor: 4_184),
            unit("BTU", "British Thermal Unit", factor: 1_055.06),
            unit("kWh", "Kilowatt-Hour", factor: 3_600_000),
            unit("erg", "Erg", factor: 0.0000001),
            unit("ft·lbf", "Foot-Pound", factor: 1.3558179483),
            unit("N·m", "Newton-Meter", factor: 1)
        ], fields: []),
        ConverterTool(key: "force", label: "Force", symbolName: "arrowUpDown", kind: .unit, units: [
            unit("N", "Newton", factor: 1),
            unit("kgf", "Kilogram-Force", factor: 9.80665),
            unit("lbf", "Pound-Force", factor: 4.4482216152605),
            unit("pdl", "Poundal", factor: 0.138254954376),
            unit("dyn", "Dyne", factor: 0.00001)
        ], fields: []),
        ConverterTool(key: "fuel", label: "Fuel", symbolName: "fuel", kind: .unit, units: [
            unit("km/L", "Kilometer per Liter", factor: 1),
            unit("mpg", "Mile per Gallon", factor: 0.425143707),
            UnitDefinition(label: "L/100km", name: "Liter per 100km", toBase: { 100 / $0 }, fromBase: { 100 / $0 }),
            UnitDefinition(label: "gal/100mi", name: "Gallon per 100mi", toBase: { 42.51437 / $0 }, fromBase: { 42.51437 / $0 })
        ], fields: []),
        ConverterTool(key: "time", label: "Time", symbolName: "clock", kind: .unit, units: [
            unit("ms", "Millisecond", factor: 0.001),
            unit("s", "Second", factor: 1),
            unit("min", "Minute", factor: 60),
            unit("hr", "Hour", factor: 3_600),
            unit("day", "Day", factor: 86_400),
            unit("week", "Week", factor: 604_800),
            unit("year", "Year", factor: 31_557_600)
        ], fields: []),
        ConverterTool(key: "data", label: "Data", symbolName: "hardDrive", kind: .unit, units: [
            unit("B", "Byte", factor: 1),
            unit("KB", "Kilobyte", factor: 1_024),
            unit("MB", "Megabyte", factor: 1_048_576),
            unit("GB", "Gigabyte", factor: 1_073_741_824),
            unit("TB", "Terabyte", factor: 1_099_511_627_776),
            unit("PB", "Petabyte", factor: 1_125_899_906_842_624)
        ], fields: []),
        ConverterTool(key: "age", label: "Age", symbolName: "cake", kind: .calculator, units: [], fields: ["year", "month", "day"]),
        ConverterTool(key: "bmi", label: "BMI", symbolName: "heart", kind: .calculator, units: [], fields: ["height", "weight"]),
        ConverterTool(key: "date", label: "Date", symbolName: "calendar", kind: .calculator, units: [], fields: ["year1", "month1", "day1", "year2", "month2", "day2"]),
        ConverterTool(key: "discount", label: "Discount", symbolName: "tag", kind: .calculator, units: [], fields: ["price", "percent"]),
        ConverterTool(key: "loan", label: "Loan", symbolName: "landmark", kind: .calculator, units: [], fields: ["principal", "rate", "years"])
    ]
}

public struct CurrencyInfo: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let symbol: String
    public let name: String
    public let decimalDigits: Int
    public let code: String
    public let popular: Bool?

    public init(id: String, symbol: String, name: String, decimalDigits: Int, code: String, popular: Bool?) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.decimalDigits = decimalDigits
        self.code = code
        self.popular = popular
    }

    enum CodingKeys: String, CodingKey {
        case id
        case symbol
        case name
        case decimalDigits = "decimal_digits"
        case code
        case popular
    }
}

public enum CurrencyCatalog {
    public static func load(bundle: Bundle = .main) -> [String: CurrencyInfo] {
        guard
            let url = bundle.url(forResource: "currencies", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([String: CurrencyInfo].self, from: data)
        else {
            return fallback
        }
        return decoded
    }

    private static let fallback: [String: CurrencyInfo] = [
        "USD": CurrencyInfo(id: "usd", symbol: "$", name: "US Dollar", decimalDigits: 2, code: "USD", popular: true),
        "EUR": CurrencyInfo(id: "eur", symbol: "€", name: "Euro", decimalDigits: 2, code: "EUR", popular: true),
        "GBP": CurrencyInfo(id: "gbp", symbol: "£", name: "British Pound", decimalDigits: 2, code: "GBP", popular: true),
        "JPY": CurrencyInfo(id: "jpy", symbol: "¥", name: "Japanese Yen", decimalDigits: 0, code: "JPY", popular: true)
    ]
}

public struct ExchangeRateResponse: Decodable, Sendable {
    public let rates: [String: Double]
}

public struct PublicExchangeRateResponse: Decodable, Sendable {
    public let result: String
    public let timeLastUpdateUnix: TimeInterval
    public let rates: [String: Double]

    enum CodingKeys: String, CodingKey {
        case result
        case timeLastUpdateUnix = "time_last_update_unix"
        case rates
    }
}

public struct CurrencyRateSnapshot: Codable, Equatable, Sendable {
    public let rates: [String: Double]
    public let updatedAt: Date

    public init(rates: [String: Double], updatedAt: Date) {
        self.rates = rates
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case rates
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rates = try container.decode([String: Double].self, forKey: .rates)

        if let timestamp = try? container.decode(Double.self, forKey: .updatedAt) {
            if timestamp > 1_000_000_000_000 {
                updatedAt = Date(timeIntervalSince1970: timestamp / 1_000)
            } else if timestamp > 1_000_000_000 {
                updatedAt = Date(timeIntervalSince1970: timestamp)
            } else {
                updatedAt = Date(timeIntervalSinceReferenceDate: timestamp)
            }
        } else {
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rates, forKey: .rates)
        try container.encode(updatedAt.timeIntervalSince1970 * 1_000, forKey: .updatedAt)
    }
}

public enum CurrencyRateStore {
    private static let key = "ratesData"
    public static let refreshInterval: TimeInterval = 60 * 60

    public static let fallbackRates: [String: Double] = [
        "USD": 1.0,
        "EUR": 0.93,
        "GBP": 0.79,
        "JPY": 157.0,
        "CAD": 1.37,
        "AUD": 1.52,
        "CHF": 0.90,
        "CNY": 7.25,
        "BTC": 0.000016
    ]

    public static func load(defaults: UserDefaults = .standard) -> CurrencyRateSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CurrencyRateSnapshot.self, from: data)
    }

    public static func save(_ snapshot: CurrencyRateSnapshot, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    public static func shouldRefresh(_ snapshot: CurrencyRateSnapshot?, now: Date = Date()) -> Bool {
        guard let snapshot else { return true }
        return now.timeIntervalSince(snapshot.updatedAt) >= refreshInterval
    }

    public static func token(bundle: Bundle = .main) -> String? {
        if let token = bundle.object(forInfoDictionaryKey: "EXCHANGE_RATE_TOKEN") as? String, !token.isEmpty {
            return token
        }
        let envToken = ProcessInfo.processInfo.environment["EXPO_PUBLIC_EXCHANGE_RATE_TOKEN"]
        return envToken?.isEmpty == false ? envToken : nil
    }

    public static func fetch(token: String, session: URLSession = .shared) async throws -> CurrencyRateSnapshot {
        var components = URLComponents(string: "https://api.billingjs.com/getExchangeRates")
        components?.queryItems = [URLQueryItem(name: "auth", value: token)]
        guard let url = components?.url else { throw URLError(.badURL) }
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)
        return CurrencyRateSnapshot(rates: response.rates, updatedAt: Date())
    }

    public static func fetchPublic(session: URLSession = .shared) async throws -> CurrencyRateSnapshot {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(PublicExchangeRateResponse.self, from: data)
        guard response.result == "success" else { throw URLError(.cannotParseResponse) }

        let mergedRates = fallbackRates.merging(response.rates) { _, liveRate in liveRate }
        return CurrencyRateSnapshot(
            rates: mergedRates,
            updatedAt: Date()
        )
    }
}
