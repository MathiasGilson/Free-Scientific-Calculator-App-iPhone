import React, { useState, useRef, useEffect } from "react"
import { SafeAreaView, StyleSheet, StatusBar, Dimensions, ScrollView, View, Keyboard } from "react-native"

import Currency from "./src/screens/Currency"
import Converter from "./src/screens/Converter"
import Calculator from "./src/screens/Calculator"

const { width } = Dimensions.get("window")

const App = () => {
    const [pageIndex, setPageIndex] = useState(1)
    const [mounted, setMounted] = useState(false)
    const scrollViewRef = useRef(null)

    const handleMomentumScrollEnd = (event) => {
        const offsetX = event.nativeEvent.contentOffset.x
        const currentPageIndex = Math.round(offsetX / width)
        setPageIndex(currentPageIndex)
    }
    const handleScroll = (event) => {
        const offsetX = event.nativeEvent.contentOffset.x
        if (Math.abs(offsetX) > width) Keyboard.dismiss()
    }

    const SCREENS = [() => <Currency />, () => <Calculator />, () => <Converter focused={pageIndex === 2} />]

    return (
        <SafeAreaView style={styles.container}>
            <StatusBar barStyle="light-content" />

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
                {SCREENS.map((screen) => (
                    <View style={styles.screen}>{mounted && screen()}</View>
                ))}
            </ScrollView>
        </SafeAreaView>
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
