import React, { useState, useEffect, useRef } from "react"
import { SafeAreaView, Text, TouchableOpacity, View, StyleSheet, Dimensions, ScrollView } from "react-native"
import * as Haptics from "expo-haptics"
import Svg, { Path } from "react-native-svg"
import * as Localization from "expo-localization"

export default ({ expanded, onPress, type, value, theme, label, action, inverted, hyperbolic, isRadian }: any) => {
    const hapticFeedback = () => Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light)

    // If the button is a number, render the number, else render the label
    if (type === "number") {
        return (
            <TouchableOpacity
                key={value}
                style={[styles.button, expanded && { borderRadius: 18 }]}
                onPressIn={hapticFeedback}
                onPress={() => {
                    if (action) return action()
                    return onPress(value)
                }}
            >
                <Text style={[{ color: "white" }, expanded ? { fontSize: 30 } : { fontSize: 38 }]}>
                    {value === "." ? Localization.getLocales()[0].decimalSeparator ?? "." : value}
                </Text>
            </TouchableOpacity>
        )
    }

    const isTrigonometric = ["sin", "cos", "tan"].includes(value)

    return (
        <TouchableOpacity
            key={value}
            style={[
                styles.button,
                theme === "equal" && { backgroundColor: "#F69A06" },
                theme === "primary" && { backgroundColor: "#3E2702" },
                theme === "secondary" && { backgroundColor: "#171717" },
                theme === "expand" && { backgroundColor: "black" },
                expanded && { borderRadius: 18 },

                inverted && label === "INV" && { backgroundColor: "#333333" },
                hyperbolic && label === "HYP" && { backgroundColor: "#333333" },
                value === "DEG" && isRadian && { backgroundColor: "#333333" }
            ]}
            onPressIn={hapticFeedback}
            onPress={() => {
                if (action) return action()

                if (isTrigonometric) {
                    return onPress((inverted ? "a" : "") + value + (hyperbolic ? "h" : "") + "(")
                }
                return onPress(value)
            }}
        >
            {label === "X" ? (
                expanded ? (
                    <ExpandedIcon />
                ) : (
                    <ExpandIcon />
                )
            ) : (
                <Text
                    style={[
                        {
                            textAlign: "center",
                            justifyContent: "center",
                            verticalAlign: "middle",
                            color: "white",
                            fontSize: 38
                        },
                        theme === "equal" && { fontSize: 50, lineHeight: 55 },
                        theme === "primary" && { color: "#FF9D00", fontSize: 45, lineHeight: 50 },
                        theme === "secondary" && { color: "#BEBEBE" },
                        value === "AC" && { color: "#BF7600" },
                        value === "()" && { marginBottom: 5, fontWeight: "500" },
                        expanded && theme === "secondary" && { fontSize: 22 },
                        expanded && theme !== "secondary" && { fontSize: 32 },
                        expanded && theme === "primary" && { fontSize: 45, lineHeight: 45 },
                        expanded && theme === "equal" && { fontSize: 45, lineHeight: 45 },
                        isTrigonometric && (inverted || hyperbolic) && { fontSize: 18 },
                        isTrigonometric && inverted && hyperbolic && { fontSize: 13 },
                        value === "Rand" && { fontSize: 16 },
                        ["DEG", "INV", "HYP"].includes(value) && { fontSize: 20 }
                    ]}
                >
                    {value === "DEG" && isRadian ? (
                        "RAD"
                    ) : (
                        <>
                            {label}
                            {isTrigonometric && hyperbolic && "h"}
                            {isTrigonometric && inverted && "⁻¹"}
                        </>
                    )}
                </Text>
            )}
        </TouchableOpacity>
    )
}

const styles = StyleSheet.create({
    button: {
        height: "100%",
        width: "100%",
        padding: 10,
        backgroundColor: "#292929",
        justifyContent: "center",
        alignItems: "center",
        borderRadius: 24
    }
})

