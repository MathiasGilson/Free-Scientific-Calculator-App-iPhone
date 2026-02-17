import React, { useEffect, useState, useContext } from "react"
import { View, Text, SectionList, TouchableOpacity, StyleSheet, Alert } from "react-native"
import { SafeAreaView } from "react-native-safe-area-context"
import dayjs from "dayjs"
import { getHistory, clearHistory, CalculationEntry } from "../utils/historyStorage"
import LucideIcon from "./LucideIcon"
import { HistoryContext } from "../../App"

type Section = {
    title: string
    data: CalculationEntry[]
}

function groupByDate(entries: CalculationEntry[]): Section[] {
    const groups: Record<string, CalculationEntry[]> = {}
    const order: string[] = []

    for (const entry of entries) {
        const d = dayjs(entry.timestamp)
        const today = dayjs().startOf("day")
        const yesterday = today.subtract(1, "day")

        let label: string
        if (d.isAfter(today)) {
            label = "Today"
        } else if (d.isAfter(yesterday)) {
            label = "Yesterday"
        } else {
            label = d.format("MMMM D, YYYY")
        }

        if (!groups[label]) {
            groups[label] = []
            order.push(label)
        }
        groups[label].push(entry)
    }

    return order.map((title) => ({ title, data: groups[title] }))
}

export default function HistoryDrawerContent({ onClose }: { onClose?: () => void }) {
    const [sections, setSections] = useState<Section[]>([])
    const { onSelect, refreshKey } = useContext(HistoryContext)

    useEffect(() => {
        getHistory().then((entries) => setSections(groupByDate(entries)))
    }, [refreshKey])

    const handleClear = () => {
        Alert.alert("Clear History", "Remove all calculation history?", [
            { text: "Cancel", style: "cancel" },
            {
                text: "Clear",
                style: "destructive",
                onPress: async () => {
                    await clearHistory()
                    setSections([])
                },
            },
        ])
    }

    const renderItem = ({ item }: { item: CalculationEntry }) => (
        <TouchableOpacity style={styles.row} onPress={() => onSelect(item.expression)} activeOpacity={0.6}>
            <Text style={styles.expression}>{item.expression}</Text>
            <Text style={styles.result}>= {item.result}</Text>
        </TouchableOpacity>
    )

    const renderSectionHeader = ({ section }: { section: Section }) => (
        <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>{section.title}</Text>
        </View>
    )

    return (
        <SafeAreaView style={styles.container} edges={["bottom"]}>
            <View style={styles.handle} />
            <View style={styles.header}>
                <Text style={styles.headerTitle}>History</Text>
                {onClose && (
                    <TouchableOpacity onPress={onClose} style={styles.closeButton} activeOpacity={0.6}>
                        <LucideIcon name="x" size={22} color="#888" />
                    </TouchableOpacity>
                )}
            </View>

            {sections.length === 0 ? (
                <View style={styles.empty}>
                    <LucideIcon name="clock" size={48} color="#555" />
                    <Text style={styles.emptyText}>No calculations yet</Text>
                </View>
            ) : (
                <>
                    <SectionList
                        sections={sections}
                        keyExtractor={(item, index) => `${item.timestamp}-${index}`}
                        renderItem={renderItem}
                        renderSectionHeader={renderSectionHeader}
                        contentContainerStyle={styles.list}
                        stickySectionHeadersEnabled={false}
                    />
                    <TouchableOpacity style={styles.clearButton} onPress={handleClear} activeOpacity={0.7}>
                        <LucideIcon name="trash-2" size={18} color="#ff4444" />
                        <Text style={styles.clearText}>Clear History</Text>
                    </TouchableOpacity>
                </>
            )}
        </SafeAreaView>
    )
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: "#1c1c1e",
    },
    handle: {
        width: 36,
        height: 5,
        borderRadius: 3,
        backgroundColor: "#555",
        alignSelf: "center",
        marginTop: 8,
        marginBottom: 4,
    },
    header: {
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "space-between",
        paddingHorizontal: 20,
        paddingVertical: 12,
        borderBottomWidth: StyleSheet.hairlineWidth,
        borderBottomColor: "#333",
    },
    headerTitle: {
        fontSize: 22,
        fontWeight: "700",
        color: "#fff",
    },
    closeButton: {
        padding: 4,
    },
    list: {
        paddingBottom: 20,
    },
    sectionHeader: {
        paddingHorizontal: 20,
        paddingTop: 20,
        paddingBottom: 8,
    },
    sectionTitle: {
        fontSize: 14,
        fontWeight: "600",
        color: "#888",
        textTransform: "uppercase",
        letterSpacing: 0.5,
    },
    row: {
        paddingHorizontal: 20,
        paddingVertical: 12,
    },
    expression: {
        fontSize: 15,
        color: "#999",
    },
    result: {
        fontSize: 20,
        color: "#fff",
        fontWeight: "500",
        marginTop: 2,
    },
    empty: {
        flex: 1,
        justifyContent: "center",
        alignItems: "center",
        gap: 12,
    },
    emptyText: {
        fontSize: 16,
        color: "#555",
    },
    clearButton: {
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "center",
        gap: 8,
        paddingVertical: 16,
        borderTopWidth: StyleSheet.hairlineWidth,
        borderTopColor: "#333",
    },
    clearText: {
        fontSize: 16,
        color: "#ff4444",
    },
})
