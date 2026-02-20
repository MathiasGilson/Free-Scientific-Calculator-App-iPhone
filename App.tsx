import React, { useState, useRef, useEffect, useCallback, createContext } from "react"
import { StyleSheet, Dimensions, Animated, View, Keyboard, Modal, Pressable } from "react-native"
import { SafeAreaView, SafeAreaProvider, useSafeAreaInsets } from "react-native-safe-area-context"
import { StatusBar } from "expo-status-bar"
import AsyncStorage from "@react-native-async-storage/async-storage"
import { GestureHandlerRootView } from "react-native-gesture-handler"

import Converter from "./src/screens/Converter"
import Calculator from "./src/screens/Calculator"
import PinnedToolScreen from "./src/screens/PinnedToolScreen"
import PinnedToolsTabBar from "./src/components/PinnedToolsTabBar"
import HistoryDrawerContent from "./src/components/HistoryDrawerContent"

const { width } = Dimensions.get("window")
const STORAGE_KEY = "pinnedConverterTools"

export const HistoryContext = createContext<{
    onSelect: (expression: string) => void
    refreshKey: number
    openHistory: () => void
    closeHistory: () => void
}>({
    onSelect: () => {},
    refreshKey: 0,
    openHistory: () => {},
    closeHistory: () => {},
})

const MainScreen = () => {
    const insets = useSafeAreaInsets()
    const [pageIndex, setPageIndex] = useState(0)
    const [mounted, setMounted] = useState(false)
    const [screenOrder, setScreenOrder] = useState<string[]>(["_calculator", "currency"])
    const [tabBarVisible, setTabBarVisible] = useState(false)
    const [mainScrollEnabled, setMainScrollEnabled] = useState(true)
    const converterRearrangingRef = useRef(false)
    const stayOnConverterRef = useRef(false)
    const scrollViewRef = useRef(null)
    const scrollX = useRef(new Animated.Value(0)).current
    const tabBarOpacity = useRef(new Animated.Value(0)).current
    const hideTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

    useEffect(() => {
        AsyncStorage.getItem(STORAGE_KEY).then((raw) => {
            if (raw) {
                try {
                    const parsed = JSON.parse(raw)
                    if (!parsed.includes("_calculator")) {
                        parsed.unshift("_calculator")
                    }
                    setScreenOrder(parsed)
                    // Scroll to calculator on launch
                    const calcIdx = parsed.indexOf("_calculator")
                    if (calcIdx > 0) {
                        setTimeout(() => {
                            scrollViewRef.current?.scrollTo({ x: calcIdx * width, animated: false })
                        }, 0)
                    }
                } catch {}
            }
        })
    }, [])

    useEffect(() => {
        if (stayOnConverterRef.current) {
            stayOnConverterRef.current = false
            const converterIdx = screenOrder.length
            scrollViewRef.current?.scrollTo({ x: converterIdx * width, animated: false })
        }
    }, [screenOrder])

    const pinnedToolKeys = screenOrder.filter((k) => k !== "_calculator")

    const handlePinnedToolsChange = useCallback((newOrder: string[]) => {
        stayOnConverterRef.current = true
        const next = newOrder.includes("_calculator") ? newOrder : ["_calculator", ...newOrder]
        AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(next))
        setScreenOrder(next)
    }, [])

    const showTabBar = useCallback(() => {
        if (hideTimerRef.current) {
            clearTimeout(hideTimerRef.current)
            hideTimerRef.current = null
        }
        setTabBarVisible(true)
        Animated.timing(tabBarOpacity, {
            toValue: 1,
            duration: 200,
            useNativeDriver: true,
        }).start()
    }, [tabBarOpacity])

    const hideTabBar = useCallback(() => {
        if (converterRearrangingRef.current) return
        Animated.timing(tabBarOpacity, {
            toValue: 0,
            duration: 300,
            useNativeDriver: true,
        }).start(() => setTabBarVisible(false))
    }, [tabBarOpacity])

    const onScrollBeginDrag = useCallback(() => {
        if (screenOrder.length > 0) {
            showTabBar()
        }
    }, [screenOrder.length, showTabBar])

    const scheduleHideTabBar = useCallback(() => {
        if (hideTimerRef.current) clearTimeout(hideTimerRef.current)
        hideTimerRef.current = setTimeout(() => {
            hideTabBar()
        }, 200)
    }, [hideTabBar])

    const handleConverterRearrange = useCallback((active: boolean) => {
        converterRearrangingRef.current = active
        setMainScrollEnabled(!active)
        if (active) {
            // Force hide — bypass the converterRearrangingRef guard
            if (hideTimerRef.current) {
                clearTimeout(hideTimerRef.current)
                hideTimerRef.current = null
            }
            Animated.timing(tabBarOpacity, {
                toValue: 0,
                duration: 200,
                useNativeDriver: true,
            }).start(() => setTabBarVisible(false))
        } else {
            scheduleHideTabBar()
        }
    }, [tabBarOpacity, scheduleHideTabBar])

    const handleConverterDetailChange = useCallback((open: boolean) => {
        setMainScrollEnabled(!open)
    }, [])

    const onMomentumScrollEnd = useCallback((event) => {
        const offsetX = event.nativeEvent.contentOffset.x
        const currentPageIndex = Math.round(offsetX / width)
        setPageIndex(currentPageIndex)
        scheduleHideTabBar()
    }, [scheduleHideTabBar])

    const onScrollEndDrag = useCallback(() => {
        scheduleHideTabBar()
    }, [scheduleHideTabBar])

    const onScroll = useCallback((event) => {
        const offsetX = event.nativeEvent.contentOffset.x
        if (Math.abs(offsetX) > width) Keyboard.dismiss()
    }, [])

    const converterIndex = screenOrder.length

    const SCREENS = [
        ...screenOrder.map((key) => ({
            key,
            render: key === "_calculator"
                ? () => <Calculator />
                : () => <PinnedToolScreen toolKey={key} />,
        })),
        { key: "_converter", render: () => <Converter focused={pageIndex === converterIndex} pinnedTools={pinnedToolKeys} screenOrder={screenOrder} onPinnedToolsChange={handlePinnedToolsChange} onRearrangeChange={handleConverterRearrange} onDetailChange={handleConverterDetailChange} /> },
    ]

    return (
        <SafeAreaView style={styles.container} edges={['bottom', 'left', 'right']}>
            <StatusBar style="light" />

            <View style={styles.container}>
                <Animated.ScrollView
                    horizontal={true}
                    pagingEnabled={true}
                    scrollEnabled={mainScrollEnabled}
                    onScrollBeginDrag={onScrollBeginDrag}
                    onMomentumScrollEnd={onMomentumScrollEnd}
                    onScrollEndDrag={onScrollEndDrag}
                    onScroll={Animated.event(
                        [{ nativeEvent: { contentOffset: { x: scrollX } } }],
                        { useNativeDriver: false, listener: onScroll }
                    )}
                    scrollEventThrottle={16}
                    ref={scrollViewRef}
                    showsHorizontalScrollIndicator={false}
                    style={styles.container}
                    onLayout={() => setMounted(true)}
                >
                    {SCREENS.map((screen) => (
                        <View key={screen.key} style={[styles.screen, { paddingTop: insets.top / 2 }]}>{mounted && screen.render()}</View>
                    ))}
                </Animated.ScrollView>

                <PinnedToolsTabBar
                    screenOrder={screenOrder}
                    scrollX={scrollX}
                    opacity={tabBarOpacity}
                />
            </View>
        </SafeAreaView>
    )
}