const ExpandIcon = () => (
    <Svg width="44" height="44" viewBox="0 0 44 44" fill="none">
        <Path
            fillRule="evenodd"
            clipRule="evenodd"
            d="M30.3909 42.6003C30.3909 41.9875 30.8876 41.4908 31.5003 41.4909L41.4908 41.4908V31.5004C41.4908 30.8876 41.9875 30.3909 42.6002 30.391C43.2128 30.3909 43.7096 30.8876 43.7096 31.5004V42.6003C43.7096 43.2128 43.2128 43.7095 42.6002 43.7097H31.5003C30.8876 43.7095 30.3909 43.2128 30.3909 42.6003Z"
            fill="#ADADAD"
        />
        <Path
            fillRule="evenodd"
            clipRule="evenodd"
            d="M27.6957 27.6957C28.1289 27.2625 28.8314 27.2625 29.2646 27.6957L43.3846 41.8157C43.8178 42.2489 43.8178 42.9514 43.3846 43.3846C42.9515 43.8178 42.2489 43.8178 41.8157 43.3846L27.6957 29.2646C27.2625 28.8314 27.2625 28.1288 27.6957 27.6957Z"
            fill="#ADADAD"
        />
        <Path
            fillRule="evenodd"
            clipRule="evenodd"
            d="M0.699525 1.80902C0.699572 1.19625 1.19628 0.699541 1.80889 0.699651L12.9088 0.69965C13.5216 0.699587 14.0182 1.19627 14.0182 1.80901C14.0183 2.42162 13.5216 2.91833 12.9088 2.91838L2.91835 2.91832L2.91825 12.9089C2.91836 13.5215 2.42165 14.0183 1.80889 14.0183C1.1963 14.0182 0.699618 13.5215 0.699524 12.9089L0.699525 1.80902Z"
            fill="#ADADAD"
        />
        <Path
            fillRule="evenodd"
            clipRule="evenodd"
            d="M1.02452 1.02449C1.45769 0.591316 2.16018 0.591253 2.59341 1.02449L16.7134 15.1445C17.1466 15.5777 17.1466 16.2802 16.7134 16.7134C16.2803 17.1466 15.5777 17.1466 15.1446 16.7134L1.02452 2.59338C0.591282 2.16015 0.591345 1.45766 1.02452 1.02449Z"
            fill="#ADADAD"
        />
        <Path
            fillRule="evenodd"
            clipRule="evenodd"
            d="M1.80905 30.3909C2.42165 30.3908 2.91836 30.8876 2.91841 31.5003L2.91835 41.4908L12.909 41.4909C13.5216 41.4908 14.0183 41.9875 14.0183 42.6002C14.0182 43.2128 13.5216 43.7095 12.909 43.7096H1.80905C1.19628 43.7095 0.699573 43.2128 0.699683 42.6002L0.699683 31.5003C0.699621 30.8876 1.1963 30.3909 1.80905 30.3909Z"
            fill="#ADADAD"
        />
        <Path
            fillRule="evenodd"
            clipRule="evenodd"
            d="M1.02452 43.3846C0.591345 42.9514 0.591282 42.2489 1.02452 41.8157L15.1446 27.6957C15.5777 27.2625 16.2803 27.2625 16.7134 27.6957C17.1466 28.1288 17.1466 28.8314 16.7134 29.2646L2.59341 43.3846C2.16018 43.8178 1.45769 43.8178 1.02452 43.3846Z"
            fill="#ADADAD"
        />
        <Path
            fillRule="evenodd"
            clipRule="evenodd"
            d="M30.3909 1.80909C30.3909 1.19628 30.8876 0.699572 31.5003 0.699729L42.6002 0.699728C43.2128 0.699571 43.7096 1.19628 43.7096 1.80909V12.909C43.7096 13.5215 43.2128 14.0182 42.6002 14.0184C41.9875 14.0182 41.4908 13.5215 41.4908 12.909V2.9183L31.5003 2.91846C30.8876 2.9183 30.3909 2.42159 30.3909 1.80909Z"
            fill="#ADADAD"
        />
        <Path
            fillRule="evenodd"
            clipRule="evenodd"
            d="M27.6957 16.7134C27.2625 16.2802 27.2625 15.5777 27.6957 15.1445L41.8157 1.02449C42.2489 0.591316 42.9515 0.591316 43.3846 1.02449C43.8178 1.45766 43.8178 2.16021 43.3846 2.59338L29.2646 16.7134C28.8314 17.1466 28.1289 17.1466 27.6957 16.7134Z"
            fill="#ADADAD"
        />
    </Svg>
)

