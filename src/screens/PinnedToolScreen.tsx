import React from "react"
import { View, StyleSheet } from "react-native"
import { converterTools } from "../data/converterTools"
import ConverterDetail from "../components/ConverterDetail"

type Props = {
    toolKey: string
    onUnpin: () => void
}

export default ({ toolKey, onUnpin }: Props) => {
    const tool = converterTools.find((t) => t.key === toolKey)
    if (!tool) return null

    return (
        <View style={styles.container}>
            <ConverterDetail tool={tool} isPinned={true} onTogglePin={onUnpin} />
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
