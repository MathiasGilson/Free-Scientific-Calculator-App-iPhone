import React, { useState, useMemo } from "react"
import {
    Text,
    View,
    StyleSheet,
    TouchableOpacity,
    ScrollView,
    Dimensions,
} from "react-native"
import { ConverterTool } from "../data/converterTools"
import {
    convertToAll,
    formatConversionResult,
    calculateBMI,
    calculateAge,
    calculateDateDiff,
    calculateDiscount,
} from "../utils/conversions"
import { hapticFeedback, hapticFeedbackSwitch } from "../utils"
import Button from "./Button"
import LucideIcon from "./LucideIcon"

const { width: screenWidth } = Dimensions.get("window")
const BUTTON_SIZE = (screenWidth - 40) / 4

type Props = {
    tool: ConverterTool
    onBack?: () => void
    isPinned?: boolean
    onTogglePin?: () => void
}

export default ({ tool, onBack, isPinned, onTogglePin }: Props) => {
    if (tool.type === "unit") return <UnitConverter tool={tool} onBack={onBack} isPinned={isPinned} onTogglePin={onTogglePin} />
    return <CalculatorView tool={tool} onBack={onBack} isPinned={isPinned} onTogglePin={onTogglePin} />
}

// ─── Unit Converter ───────────────────────────────────────────

function UnitConverter({ tool, onBack, isPinned, onTogglePin }: Props) {
    const [input, setInput] = useState("1")
    const [inputEdited, setInputEdited] = useState(false)
    const [fromIndex, setFromIndex] = useState(0)

    const results = useMemo(() => {
        const num = parseFloat(input) || 0
        return convertToAll(num, fromIndex, tool.units!)
    }, [input, fromIndex])

    const appendValue = (v: string) => {
        if (!inputEdited) {
            setInputEdited(true)
            if (v === ".") {
                setInput("0.")
            } else {
                setInput(v)
            }
            return
        }
        if (v === "." && input.includes(".")) return
        setInput(input === "0" && v !== "." ? v : input + v)
    }

    const backspace = () => {
        setInputEdited(true)
        setInput(input.length <= 1 ? "0" : input.slice(0, -1))
    }
    const clear = () => {
        setInputEdited(true)
        setInput("0")
    }

    return (
        <View style={styles.container}>
            <Header icon={tool.icon} label={tool.label} onBack={onBack} isPinned={isPinned} onTogglePin={onTogglePin} />

            <ScrollView style={styles.resultsList} contentContainerStyle={{ paddingBottom: 10 }}>
                {results.map((r, i) => (
                    <TouchableOpacity
                        key={r.label}
                        style={[styles.resultRow, i === fromIndex && styles.resultRowActive]}
                        onPress={() => {
                            setFromIndex(i)
                            setInput("1")
                            setInputEdited(false)
                        }}
                    >
                        <Text style={[styles.resultLabel, i === fromIndex && { color: "white", fontSize: 22 }]}>{r.label}</Text>
                        <Text style={[styles.resultValue, i === fromIndex && { color: "#F69A06", fontSize: 26 }]} numberOfLines={1}>
                            {formatConversionResult(r.value)}
                        </Text>
                    </TouchableOpacity>
                ))}
            </ScrollView>

            <Keypad appendValue={appendValue} onClear={clear} onBackspace={backspace} />
        </View>
    )
}

// ─── Calculator View ──────────────────────────────────────────

type CalcFieldConfig = {
    key: string
    label: string
    placeholder: string
}

const calcFieldConfigs: Record<string, CalcFieldConfig[]> = {
    age: [
        { key: "year", label: "Year", placeholder: "1990" },
        { key: "month", label: "Month", placeholder: "1" },
        { key: "day", label: "Day", placeholder: "1" },
    ],
    bmi: [
        { key: "height", label: "Height (cm)", placeholder: "170" },
        { key: "weight", label: "Weight (kg)", placeholder: "70" },
    ],
    date: [
        { key: "year1", label: "Year 1", placeholder: "2024" },
        { key: "month1", label: "Month 1", placeholder: "1" },
        { key: "day1", label: "Day 1", placeholder: "1" },
        { key: "year2", label: "Year 2", placeholder: "2025" },
        { key: "month2", label: "Month 2", placeholder: "1" },
        { key: "day2", label: "Day 2", placeholder: "1" },
    ],
    discount: [
        { key: "price", label: "Price", placeholder: "100" },
        { key: "percent", label: "%", placeholder: "20" },
    ],
}