const ExpandedIcon = () => (
    <Svg width="50" height="50" viewBox="0 0 50 50" fill="none">
        <Path
            fillRule="evenodd"
            clipRule="evenodd"
            d="M30.7656 9.0625C31.1884 9.0625 31.5312 9.40529 31.5312 9.82812V16.7188H38.4219C38.8447 16.7188 39.1875 17.0616 39.1875 17.4844C39.1875 17.9072 38.8447 18.25 38.4219 18.25H30.7656C30.3428 18.25 30 17.9072 30 17.4844V9.82812C30 9.40529 30.3428 9.0625 30.7656 9.0625Z"
            fill="#BFBFBF"
        />
        <Path
            fillRule="evenodd"
            clipRule="evenodd"
            d="M42.0258 6.22426C42.3247 6.52325 42.3247 7.00801 42.0258 7.307L31.3071 18.0258C31.008 18.3247 30.5232 18.3247 30.2242 18.0258C29.9253 17.7268 29.9253 17.242 30.2242 16.9429L40.9429 6.22426C41.242 5.92525 41.7268 5.92525 42.0258 6.22426Z"
            fill="#BFBFBF"
        />
        <Path
            fillRule="evenodd"
            clipRule="evenodd"
            d="M9.0625 29.7656C9.0625 29.3428 9.40529 29 9.82812 29H17.4844C17.9072 29 18.25 29.3428 18.25 29.7656V37.4219C18.25 37.8447 17.9072 38.1875 17.4844 38.1875C17.0616 38.1875 16.7188 37.8447 16.7188 37.4219V30.5312H9.82812C9.40529 30.5312 9.0625 30.1884 9.0625 29.7656Z"
            fill="#BFBFBF"
        />
        <Path
            fillRule="evenodd"
            clipRule="evenodd"
            d="M18.0258 29.2242C18.3247 29.5232 18.3247 30.008 18.0258 30.3071L7.307 41.0258C7.00801 41.3247 6.52325 41.3247 6.22426 41.0258C5.92525 40.7268 5.92525 40.242 6.22426 39.9429L16.9429 29.2242C17.242 28.9253 17.7268 28.9253 18.0258 29.2242Z"
            fill="#BFBFBF"
        />
        <Path
            fillRule="evenodd"
            clipRule="evenodd"
            d="M30 29.7656C30 29.3428 30.3428 29 30.7656 29H38.4219C38.8447 29 39.1875 29.3428 39.1875 29.7656C39.1875 30.1884 38.8447 30.5312 38.4219 30.5312H31.5312V37.4219C31.5312 37.8447 31.1884 38.1875 30.7656 38.1875C30.3428 38.1875 30 37.8447 30 37.4219V29.7656Z"
            fill="#BFBFBF"
        />
        <Path
            fillRule="evenodd"
            clipRule="evenodd"
            d="M30.2242 29.2242C30.5232 28.9253 31.008 28.9253 31.3071 29.2242L42.0258 39.9429C42.3247 40.242 42.3247 40.7268 42.0258 41.0258C41.7268 41.3247 41.242 41.3247 40.9429 41.0258L30.2242 30.3071C29.9253 30.008 29.9253 29.5232 30.2242 29.2242Z"
            fill="#BFBFBF"
        />
        <Path
            fillRule="evenodd"
            clipRule="evenodd"
            d="M17.4844 9.0625C17.9072 9.0625 18.25 9.40529 18.25 9.82812V17.4844C18.25 17.9072 17.9072 18.25 17.4844 18.25H9.82812C9.40529 18.25 9.0625 17.9072 9.0625 17.4844C9.0625 17.0616 9.40529 16.7188 9.82812 16.7188H16.7188V9.82812C16.7188 9.40529 17.0616 9.0625 17.4844 9.0625Z"
            fill="#BFBFBF"
        />
        <Path
            fillRule="evenodd"
            clipRule="evenodd"
            d="M6.22426 6.22426C6.52325 5.92525 7.00801 5.92525 7.307 6.22426L18.0258 16.9429C18.3247 17.242 18.3247 17.7268 18.0258 18.0258C17.7268 18.3247 17.242 18.3247 16.9429 18.0258L6.22426 7.307C5.92525 7.00801 5.92525 6.52325 6.22426 6.22426Z"
            fill="#BFBFBF"
        />
    </Svg>
)