const App = () => {
    const [refreshKey, setRefreshKey] = useState(0)
    const [historyVisible, setHistoryVisible] = useState(false)
    const onSelectRef = useRef<((expression: string) => void) | null>(null)

    const openHistory = useCallback(() => setHistoryVisible(true), [])
    const closeHistory = useCallback(() => setHistoryVisible(false), [])

    const handleSelect = useCallback((expression: string) => {
        onSelectRef.current?.(expression)
        setHistoryVisible(false)
    }, [])

    const contextValue = React.useMemo(
        () => ({ onSelect: handleSelect, refreshKey, openHistory, closeHistory }),
        [handleSelect, refreshKey, openHistory, closeHistory]
    )

    // Expose a way for Calculator to register its onSelect handler and bump refreshKey
    const setOnSelect = useCallback((fn: (expression: string) => void) => {
        onSelectRef.current = fn
    }, [])

    const bumpRefreshKey = useCallback(() => {
        setRefreshKey((k) => k + 1)
    }, [])

    return (
        <GestureHandlerRootView style={styles.container}>
            <SafeAreaProvider>
                <HistoryContext.Provider value={contextValue}>
                    <CalcCallbackContext.Provider value={{ setOnSelect, bumpRefreshKey }}>
                        <MainScreen />
                        <Modal
                            animationType="slide"
                            visible={historyVisible}
                            transparent={true}
                            onRequestClose={closeHistory}
                        >
                            <View style={styles.modalOverlay}>
                                <Pressable style={styles.modalDismissArea} onPress={closeHistory} />
                                <View style={styles.modalSheet}>
                                    <HistoryDrawerContent onClose={closeHistory} />
                                </View>
                            </View>
                        </Modal>
                    </CalcCallbackContext.Provider>
                </HistoryContext.Provider>
            </SafeAreaProvider>
        </GestureHandlerRootView>
    )
}

export const CalcCallbackContext = createContext<{
    setOnSelect: (fn: (expression: string) => void) => void
    bumpRefreshKey: () => void
}>({
    setOnSelect: () => {},
    bumpRefreshKey: () => {},
})

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: "black"
    },
    screen: {
        width,
        flex: 1,
        justifyContent: "center",
        alignItems: "center"
    },
    modalOverlay: {
        flex: 1,
        justifyContent: "flex-end",
    },
    modalDismissArea: {
        flex: 1,
    },
    modalSheet: {
        height: "75%",
        borderTopLeftRadius: 14,
        borderTopRightRadius: 14,
        overflow: "hidden",
    },
})

export default App