function CalculatorView({ tool, onBack, isPinned, onTogglePin }: Props) {
    const fields = calcFieldConfigs[tool.key] || []
    const initialValues: Record<string, string> = {}
    fields.forEach((f) => (initialValues[f.key] = f.placeholder))
    const [values, setValues] = useState(initialValues)
    const [activeField, setActiveField] = useState(fields[0]?.key || "")
    const [editedFields, setEditedFields] = useState<Record<string, boolean>>({})

    const result = useMemo(() => {
        const nums: Record<string, number> = {}
        for (const f of fields) {
            nums[f.key] = parseFloat(values[f.key]) || 0
        }

        switch (tool.key) {
            case "age":
                return calculateAge(nums.year, nums.month, nums.day)
            case "bmi":
                return calculateBMI(nums.height, nums.weight)
            case "date":
                return calculateDateDiff(
                    nums.year1, nums.month1, nums.day1,
                    nums.year2, nums.month2, nums.day2
                )
            case "discount":
                return calculateDiscount(nums.price, nums.percent)
            default:
                return null
        }
    }, [values])

    const appendValue = (v: string) => {
        if (!editedFields[activeField]) {
            setEditedFields({ ...editedFields, [activeField]: true })
            if (v === ".") {
                setValues({ ...values, [activeField]: "0." })
            } else {
                setValues({ ...values, [activeField]: v })
            }
            return
        }
        const cur = values[activeField] || ""
        if (v === "." && cur.includes(".")) return
        const next = cur === "0" && v !== "." ? v : cur + v
        setValues({ ...values, [activeField]: next })
    }
    const backspace = () => {
        setEditedFields({ ...editedFields, [activeField]: true })
        const cur = values[activeField] || ""
        setValues({ ...values, [activeField]: cur.length <= 1 ? "" : cur.slice(0, -1) })
    }
    const clear = () => {
        setEditedFields({ ...editedFields, [activeField]: true })
        setValues({ ...values, [activeField]: "" })
    }

    return (
        <View style={styles.container}>
            <Header icon={tool.icon} label={tool.label} onBack={onBack} isPinned={isPinned} onTogglePin={onTogglePin} />

            <ScrollView style={styles.resultsList} contentContainerStyle={{ paddingBottom: 10 }}>
                {fields.map((f) => (
                    <TouchableOpacity
                        key={f.key}
                        style={[styles.calcFieldRow, activeField === f.key && styles.resultRowActive]}
                        onPress={() => setActiveField(f.key)}
                    >
                        <Text style={styles.resultLabel}>{f.label}</Text>
                        <Text style={[styles.resultValue, activeField === f.key && { color: "#F69A06" }]}>
                            {values[f.key] || f.placeholder}
                        </Text>
                    </TouchableOpacity>
                ))}

                {result && (
                    <View style={styles.calcResult}>
                        {renderCalcResult(tool.key, result)}
                    </View>
                )}
            </ScrollView>

            <Keypad appendValue={appendValue} onClear={clear} onBackspace={backspace} />
        </View>
    )
}

function renderCalcResult(key: string, result: any) {
    switch (key) {
        case "age":
            return (
                <>
                    <Text style={styles.calcResultTitle}>Age</Text>
                    <Text style={styles.calcResultText}>
                        {result.years} years, {result.months} months, {result.days} days
                    </Text>
                </>
            )
        case "bmi":
            return (
                <>
                    <Text style={styles.calcResultTitle}>BMI</Text>
                    <Text style={styles.calcResultText}>
                        {result.bmi} — {result.category}
                    </Text>
                </>
            )
        case "date":
            return (
                <>
                    <Text style={styles.calcResultTitle}>Difference</Text>
                    <Text style={styles.calcResultText}>{result.totalDays} days</Text>
                    <Text style={styles.calcResultText}>{result.weeks} weeks</Text>
                    <Text style={styles.calcResultText}>{result.months} months</Text>
                    <Text style={styles.calcResultText}>{result.years} years</Text>
                </>
            )
        case "discount":
            return (
                <>
                    <Text style={styles.calcResultTitle}>Result</Text>
                    <Text style={styles.calcResultText}>Savings: {result.savings}</Text>
                    <Text style={styles.calcResultText}>Final price: {result.finalPrice}</Text>
                </>
            )
        default:
            return null
    }
}

// ─── Shared Components ────────────────────────────────────────

function Header({ icon, label, onBack, isPinned, onTogglePin }: {
    icon: string
    label: string
    onBack?: () => void
    isPinned?: boolean
    onTogglePin?: () => void
}) {
    return (
        <View style={styles.header}>
            {onBack ? (
                <TouchableOpacity onPress={onBack} style={styles.backButton}>
                    <Text style={styles.backText}>‹ Back</Text>
                </TouchableOpacity>
            ) : (
                <View style={styles.backButton} />
            )}
            <View style={styles.headerCenter}>
                <LucideIcon name={icon} size={20} color="white" />
                <Text style={styles.headerTitle}>{label}</Text>
            </View>
            {onTogglePin ? (
                <TouchableOpacity onPress={onTogglePin} style={[styles.backButton, { alignItems: "flex-end" }]}>
                    <LucideIcon name={isPinned ? "pin-filled" : "pin"} size={20} color="#999" />
                </TouchableOpacity>
            ) : (
                <View style={styles.backButton} />
            )}
        </View>
    )
}

