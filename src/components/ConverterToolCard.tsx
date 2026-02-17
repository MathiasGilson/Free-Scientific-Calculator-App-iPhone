import React from "react"
import { Text, TouchableOpacity, View, StyleSheet, Dimensions } from "react-native"
import { ConverterTool } from "../data/converterTools"
import { hapticFeedback } from "../utils"
import LucideIcon from "./LucideIcon"

const { width: screenWidth } = Dimensions.get("window")
const CARD_SIZE = (screenWidth - 20 - 8 * 8) / 4

type Props = {
    tool: ConverterTool
    onPress?: () => void
    onLongPress?: () => void
    onPressOut?: () => void
    delayLongPress?: number
}

export default ({ tool, onPress, onLongPress, onPressOut, delayLongPress = 300 }: Props) => (
    <TouchableOpacity
        style={styles.card}
        onPressIn={hapticFeedback}
        onPress={onPress}
        onLongPress={onLongPress}
        onPressOut={onPressOut}
        delayLongPress={delayLongPress}
        activeOpacity={0.7}
    >
        <View style={styles.iconContainer}>
            <LucideIcon name={tool.icon} size={28} color="white" />
        </View>
        <Text style={styles.label}>{tool.label}</Text>
    </TouchableOpacity>
)

const styles = StyleSheet.create({
    card: {
        width: CARD_SIZE,
        height: CARD_SIZE,
        borderRadius: 24,
        backgroundColor: "#292929",
        justifyContent: "center",
        alignItems: "center",
        margin: 8,
    },
    iconContainer: {
        marginBottom: 8,
    },
    label: {
        fontSize: 13,
        fontWeight: "500",
        color: "white",
    },
})
