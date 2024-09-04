import React, { useState, useEffect, useRef } from "react"
import { SafeAreaView, Text, View, StyleSheet, TextInput, Keyboard } from "react-native"
import * as Clipboard from "expo-clipboard"
import * as Haptics from "expo-haptics"
import * as Localization from "expo-localization"
import { evaluate, createUnit } from "mathjs"
import Svg, { Path } from "react-native-svg"

try {
    createUnit("C", "1 degC", { override: true })
    createUnit("F", "1 degF", { override: true })
    createUnit("Celsius", "1 degC", { override: true })
    createUnit("Fahrenheit", "1 degF", { override: true })
    createUnit("kph", "1 km/hour", { override: true })
    createUnit("mph", "1 mile/hour", { override: true })
} catch (error) {
    console.log(error)
}

export default ({ focused = false }) => {
    const inputRef = useRef<
        TextInput & {
            focus: () => void
        }
    >()
    const [currentInput, setCurrentInput] = useState("")
    const [result, setResult] = useState("hello")
    const [error, setError] = useState("")

    useEffect(() => {
        console.log(currentInput)
        if (!currentInput) {
            setResult("")
        }
        try {
            const result = evaluate(currentInput)
            if (result) setResult(String(result))
        } catch (error) {}
    }, [currentInput])

    useEffect(() => {
        if (focused && inputRef.current) inputRef.current.focus()
    }, [focused])

    return (
        <SafeAreaView style={styles.container}>
            <TextInput
                ref={inputRef}
                clearButtonMode={"while-editing"}
                style={styles.input}
                placeholder="2 inches to cm"
                onChangeText={setCurrentInput}
                value={currentInput}
            />

            <View style={styles.resultContainer}>
                {result ? (
                    <Text style={styles.result}>{result}</Text>
                ) : (
                    <>
                        <Text style={styles.hint}>Convert any values from one unit to another</Text>
                    </>
                )}
            </View>
        </SafeAreaView>
    )
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        width: "100%",
        backgroundColor: "black"
    },
    resultContainer: {
        padding: 20
    },
    result: {
        color: "white",
        fontSize: 22
    },
    hint: {
        color: "#333333",
        fontSize: 22
    },
    input: {
        borderRadius: 10,
        backgroundColor: "#333",
        color: "white",
        fontSize: 22,
        height: 50,
        margin: 12,
        borderWidth: 1,
        padding: 10
    }
})