function Keypad({
    appendValue,
    onClear,
    onBackspace,
}: {
    appendValue: (v: string) => void
    onClear: () => void
    onBackspace: () => void
}) {
    return (
        <View style={styles.keyboard}>
            <View style={styles.numberButtons}>
                {[
                    { value: "3" }, { value: "2" }, { value: "1" },
                    { value: "6" }, { value: "5" }, { value: "4" },
                    { value: "9" }, { value: "8" }, { value: "7" },
                    { value: "." }, { value: "0" },
                ].map((btn) => (
                    <View style={{ width: BUTTON_SIZE, height: BUTTON_SIZE, padding: 5 }} key={btn.value}>
                        <Button type="number" theme="default" value={btn.value} onPress={() => appendValue(btn.value)} />
                    </View>
                ))}
            </View>
            <View style={styles.actionButtons}>
                <View style={styles.actionButtonWrapper}>
                    <TouchableOpacity style={styles.actionButton} onPressIn={hapticFeedbackSwitch} onPress={onClear}>
                        <Text style={{ color: "#BF7600", fontSize: 30 }}>AC</Text>
                    </TouchableOpacity>
                </View>
                <View style={styles.actionButtonWrapper}>
                    <TouchableOpacity
                        onPressIn={hapticFeedback}
                        style={[styles.actionButton, { backgroundColor: "#F69A06" }]}
                        onPress={onBackspace}
                    >
                        <Text style={{ color: "white", fontSize: 35 }}>⌫</Text>
                    </TouchableOpacity>
                </View>
            </View>
        </View>
    )
}

// ─── Styles ───────────────────────────────────────────────────

const styles = StyleSheet.create({
    container: {
        flex: 1,
        width: "100%",
        backgroundColor: "black",
    },
    header: {
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "space-between",
        paddingHorizontal: 16,
        paddingVertical: 10,
        marginBottom: 8,
    },
    backButton: {
        width: 70,
    },
    backText: {
        color: "#F69A06",
        fontSize: 18,
    },
    headerCenter: {
        flexDirection: "row",
        alignItems: "center",
        gap: 6,
    },
    headerTitle: {
        color: "white",
        fontSize: 20,
        fontWeight: "600",
    },
    resultsList: {
        flex: 1,
        paddingHorizontal: 16,
    },
    resultRow: {
        flexDirection: "row",
        justifyContent: "space-between",
        alignItems: "center",
        paddingVertical: 12,
        paddingHorizontal: 12,
        borderRadius: 10,
    },
    resultRowActive: {
        backgroundColor: "#1a1a1a",
    },
    resultLabel: {
        color: "#999",
        fontSize: 18,
        fontWeight: "500",
        width: 70,
    },
    resultValue: {
        color: "white",
        fontSize: 18,
        fontWeight: "400",
        flex: 1,
        textAlign: "right",
    },
    calcFieldRow: {
        flexDirection: "row",
        justifyContent: "space-between",
        alignItems: "center",
        paddingVertical: 14,
        paddingHorizontal: 12,
        borderRadius: 10,
    },
    calcResult: {
        marginTop: 16,
        backgroundColor: "#1a1a1a",
        borderRadius: 12,
        padding: 16,
    },
    calcResultTitle: {
        color: "#F69A06",
        fontSize: 16,
        fontWeight: "600",
        marginBottom: 8,
    },
    calcResultText: {
        color: "white",
        fontSize: 20,
        fontWeight: "400",
        marginBottom: 4,
    },
    keyboard: {
        height: BUTTON_SIZE * 4,
        width: screenWidth,
        flexDirection: "row",
        justifyContent: "center",
        alignItems: "center",
        paddingHorizontal: 10,
    },
    numberButtons: {
        height: BUTTON_SIZE * 4,
        width: BUTTON_SIZE * 3,
        flexDirection: "row-reverse",
        flexWrap: "wrap",
    },
    actionButtons: {
        height: BUTTON_SIZE * 4,
        width: BUTTON_SIZE,
    },
    actionButtonWrapper: {
        padding: 5,
        height: BUTTON_SIZE * 2,
        width: BUTTON_SIZE,
    },
    actionButton: {
        width: "100%",
        height: "100%",
        borderRadius: 25,
        backgroundColor: "#3E2702",
        justifyContent: "center",
        alignItems: "center",
    },
})
