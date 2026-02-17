import React from "react"
import { View, StyleSheet } from "react-native"
import { converterTools } from "../data/converterTools"
import ConverterDetail from "../components/ConverterDetail"
import Currency from "./Currency"

type Props = {
    toolKey: string
}

export default ({ toolKey }: Props) => {
    if (toolKey === "currency") {
        return (
            <View style={styles.container}>
                <Currency />
            </View>
        )
    }

    const tool = converterTools.find((t) => t.key === toolKey)
    if (!tool) return null

    return (
        <View style={styles.container}>
            <ConverterDetail tool={tool} />
        </View>
    )
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        width: "100%",
        backgroundColor: "black",
    },
})
