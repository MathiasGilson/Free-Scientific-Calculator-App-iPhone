import React, { useState } from "react"
import { View, StyleSheet, ScrollView } from "react-native"
import { SafeAreaView } from "react-native-safe-area-context"
import { converterTools, ConverterTool } from "../data/converterTools"
import ConverterToolCard from "../components/ConverterToolCard"
import ConverterDetail from "../components/ConverterDetail"

type Props = {
    focused?: boolean
    pinnedTools?: string[]
    onPinnedToolsChange?: (keys: string[]) => void
}

export default ({ focused = false, pinnedTools = [], onPinnedToolsChange }: Props) => {
    const [selectedTool, setSelectedTool] = useState<ConverterTool | null>(null)

    const togglePin = (toolKey: string) => {
        if (!onPinnedToolsChange) return
        const next = pinnedTools.includes(toolKey)
            ? pinnedTools.filter((k) => k !== toolKey)
            : [...pinnedTools, toolKey]
        onPinnedToolsChange(next)
    }

    if (selectedTool) {
        return (
            <View style={styles.container}>
                <ConverterDetail
                    tool={selectedTool}
                    onBack={() => setSelectedTool(null)}
                    isPinned={pinnedTools.includes(selectedTool.key)}
                    onTogglePin={() => togglePin(selectedTool.key)}
                />
            </View>
        )
    }

    return (
        <SafeAreaView style={styles.container}>
            <ScrollView contentContainerStyle={styles.grid}>
                {converterTools
                    .slice()
                    .sort((a, b) => {
                        const ap = pinnedTools.includes(a.key) ? 0 : 1
                        const bp = pinnedTools.includes(b.key) ? 0 : 1
                        return ap - bp
                    })
                    .map((tool) => (
                        <ConverterToolCard
                            key={tool.key}
                            tool={tool}
                            onPress={() => setSelectedTool(tool)}
                        />
                    ))}
            </ScrollView>
        </SafeAreaView>
    )
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        width: "100%",
        backgroundColor: "black",
    },
    grid: {
        flexDirection: "row",
        flexWrap: "wrap",
        justifyContent: "center",
        paddingTop: 80,
        paddingHorizontal: 10,
    },
})
