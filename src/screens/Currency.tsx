import React, { useState, useEffect } from "react"
import {
    SafeAreaView,
    Text,
    View,
    StyleSheet,
    ScrollView,
    LogBox,
    Modal,
    TextInput,
    TouchableOpacity,
    Dimensions,
    Pressable
} from "react-native"
import currencies from "../currencies.json" // make sure this file contains the needed currency data

import * as Localization from "expo-localization"

import dayjs from "dayjs"
import relativeTime from "dayjs/plugin/relativeTime"
dayjs.extend(relativeTime)

import AsyncStorage from "@react-native-async-storage/async-storage"
LogBox.ignoreAllLogs()
import Button from "../components/Button"
import { hapticFeedbackSwitch, hapticFeedback } from "../utils"

// Get the device width and height
const { width: screenWidth } = Dimensions.get("window")

// Calculate button width and height based on screen size
const BUTTON_SIZE = (screenWidth - 40) / 4

export default () => {
    const [amounts, setAmounts] = useState(["1", "0", "0", "0"])
    const [rates, setRates] = useState(null)
    const [ratesUpdatedAt, setRatesUpdatedAt] = useState(0)

    const [displayedCurrencies, setDisplayedCurrencies] = useState(["USD", "EUR", "GBP", "JPY"])
    const [searchText, setSearchText] = useState("")
    const [currencyPickerVisible, setCurrencyPickerVisible] = useState(false)
    const [activeCurrencyIndex, setActiveCurrencyIndex] = useState(0)
    const [activeAmount, setActiveAmount] = useState("1")
    const [inputEdited, setInputEdited] = useState(false)

    const fetchRates = async () => {
        setRatesUpdatedAt(0)
        const currentTime = new Date().getTime()
        try {
            const response = await fetch(
                `https://openexchangerates.org/api/latest.json?app_id=${process.env.EXPO_PUBLIC_OPEN_EXCHANGE_RATES_API_KEY}`
            )
            const json = await response.json()
            setRatesUpdatedAt(currentTime)
            setRates(json.rates)
            await AsyncStorage.setItem("ratesData", JSON.stringify({ rates: json.rates, updatedAt: currentTime }))
        } catch (error) {
            console.error(error)
        }
    }

    const getRates = async () => {
        const ratesData = await AsyncStorage.getItem("ratesData")
        const ratesDataParsed = ratesData ? JSON.parse(ratesData) : null
        const currentTime = new Date().getTime()

        if (ratesDataParsed && currentTime - ratesDataParsed.updatedAt < 24 * 60 * 60 * 1000) {
            setRatesUpdatedAt(ratesDataParsed.updatedAt)
            return setRates(ratesDataParsed.rates)
        }
        return fetchRates()
    }

    useEffect(() => {
        // Load the displayed currencies from AsyncStorage when the app is opened
        const loadDisplayedCurrencies = async () => {
            const savedCurrencies = await AsyncStorage.getItem("displayedCurrencies")
            if (savedCurrencies) {
                setDisplayedCurrencies(JSON.parse(savedCurrencies))
            }
        }

        loadDisplayedCurrencies()
    }, [])

    useEffect(() => {
        // Save the displayed currencies to AsyncStorage whenever they change
        const saveDisplayedCurrencies = async () => {
            await AsyncStorage.setItem("displayedCurrencies", JSON.stringify(displayedCurrencies))
        }

        saveDisplayedCurrencies()
    }, [displayedCurrencies])

    useEffect(() => {
        getRates()
    }, [])

    useEffect(() => {
        reset()
    }, [activeCurrencyIndex])

    useEffect(() => {
        setSearchText("")
    }, [currencyPickerVisible])

    const reset = () => {
        setInputEdited(false)
        setActiveAmount("1")
    }

    const convertCurrency = () => {
        if (!rates) return

        const baseRate = rates[displayedCurrencies[activeCurrencyIndex]] ?? 1

        const newAmounts = displayedCurrencies.map((currency, i) => {
            if (i === activeCurrencyIndex) return activeAmount
            return ((Number(activeAmount) / baseRate) * (rates[currency] ?? 1)).toString()
        })
        setAmounts(newAmounts)
    }

    useEffect(() => {
        convertCurrency()
    }, [rates, displayedCurrencies, activeAmount, activeCurrencyIndex])

    const handleCurrencyChange = (code) => {
        const newCurrencies = [...displayedCurrencies]
        newCurrencies[activeCurrencyIndex] = code
        setDisplayedCurrencies(newCurrencies)
        setCurrencyPickerVisible(false)
    }

    const appendValue = (value) => {
        setInputEdited(true)
        if (value === ".") {
            const currencyData = Object.entries(currencies).find(
                ([code]) => code === displayedCurrencies[activeCurrencyIndex]
            )[1] as any
            if (currencyData.decimal_digits === 0) return
            if (activeAmount.includes(".")) return
            if (!inputEdited) return setActiveAmount("1.")
        }
        const newValue = !inputEdited ? value : activeAmount + value
        setActiveAmount(newValue)
    }

    const renderCurrency = (currency, index) => {
        const currencyData = Object.entries(currencies)
            .find(([code]) => code === currency)
            .at(1) as any

        const isActiveCurrency = index === activeCurrencyIndex

        const displayedCurrency =
            isActiveCurrency && activeAmount.at(-1) === "."
                ? activeAmount.replace(".", Localization.getLocales()[0].decimalSeparator ?? ".")
                : Number(
                      parseFloat(isActiveCurrency ? activeAmount : amounts[index]).toFixed(currencyData.decimal_digits)
                  ).toLocaleString(Localization.locale ?? "en-US", {
                      maximumFractionDigits: currencyData.decimal_digits
                  })
        return (
            <View style={styles.currencyInput} key={currency}>
                <TouchableOpacity
                    style={styles.currencySelector}
                    onPress={() => {
                        setCurrencyPickerVisible(true)
                        setActiveCurrencyIndex(index)
                    }}
                >
                    <Text style={styles.currencyText}>{currency}</Text>
                </TouchableOpacity>
                <TouchableOpacity
                    onPress={() => {
                        setActiveCurrencyIndex(index)
                        setActiveAmount("1")
                    }}
                >
                    <Text style={[styles.input, isActiveCurrency && { color: "#F69A06" }]}>{displayedCurrency}</Text>
                    <Text style={styles.currencyName}>{currencyData.name}</Text>
                </TouchableOpacity>
            </View>
        )
    }

    return (
        <SafeAreaView style={styles.container}>
            <View style={styles.currencyContainer}>
                {displayedCurrencies.map(renderCurrency)}

                <TouchableOpacity onPress={fetchRates} style={styles.ratesRefreshTimeContainer}>
                    <View style={styles.ratesRefreshTime}>
                        <Text style={{ color: "#555" }}>
                            {ratesUpdatedAt > 0
                                ? `Updated ${dayjs(ratesUpdatedAt).fromNow()} at ${dayjs(ratesUpdatedAt).format(
                                      "HH:mm"
                                  )}`
                                : "Updating rates..."}
                        </Text>
                    </View>
                </TouchableOpacity>
            </View>

            {/* Keyboard View */}
            <View style={styles.keyboard}>
                <View style={styles.numberButtons}>
                    {[
                        { type: "number", theme: "default", value: "3" },
                        { type: "number", theme: "default", value: "2" },
                        { type: "number", theme: "default", value: "1" },
                        { type: "number", theme: "default", value: "6" },
                        { type: "number", theme: "default", value: "5" },
                        { type: "number", theme: "default", value: "4" },
                        { type: "number", theme: "default", value: "9" },
                        { type: "number", theme: "default", value: "8" },
                        { type: "number", theme: "default", value: "7" },
                        { type: "number", theme: "default", value: "." },
                        { type: "number", theme: "default", value: "0" }
                    ].map((button) => (
                        <View style={{ width: BUTTON_SIZE, height: BUTTON_SIZE, padding: 5 }} key={button.value}>
                            <Button {...button} onPress={() => appendValue(button.value)} />
                        </View>
                    ))}
                </View>
                <View style={styles.actionButtons}>
                    <View style={styles.actionButtonWrapper}>
                        <TouchableOpacity style={styles.actionButton} onPressIn={hapticFeedbackSwitch} onPress={reset}>
                            <Text style={{ color: "#BF7600", fontSize: 30 }}>AC</Text>
                        </TouchableOpacity>
                    </View>
                    <View style={styles.actionButtonWrapper}>
                        <TouchableOpacity
                            onPressIn={hapticFeedback}
                            style={[styles.actionButton, { backgroundColor: "#F69A06" }]}
                            onPress={() => {
                                setActiveAmount(activeAmount.slice(0, -1) || "0")
                            }}
                        >
                            <Text style={{ color: "white", fontSize: 35 }}>⌫</Text>
                        </TouchableOpacity>
                    </View>
                </View>
            </View>

            {/* Currency picker */}
            <Modal
                animationType="slide"
                visible={currencyPickerVisible}
                transparent={true}
                presentationStyle="formSheet"
                onRequestClose={() => setCurrencyPickerVisible(!currencyPickerVisible)}
            >
                <View style={styles.modalView}>
                    <Pressable
                        style={styles.dismissArea}
                        onPress={() => setCurrencyPickerVisible(!currencyPickerVisible)}
                    />
                    <View style={styles.currencyPicker}>
                        <TextInput
                            style={styles.searchBar}
                            placeholder="Search"
                            clearButtonMode="while-editing"
                            onChangeText={(text) => setSearchText(text)}
                            defaultValue={searchText}
                        />
                        <ScrollView style={{ flex: 1, width: "100%" }}>
                            {Object.entries(currencies)
                                .filter(
                                    ([code, { name }]) =>
                                        name.toLowerCase().includes(searchText.toLowerCase()) ||
                                        code.toLowerCase().includes(searchText.toLowerCase())
                                )
                                .map(([code, { name, symbol }]) => (
                                    <TouchableOpacity
                                        style={{
                                            paddingVertical: 10,
                                            width: "100%"
                                        }}
                                        key={code}
                                        onPress={() => handleCurrencyChange(code)}
                                    >
                                        <Text style={styles.currencyText}>{`${name} (${symbol})`}</Text>
                                    </TouchableOpacity>
                                ))}
                        </ScrollView>
                    </View>
                </View>
            </Modal>
        </SafeAreaView>
    )
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        flexDirection: "column",
        width: "100%",
        backgroundColor: "black"
    },
    currencyContainer: {
        flex: 1,
        padding: 20,
        paddingBottom: 0,
        flexDirection: "column",
        justifyContent: "space-between"
    },
    dismissArea: {
        flex: 1
    },
    currencyPicker: {
        height: "80%",
        marginTop: "auto",
        backgroundColor: "#222",
        borderTopRightRadius: 20,
        borderTopLeftRadius: 20,
        padding: 20,
        alignItems: "center",
        shadowColor: "#000",
        shadowOffset: {
            width: 0,
            height: 2
        },
        shadowOpacity: 0.25,
        shadowRadius: 4,
        elevation: 5
    },
    keyboard: {
        height: BUTTON_SIZE * 4,
        width: screenWidth,
        flexDirection: "row",
        justifyContent: "center",
        alignItems: "center",
        paddingHorizontal: 10
    },
    numberButtons: {
        height: BUTTON_SIZE * 4,
        width: BUTTON_SIZE * 3,

        flexDirection: "row-reverse",
        flexWrap: "wrap"
    },
    actionButtons: {
        height: BUTTON_SIZE * 4,
        width: BUTTON_SIZE
    },
    actionButtonWrapper: {
        padding: 5,
        height: BUTTON_SIZE * 2,
        width: BUTTON_SIZE
    },
    actionButton: {
        width: "100%",
        height: "100%",
        borderRadius: 25,
        backgroundColor: "#3E2702",
        justifyContent: "center",
        alignItems: "center"
    },
    currencyInput: {
        flexDirection: "row",
        justifyContent: "space-between",
        alignItems: "center"
    },
    input: {
        fontSize: 30,
        color: "white",
        textAlign: "right",
        fontWeight: "500"
    },
    currencySelector: {
        alignItems: "center",
        justifyContent: "center"
    },
    ratesRefreshTime: {
        alignItems: "flex-start",
        justifyContent: "center"
    },
    ratesRefreshTimeContainer: {
        padding: 5
    },

    searchBar: {
        width: "100%",
        height: 50,
        backgroundColor: "#333",
        borderRadius: 10,
        paddingVertical: 10,
        paddingHorizontal: 20,
        marginBottom: 20,
        color: "white",
        fontSize: 18
    },

    modalView: {
        flex: 1
    },
    currencyText: {
        fontSize: 25,
        fontWeight: "300",
        color: "white",
        textAlign: "left"
    },
    currencyName: {
        fontSize: 15,
        paddingTop: 2,
        fontWeight: "300",
        color: "#999",
        textAlign: "right"
    },
    results: {
        padding: 20
    },
    resultText: {
        fontSize: 18,
        color: "white",
        marginBottom: 10
    }
})
