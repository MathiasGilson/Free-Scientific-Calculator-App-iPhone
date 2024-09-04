import React, { useState, useEffect, useRef } from "react"
import { SafeAreaView, Text, TouchableOpacity, View, StyleSheet, Dimensions, ScrollView } from "react-native"
import * as Clipboard from "expo-clipboard"

import * as Localization from "expo-localization"
import { create, all } from "mathjs"

import { hapticFeedback, hapticFeedbackSwitch, hapticSuccess } from "../utils"
import Button from "../components/Button"

const config = {}
const MathJS = create(all, config)

// Get the device width and height
const { width: screenWidth } = Dimensions.get("window")

// Calculate button width and height based on screen size
const BUTTON_SIZE = (screenWidth - 40) / 4
const EXPANDED_BUTTON_SIZE = (screenWidth - 40) / 5

const App = () => {
    const [currentInput, setCurrentInput] = useState("")
    const [history, setHistory] = useState([])
    const [selectedChunk, setSelectedChunk] = useState(-1)
    const [tempResult, setTempResult] = useState("")
    const [isClipboardMenuVisible, setIsClipboardMenuVisible] = useState(false)
    const [isEditingChunk, setIsEditingChunk] = useState(false)
    const [expanded, setExpanded] = useState(false)
    const [inverted, setInverted] = useState(false)
    const [hyperbolic, setHyperbolic] = useState(false)
    const [isRadian, setIsRadian] = useState(false)
    const [error, setError] = useState("")

    const [chunkWidths, setChunkWidths] = useState([])
    const [chunkFontSize, setChunkFontSize] = useState(48)

    useEffect(() => {
        if (isClipboardMenuVisible) setIsClipboardMenuVisible(false)
        computeTempResult()
    }, [currentInput])

    useEffect(() => {
        computeTempResult()
    }, [isRadian])

    useEffect(() => {
        const totalWidth = chunkWidths.reduce((acc, width) => acc + width, 0)
        console.log(totalWidth)
        const maxWidth = screenWidth - 100

        // Adjust the font size to fit the largest chunk into the container
        const scaleFactor = maxWidth / totalWidth
        setChunkFontSize((oldFontSize) => Math.min(48, Math.max(oldFontSize * scaleFactor, 20)))
    }, [currentInput])

    const computeTempResult = () => {
        try {
            const result = evaluateInput(currentInput)
            if (result) setTempResult(String(result))
        } catch (error) {}
    }

    const formatChunk = (chunk) => {
        if (chunk === "") return chunk
        if (chunk.includes(".") || (chunk.includes(",") && [",", ".", "0"].includes(chunk.at(-1)))) {
            return chunk.replace(".", Localization.getLocales()[0].decimalSeparator ?? ".")
        }

        const formatted = new Intl.NumberFormat(Localization.locale ?? "en-US", {
            maximumFractionDigits: 5,
            useGrouping: true
        }).format(chunk)

        if (formatted === "NaN") return chunk

        return formatted
    }

    const formatResult = (result) => {
        if (result === "") return result

        const formatted = new Intl.NumberFormat(Localization.locale ?? "en-US", {
            maximumFractionDigits: 5,
            useGrouping: true
        }).format(result)

        if (formatted === "NaN") return result
        return formatted
    }

    const pasteClipboard = async () => {
        const text = await Clipboard.getStringAsync()
        setCurrentInput(text)
        setIsClipboardMenuVisible(false)
    }

    const handleCopy = async (value) => {
        hapticSuccess()
        await Clipboard.setStringAsync(value)
    }

    const openClipboardMenu = async () => {
        hapticSuccess()
        setIsClipboardMenuVisible(true)
    }

    const handlePress = (value) => {
        if (selectedChunk !== -1) {
            let chunks = currentInput.split(/([+\-*/])/)
            if (value.match(/[0-9.,]/)) {
                if (isEditingChunk) {
                    chunks[selectedChunk] = value
                    setIsEditingChunk(false)
                } else {
                    chunks[selectedChunk] += value
                }
            } else {
                setSelectedChunk(-1)
            }
            setCurrentInput(chunks.join(""))
        } else {
            // if the value is an operator and the last character is an operator, replace it
            if (value?.match(/[+\-*/]/) && currentInput.at(-1)?.match(/[+\-*/]/)) {
                return setCurrentInput(currentInput.slice(0, -1) + value)
            }
            setCurrentInput(currentInput + value)
        }
    }

    const handleClear = () => {
        hapticFeedbackSwitch()

        resetChunkFontSize()

        setCurrentInput("")
        setTempResult("")
        setError("")
        if (!currentInput) setHistory([])
        setSelectedChunk(-1)
    }

    const resetChunkFontSize = () => {
        setChunkWidths([])
        setChunkFontSize(48)
    }

    const handleSelectChunk = (index) => {
        setSelectedChunk(index)
        setIsEditingChunk(true)
    }

    const evaluateInput = (input) => {
        // parse input to replace trigonometric functions values with deg or rad based on the isRadian state
        const parsedInput = input.replace(
            new RegExp(`(sin|cos|tan)\\(([^)]+)\\)`, "g"),
            (match, func, value) => `${func}((${value}) ${isRadian ? "rad" : "deg"})`
        )
        let result = MathJS.evaluate(parsedInput)

        if (typeof result === "number" && !Number.isInteger(result)) {
            result = parseFloat(result.toFixed(5))
        }

        return result
    }

    const handleCalculate = () => {
        resetChunkFontSize()
        try {
            const result = evaluateInput(currentInput)
            const parsedResult = `${currentInput.toLocaleString()} = ${result.toLocaleString()}`
            setHistory((prev) => {
                if (prev.at(-1) === parsedResult) return prev
                return [...prev, parsedResult]
            })
            setCurrentInput(String(result))
            setSelectedChunk(-1)
        } catch (error) {
            setError("Invalid input")
        }
    }

    const handleHistoryCopy = (item) => {
        const parts = item.split("=")
        handleCopy(parts[1].trim())
    }

    const handleHistoryClick = (item) => {
        const parts = item.split("=")
        setCurrentInput(parts[0].trim())
    }

    const handleExpand = () => {
        hapticFeedbackSwitch()
        setExpanded(!expanded)
    }

    const handleInverse = () => {
        hapticFeedbackSwitch()
        setInverted(!inverted)
    }

    const handleHyperbolic = () => {
        hapticFeedbackSwitch()
        setHyperbolic(!hyperbolic)
    }

    const handleChangeAngleUnit = () => {
        hapticFeedbackSwitch()
        setIsRadian(!isRadian)
    }

    const handleDecimalPoint = () => {
        // Regular expression to find the last number in the input
        const lastNumberRegex = /(\d*\.?\d*)$/

        const match = currentInput.match(lastNumberRegex)
        if (match) {
            const lastSegment = match[0]

            // If the last segment is empty or only contains a decimal point, insert '0.'
            if (lastSegment === "" || lastSegment === ".") {
                return handlePress("0.")
            }
            // If the last segment is a number without a decimal, insert a decimal point
            else if (!lastSegment.includes(".")) {
                return handlePress(".")
            }
        }
    }

    const handleBackspace = () => {
        const operatorRegex =
            /asin\(|acos\(|atan\(|sinh\(|cosh\(|tanh\(|asinh\(|acosh\(|atanh\(|sin\(|cos\(|tan\(|pi|sqrt\(|log10\(|log\(/g
        const removeLastOperatorIfPresent = (text) => {
            let lastMatch
            let match
            // Find the last occurrence of an operator
            while ((match = operatorRegex.exec(text)) !== null) {
                lastMatch = match
            }

            // Check if the last operator is at the end of the string
            if (lastMatch && text.endsWith(lastMatch[0])) {
                return text.substring(0, lastMatch.index)
            } else {
                return text.slice(0, -1)
            }
        }

        if (selectedChunk !== -1) {
            const chunks = currentInput.split(/([+\-*/])/)
            chunks[selectedChunk] = removeLastOperatorIfPresent(chunks[selectedChunk])
            return setCurrentInput(chunks.join(""))
        } else {
            setCurrentInput((prevInput) => removeLastOperatorIfPresent(prevInput))
        }
    }

    const BUTTONS = [
        {
            type: "operator",
            theme: "secondary",
            label: "HYP",
            value: "HYP",
            expanded: true,
            action: handleHyperbolic
        },
        { type: "operator", theme: "secondary", label: "INV", value: "INV", expanded: true, action: handleInverse },
        { type: "operator", theme: "secondary", label: "sin", value: "sin", expanded: true },
        { type: "operator", theme: "secondary", label: "cos", value: "cos", expanded: true },
        { type: "operator", theme: "secondary", label: "tan", value: "tan", expanded: true },
        { type: "operator", theme: "secondary", label: "x^y", value: "^", expanded: true },
        { type: "operator", theme: "secondary", label: "lg", value: "log(", expanded: true },
        { type: "operator", theme: "secondary", label: "lg10", value: "log10(", expanded: true },
        {
            type: "operator",
            theme: "secondary",
            label: "Rand",
            value: "Rand",
            expanded: true,
            action: () => handlePress(Math.random().toFixed(5))
        },
        {
            type: "operator",
            theme: "secondary",
            label: "DEG",
            value: "DEG",
            expanded: true,
            action: handleChangeAngleUnit
        },
        { type: "operator", theme: "secondary", label: "√x", value: "sqrt(", expanded: true },
        { type: "action", theme: "secondary", label: "AC", value: "AC", action: handleClear },
        {
            type: "action",
            theme: "secondary",
            label: "(  )",
            value: "()",
            action: () => handlePress(nextParenthesis(currentInput))
        },
        { type: "action", theme: "secondary", label: "%", value: "%" },
        { type: "operator", theme: "primary", label: "÷", value: "/" },
        { type: "operator", theme: "secondary", label: "x!", value: "!", expanded: true },
        { type: "number", theme: "default", value: "7" },
        { type: "number", theme: "default", value: "8" },
        { type: "number", theme: "default", value: "9" },
        { type: "operator", theme: "primary", label: "×", value: "*" },
        { type: "operator", theme: "secondary", label: "1/x", value: "1/", expanded: true },
        { type: "number", theme: "default", value: "4" },
        { type: "number", theme: "default", value: "5" },
        { type: "number", theme: "default", value: "6" },
        { type: "operator", theme: "primary", label: "-", value: "-" },
        { type: "operator", theme: "secondary", label: "π", value: "pi", expanded: true },
        { type: "number", theme: "default", value: "1" },
        { type: "number", theme: "default", value: "2" },
        { type: "number", theme: "default", value: "3" },
        { type: "operator", theme: "primary", label: "+", value: "+" },
        { type: "expand", theme: "expand", label: "X", action: handleExpand },
        { type: "operator", theme: "default", label: "e", value: "e", expanded: true },
        { type: "number", theme: "default", value: "0" },
        {
            type: "number",
            theme: "default",
            label: ",",
            value: ".",
            action: handleDecimalPoint
        },
        { type: "operator", theme: "equal", label: "=", value: "=", action: handleCalculate }
    ]

    const renderInput = () => {
        if (error) return <Text style={styles.inputText}>{error}</Text>

        return (
            <>
                {currentInput && (
                    <View style={styles.chunkContainer}>
                        {currentInput.split(/([+\-*/])/).map((chunk, index) => (
                            <TouchableOpacity
                                key={index}
                                style={[
                                    styles.chunk,
                                    { height: chunkFontSize + 15 },
                                    selectedChunk === index && styles.selectedChunk
                                ]}
                                onLongPress={() => handleCopy(chunk)}
                                onPress={() => {
                                    if (isClipboardMenuVisible) return setIsClipboardMenuVisible(false)
                                    if (selectedChunk === index) return setSelectedChunk(-1)
                                    handleSelectChunk(index)
                                }}
                                onLayout={({ nativeEvent }) => {
                                    setChunkWidths((prev) => {
                                        const newWidths = [...prev]
                                        newWidths[index] = nativeEvent.layout.width
                                        return newWidths
                                    })
                                }}
                            >
                                <Text
                                    style={[
                                        styles.inputText,
                                        { fontSize: chunkFontSize, lineHeight: chunkFontSize + 4 }
                                    ]}
                                >
                                    {formatChunk(chunk)}
                                </Text>
                            </TouchableOpacity>
                        ))}
                    </View>
                )}

                {/* Backspace button */}
                {currentInput && (
                    <TouchableOpacity
                        style={styles.backspaceButton}
                        onPressIn={hapticFeedback}
                        onPress={handleBackspace}
                    >
                        <Text style={styles.backspaceText}>⌫</Text>
                    </TouchableOpacity>
                )}

                {/* Default to 0 */}
                {!currentInput && (
                    <View style={{ flex: 1 }}>
                        <Text style={styles.inputText} onLongPress={openClipboardMenu}>
                            0
                        </Text>
                    </View>
                )}

                {/* Clipboard menu */}
                {isClipboardMenuVisible && (
                    <View style={styles.clipboardMenuContainer}>
                        <TouchableOpacity style={styles.clipboardMenu} onPress={pasteClipboard}>
                            <Text style={styles.clipboardMenuText}>Paste</Text>
                        </TouchableOpacity>
                    </View>
                )}
            </>
        )
    }

    return (
        <SafeAreaView style={styles.container}>
            <View style={styles.header}>
                <View style={styles.historyContainer} onTouchStart={() => setSelectedChunk(-1)}>
                    <ScrollView
                        contentContainerStyle={{ padding: 10, alignItems: "flex-end" }}
                        showsVerticalScrollIndicator={false}
                    >
                        {history.map((result, index) => (
                            <TouchableOpacity
                                key={`result-${result}-${index}`}
                                onPressIn={() => hapticFeedback()}
                                onLongPress={() => handleHistoryCopy(result)}
                                onPress={() => handleHistoryClick(result)}
                            >
                                <Text style={styles.historyText}>{result}</Text>
                            </TouchableOpacity>
                        ))}
                    </ScrollView>
                </View>

                <View style={styles.inputContainer}>{renderInput()}</View>

                {currentInput && tempResult && (
                    <Text style={styles.temporaryResultText}>= {formatResult(tempResult)}</Text>
                )}
            </View>

            <View style={[styles.buttonContainer, expanded && { marginBottom: 75, paddingHorizontal: 15 }]}>
                {BUTTONS.filter((button) => {
                    if (!expanded && button.expanded) return false
                    return true
                }).map((button) => (
                    <View
                        style={[
                            styles.buttonWrapper,
                            expanded && {
                                width: EXPANDED_BUTTON_SIZE,
                                height: EXPANDED_BUTTON_SIZE,
                                margin: 1
                            }
                        ]}
                    >
                        <Button
                            key={button.value}
                            {...button}
                            expanded={expanded}
                            inverted={inverted}
                            hyperbolic={hyperbolic}
                            isRadian={isRadian}
                            onPress={handlePress}
                        />
                    </View>
                ))}
            </View>
        </SafeAreaView>
    )
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        flexDirection: "column",
        backgroundColor: "black"
    },
    header: {
        flex: 1
    },
    historyContainer: {
        flex: 3,
        justifyContent: "flex-end",
        alignItems: "flex-end",
        paddingRight: 20
    },
    historyText: {
        fontSize: 22,
        paddingVertical: 5,
        color: "gray"
    },
    inputContainer: {
        flex: 1,
        minHeight: 100,
        width: "100%",
        flexDirection: "row",
        alignItems: "flex-end",
        justifyContent: "flex-end",
        paddingRight: 20
    },
    buttonContainer: {
        marginTop: "auto",
        padding: 10,
        marginBottom: 25,
        width: screenWidth,
        height: BUTTON_SIZE * 5,
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "center",
        flexWrap: "wrap"
    },
    buttonWrapper: {
        width: BUTTON_SIZE,
        height: BUTTON_SIZE,
        margin: 2,
        padding: 5,
        justifyContent: "center",
        alignItems: "center"
    },
    inputText: {
        width: "100%",
        textAlign: "right",
        fontSize: 48,
        lineHeight: 52,
        color: "white"
    },
    backspaceButton: {
        position: "absolute",
        justifyContent: "center",
        alignItems: "center",
        width: 50,
        right: 15,
        bottom: 10
    },
    backspaceText: {
        fontSize: 32,
        color: "#B4B4B4"
    },
    chunkContainer: {
        flexDirection: "row",
        alignItems: "flex-start",
        justifyContent: "flex-end",
        width: "100%",
        paddingRight: 40,
        backgroundColor: "black",
        height: "auto",
        flexWrap: "wrap"
    },
    chunk: {
        padding: 5
    },
    selectedChunk: {
        backgroundColor: "rgba(40, 80, 200, 0.5)",
        borderRadius: 10,
        padding: 5
    },
    temporaryResultText: {
        height: 40,
        textAlign: "right",
        paddingRight: 30,
        fontSize: 25,
        color: "gray"
    },
    clipboardMenuContainer: {},
    clipboardMenu: {
        position: "absolute",
        top: -70,
        right: 5,
        backgroundColor: "rgba(255, 255, 255, 0.2)",
        paddingHorizontal: 10,
        paddingVertical: 5,
        borderRadius: 5
    },
    clipboardMenuText: {
        fontSize: 20,
        color: "white"
    }
})

const nextParenthesis = (inputString) => {
    const lastChar = inputString.at(-1)
    if (["+", "-", "/", "*", "("].includes(lastChar)) return "("
    const counts = inputString.split("").reduce(
        (acc, char) => {
            if (char === "(") {
                acc.openCount++
            } else if (char === ")") {
                acc.closeCount++
            }
            return acc
        },
        { openCount: 0, closeCount: 0 }
    )

    if (counts.closeCount > counts.openCount) {
        // The string is already unbalanced with more closing parentheses
        return "Error: Unbalanced expression"
    }

    return counts.openCount > counts.closeCount ? ")" : "("
}

export default App
