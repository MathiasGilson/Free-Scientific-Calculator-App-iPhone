import { UnitDef } from "../data/converterTools"

export function convertToAll(
    value: number,
    fromIndex: number,
    units: UnitDef[]
): { label: string; name: string; value: number }[] {
    const baseValue = units[fromIndex].toBase(value)
    return units.map((unit, i) => ({
        label: unit.label,
        name: unit.name,
        value: i === fromIndex ? value : unit.fromBase(baseValue),
    }))
}

export function formatConversionResult(value: number): string {
    if (value === 0) return "0"
    const abs = Math.abs(value)
    if (abs >= 1e12 || (abs < 1e-6 && abs > 0)) {
        return value.toExponential(4)
    }
    // Limit total significant digits to keep numbers compact
    const intDigits = abs >= 1 ? Math.floor(Math.log10(abs)) + 1 : 1
    const maxFraction = Math.max(0, 8 - intDigits)
    const cleaned = parseFloat(value.toFixed(maxFraction))
    return cleaned.toLocaleString("en-US", { maximumFractionDigits: maxFraction })
}

export function formatNumber(value: number, decimals = 2): string {
    return value.toLocaleString("en-US", { minimumFractionDigits: 0, maximumFractionDigits: decimals })
}

export function calculateBMI(heightCm: number, weightKg: number) {
    if (heightCm <= 0 || weightKg <= 0) return null
    const heightM = heightCm / 100
    const bmi = weightKg / (heightM * heightM)
    let category = ""
    if (bmi < 18.5) category = "Underweight"
    else if (bmi < 25) category = "Normal"
    else if (bmi < 30) category = "Overweight"
    else category = "Obese"
    return { bmi: Math.round(bmi * 10) / 10, category }
}

export function calculateAge(year: number, month: number, day: number) {
    const birth = new Date(year, month - 1, day)
    const now = new Date()
    if (isNaN(birth.getTime()) || birth > now) return null

    let years = now.getFullYear() - birth.getFullYear()
    let months = now.getMonth() - birth.getMonth()
    let days = now.getDate() - birth.getDate()

    if (days < 0) {
        months--
        const prevMonth = new Date(now.getFullYear(), now.getMonth(), 0)
        days += prevMonth.getDate()
    }
    if (months < 0) {
        years--
        months += 12
    }
    return { years, months, days }
}

export function calculateDateDiff(
    y1: number, m1: number, d1: number,
    y2: number, m2: number, d2: number
) {
    const date1 = new Date(y1, m1 - 1, d1)
    const date2 = new Date(y2, m2 - 1, d2)
    if (isNaN(date1.getTime()) || isNaN(date2.getTime())) return null

    const diffMs = Math.abs(date2.getTime() - date1.getTime())
    const totalDays = Math.floor(diffMs / 86400000)
    const weeks = Math.floor(totalDays / 7)
    const months = Math.round(totalDays / 30.4375 * 10) / 10
    const years = Math.round(totalDays / 365.25 * 100) / 100
    return { totalDays, weeks, months, years }
}

export function calculateLoan(principal: number, rate: number, years: number) {
    if (principal <= 0 || rate <= 0 || years <= 0) return null
    const monthlyRate = rate / 100 / 12
    const numPayments = years * 12
    const monthly = principal * (monthlyRate * Math.pow(1 + monthlyRate, numPayments)) / (Math.pow(1 + monthlyRate, numPayments) - 1)
    const totalPaid = monthly * numPayments
    const totalInterest = totalPaid - principal
    return {
        monthly: Math.round(monthly * 100) / 100,
        totalPaid: Math.round(totalPaid * 100) / 100,
        totalInterest: Math.round(totalInterest * 100) / 100,
    }
}

export function calculateDiscount(price: number, percent: number) {
    if (price < 0 || percent < 0) return null
    const savings = price * (percent / 100)
    const finalPrice = price - savings
    return {
        savings: Math.round(savings * 100) / 100,
        finalPrice: Math.round(finalPrice * 100) / 100,
    }
}
