import React, { useState, useRef, useEffect, useCallback } from "react"
import { StyleSheet, Dimensions, ScrollView, View, Keyboard } from "react-native"
import { SafeAreaView, SafeAreaProvider } from "react-native-safe-area-context"
import { StatusBar } from "expo-status-bar"
import AsyncStorage from "@react-native-async-storage/async-storage"

import Currency from "./src/screens/Currency"
import Converter from "./src/screens/Converter"
import Calculator from "./src/screens/Calculator"
import PinnedToolScreen from "./src/screens/PinnedToolScreen"

const { width } = Dimensions.get("window")
const STORAGE_KEY = "pinnedConverterTools"

const App = () => {
    const [pageIndex, setPageIndex] = useState(1)
    const [mounted, setMounted] = useState(false)
    const [pinnedTools, setPinnedTools] = useState<string[]>([])
    const scrollViewRef = useRef(null)

    useEffect(() => {
        AsyncStorage.getItem(STORAGE_KEY).then((raw) => {
            if (raw) {
                try {
                    setPinnedTools(JSON.parse(raw))
                } catch {}
            }
        })
    }, [])

    const handlePinnedToolsChange = useCallback((keys: string[]) => {
        setPinnedTools(keys)
        AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(keys))
    }, [])

    const handleUnpin = useCallback((toolKey: string) => {
        setPinnedTools((prev) => {
            const next = prev.filter((k) => k !== toolKey)
            AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(next))
            return next
        })
    }, [])

    const handleMomentumScrollEnd = (event) => {
        const offsetX = event.nativeEvent.contentOffset.x
        const currentPageIndex = Math.round(offsetX / width)
        setPageIndex(currentPageIndex)
    }
    const handleScroll = (event) => {
        const offsetX = event.nativeEvent.contentOffset.x
        if (Math.abs(offsetX) > width) Keyboard.dismiss()
    }

    const SCREENS = [
        () => <Currency />,
        () => <Calculator />,
        () => <Converter focused={pageIndex === 2} pinnedTools={pinnedTools} onPinnedToolsChange={handlePinnedToolsChange} />,
        ...pinnedTools.map((toolKey) => () => (
            <PinnedToolScreen toolKey={toolKey} onUnpin={() => handleUnpin(toolKey)} />
        )),
    ]

    return (
        <SafeAreaProvider>
        <SafeAreaView style={styles.container}>
            <StatusBar style="light" />

            <ScrollView
                horizontal={true}
                pagingEnabled={true}
                onMomentumScrollEnd={handleMomentumScrollEnd}
                onScroll={handleScroll}
                scrollEventThrottle={1}
                ref={scrollViewRef}
                showsHorizontalScrollIndicator={false}
                style={styles.container}
                onLayout={() => {
                    scrollViewRef.current.scrollTo({
                        x: width,
                        animated: false
                    })
                    setMounted(true)
                }}
            >
                {SCREENS.map((screen, i) => (
                    <View key={i} style={styles.screen}>{mounted && screen()}</View>
                ))}
            </ScrollView>
        </SafeAreaView>
        </SafeAreaProvider>
    )
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: "black"
    },
    screen: {
        width,
        justifyContent: "center",
        alignItems: "center"
    }
})

export default App
