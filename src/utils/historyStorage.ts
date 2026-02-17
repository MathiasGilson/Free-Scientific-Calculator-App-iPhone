import AsyncStorage from "@react-native-async-storage/async-storage"

const HISTORY_KEY = "calculationHistory"
const MAX_ENTRIES = 100

export type CalculationEntry = {
    expression: string
    result: string
    timestamp: number
}

export async function saveCalculation(expression: string, result: string): Promise<void> {
    const entry: CalculationEntry = { expression, result, timestamp: Date.now() }
    const existing = await getHistory()
    const updated = [entry, ...existing].slice(0, MAX_ENTRIES)
    await AsyncStorage.setItem(HISTORY_KEY, JSON.stringify(updated))
}

export async function getHistory(): Promise<CalculationEntry[]> {
    const raw = await AsyncStorage.getItem(HISTORY_KEY)
    if (!raw) return []
    try {
        return JSON.parse(raw)
    } catch {
        return []
    }
}

export async function clearHistory(): Promise<void> {
    await AsyncStorage.removeItem(HISTORY_KEY)
}
