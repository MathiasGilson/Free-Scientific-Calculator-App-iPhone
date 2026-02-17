import React from "react"
import { Animated, View, StyleSheet, Dimensions } from "react-native"
import { useSafeAreaInsets } from "react-native-safe-area-context"
import { converterTools } from "../data/converterTools"
import LucideIcon from "./LucideIcon"

const { width } = Dimensions.get("window")
const ICON_SIZE = 20

function iconForKey(key: string): string {
    if (key === "_calculator") return "calculator"
    const tool = converterTools.find((t) => t.key === key)
    return tool?.icon || "bookmark"
}

type Props = {
    screenOrder: string[]
    scrollX: Animated.Value
    opacity: Animated.Value
}

export default ({ screenOrder, scrollX, opacity }: Props) => {
    if (screenOrder.length === 0) return null
    const insets = useSafeAreaInsets()

    const allTabs = [
        ...screenOrder.map((key, i) => ({ key, icon: iconForKey(key), screenIndex: i })),
        { key: "_converter", icon: "layout-grid", screenIndex: screenOrder.length },
    ]

    return (
        <Animated.View style={[styles.container, { opacity, paddingTop: insets.top + 4 }]} pointerEvents="none">
            <View style={styles.tabRow}>
                {allTabs.map((tab) => {
                    const tabCenter = tab.screenIndex * width
                    const activity = scrollX.interpolate({
                        inputRange: [tabCenter - width, tabCenter, tabCenter + width],
                        outputRange: [0, 1, 0],
                        extrapolate: "clamp",
                    })
                    const bgOpacity = activity.interpolate({
                        inputRange: [0, 1],
                        outputRange: [0, 1],
                    })
                    const activeIconOpacity = activity
                    const inactiveIconOpacity = activity.interpolate({
                        inputRange: [0, 1],
                        outputRange: [1, 0],
                    })

                    return (
                        <View key={tab.key} style={styles.tabWrapper}>
                            <Animated.View style={[styles.tabBg, { opacity: bgOpacity }]} />
                            <View style={styles.tabContent}>
                                <View style={styles.iconWrapper}>
                                    <Animated.View style={{ opacity: inactiveIconOpacity }}>
                                        <LucideIcon name={tab.icon} size={ICON_SIZE} color="#999" />
                                    </Animated.View>
                                    <Animated.View style={[styles.iconOverlay, { opacity: activeIconOpacity }]}>
                                        <LucideIcon name={tab.icon} size={ICON_SIZE} color="#F69A06" />
                                    </Animated.View>
                                </View>
                            </View>
                        </View>
                    )
                })}
            </View>
        </Animated.View>
    )
}

const styles = StyleSheet.create({
    container: {
        position: "absolute",
        top: 0,
        left: 0,
        right: 0,
        zIndex: 100,
        alignItems: "center",
    },
    tabRow: {
        flexDirection: "row",
        backgroundColor: "rgba(30,30,30,0.85)",
        borderRadius: 16,
        paddingHorizontal: 4,
        paddingVertical: 4,
    },
    tabWrapper: {
        position: "relative",
        borderRadius: 12,
        overflow: "hidden",
    },
    tabBg: {
        ...StyleSheet.absoluteFillObject,
        backgroundColor: "rgba(255,255,255,0.1)",
        borderRadius: 12,
    },
    tabContent: {
        alignItems: "center",
        justifyContent: "center",
        paddingHorizontal: 10,
        paddingVertical: 8,
    },
    iconWrapper: {
        width: ICON_SIZE,
        height: ICON_SIZE,
    },
    iconOverlay: {
        ...StyleSheet.absoluteFillObject,
    },
})
