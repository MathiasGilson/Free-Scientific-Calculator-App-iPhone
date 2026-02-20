import React, { useState, useRef, useCallback, useEffect, useMemo } from "react"
import { View, Text, StyleSheet, ScrollView, Pressable, Dimensions } from "react-native"
import { SafeAreaView } from "react-native-safe-area-context"
import AsyncStorage from "@react-native-async-storage/async-storage"
import { Gesture, GestureDetector } from "react-native-gesture-handler"
import Animated, {
    useSharedValue,
    useAnimatedStyle,
    withSpring,
    withTiming,
    withRepeat,
    withSequence,
    runOnJS,
    cancelAnimation,
    makeMutable,
    type SharedValue,
} from "react-native-reanimated"
import { converterTools, ConverterTool } from "../data/converterTools"
import ConverterToolCard from "../components/ConverterToolCard"
import ConverterDetail from "../components/ConverterDetail"
import LucideIcon from "../components/LucideIcon"
import Currency from "./Currency"
import { hapticFeedbackSwitch } from "../utils"

const { width: screenWidth } = Dimensions.get("window")
const COLUMNS = 4
const CARD_MARGIN = 8
const GRID_PADDING = 10
const CARD_SIZE = (screenWidth - GRID_PADDING * 2 - CARD_MARGIN * 2 * COLUMNS) / COLUMNS
const CELL_SIZE = CARD_SIZE + CARD_MARGIN * 2
const TOOL_ORDER_KEY = "converterToolOrder"
const INLINE_BAR_ICON = 28
const INLINE_BAR_ITEM_WIDTH = INLINE_BAR_ICON + 20
const INLINE_BAR_ITEM_STEP = INLINE_BAR_ITEM_WIDTH + 2
const INLINE_BAR_ITEM_HEIGHT = INLINE_BAR_ICON + 16
const NUM_TOOLS = converterTools.length
const MAX_BAR_ITEMS = 20
const MAX_PINNED_TOOLS = 5

function iconForKey(key: string): string {
    if (key === "_calculator") return "calculator"
    const tool = converterTools.find((t) => t.key === key)
    return tool?.icon || "bookmark"
}

function getPosition(index: number) {
    return {
        x: (index % COLUMNS) * CELL_SIZE,
        y: Math.floor(index / COLUMNS) * CELL_SIZE,
    }
}

type Props = {
    focused?: boolean
    pinnedTools?: string[]
    screenOrder?: string[]
    onPinnedToolsChange?: (keys: string[]) => void
    onRearrangeChange?: (active: boolean) => void
    onDetailChange?: (open: boolean) => void
}

export default ({ focused = false, pinnedTools = [], screenOrder = [], onPinnedToolsChange, onRearrangeChange, onDetailChange }: Props) => {
    const [selectedTool, setSelectedTool] = useState<ConverterTool | null>(null)
    const [toolOrder, setToolOrder] = useState<string[]>(() => converterTools.map(t => t.key))
    const [rearranging, setRearranging] = useState(false)
    const [dragIdx, setDragIdx] = useState<number | null>(null)
    const [dropTarget, setDropTarget] = useState<string | null>(null)
    const [dropInsertIndex, setDropInsertIndex] = useState<number | null>(null)
    const [highlightBarKey, setHighlightBarKey] = useState<string | null>(null)

    const rearrangingRef = useRef(false)
    const dragIdxRef = useRef<number | null>(null)
    const toolOrderRef = useRef(toolOrder)
    const lastTargetRef = useRef(0)
    const onRearrangeChangeRef = useRef(onRearrangeChange)
    const pinnedToolsRef = useRef(pinnedTools)
    const onPinnedToolsChangeRef = useRef(onPinnedToolsChange)
    const screenOrderRef = useRef(screenOrder)
    const containerOffsetY = useRef(0)
    const containerRef = useRef<View>(null)
    const dragStartAbs = useRef({ x: 0, y: 0 })
    const dragStartIdx = useRef(0)
    const inlineBarRef = useRef<View>(null)
    const inlineBarLayout = useRef({ x: 0, y: 0, width: 0, height: 0 })

    // Reanimated shared values for floating card
    const dragAbsX = useSharedValue(0)
    const dragAbsY = useSharedValue(0)
    const dragScale = useSharedValue(1)
    const isDragging = useSharedValue(false)

    // Pre-allocate card offset shared values for all tools
    const cardOffsets = useMemo(() =>
        Array.from({ length: NUM_TOOLS }, () => ({
            x: makeMutable(0),
            y: makeMutable(0),
        })),
    [])

    // Wiggle animation
    const shakeValue = useSharedValue(0)

    // Drop preview animation
    const dropPreviewScale = useSharedValue(0)
    const pulseValue = useSharedValue(0)

    // Inline bar reorder drag state (mirrors grid card drag pattern)
    const [barDragIdx, setBarDragIdx] = useState<number | null>(null)
    const barDragIdxRef = useRef<number | null>(null)
    const barLastTargetRef = useRef(0)
    const barFloatingX = useSharedValue(0)
    const barFloatingY = useSharedValue(0)
    const barFloatingScale = useSharedValue(0)
    const barFloatingOpacity = useSharedValue(0)
    const barItemOffsets = useMemo(() =>
        Array.from({ length: MAX_BAR_ITEMS }, () => makeMutable(0)),
    [])

    // Toast state
    const [toastMessage, setToastMessage] = useState<string | null>(null)
    const toastOpacity = useSharedValue(0)
    const toastTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

    const showToast = useCallback((msg: string) => {
        if (toastTimerRef.current) clearTimeout(toastTimerRef.current)
        setToastMessage(msg)
        toastOpacity.value = withTiming(1, { duration: 200 })
        toastTimerRef.current = setTimeout(() => {
            toastOpacity.value = withTiming(0, { duration: 300 }, () => {
                runOnJS(setToastMessage)(null)
            })
        }, 2000)
    }, [toastOpacity])

    const toastAnimStyle = useAnimatedStyle(() => ({
        opacity: toastOpacity.value,
        transform: [{ translateY: withTiming(toastOpacity.value > 0 ? 0 : -10, { duration: 200 }) }],
    }))

    useEffect(() => { onRearrangeChangeRef.current = onRearrangeChange }, [onRearrangeChange])
    useEffect(() => { pinnedToolsRef.current = pinnedTools }, [pinnedTools])
    useEffect(() => { onPinnedToolsChangeRef.current = onPinnedToolsChange }, [onPinnedToolsChange])
    useEffect(() => { screenOrderRef.current = screenOrder }, [screenOrder])

    useEffect(() => {
        onDetailChange?.(selectedTool !== null)
    }, [selectedTool, onDetailChange])

    useEffect(() => {
        if (dropTarget) {
            dropPreviewScale.value = withTiming(1, { duration: 200 })
            pulseValue.value = withRepeat(
                withSequence(
                    withTiming(1, { duration: 600 }),
                    withTiming(0, { duration: 600 })
                ),
                -1
            )
        } else {
            cancelAnimation(pulseValue)
            dropPreviewScale.value = withTiming(0, { duration: 150 })
        }
    }, [dropTarget, dropPreviewScale, pulseValue])

    useEffect(() => {
        AsyncStorage.getItem(TOOL_ORDER_KEY).then(raw => {
            if (raw) {
                try {
                    const parsed = JSON.parse(raw)
                    const allKeys = converterTools.map(t => t.key)
                    const valid = parsed.filter((k: string) => allKeys.includes(k))
                    const missing = allKeys.filter(k => !valid.includes(k))
                    const merged = [...valid, ...missing]
                    setToolOrder(merged)
                    toolOrderRef.current = merged
                } catch {}
            }
        })
    }, [])

    const orderedTools = toolOrder
        .map(key => converterTools.find(t => t.key === key))
        .filter(Boolean) as ConverterTool[]

    const startShake = useCallback(() => {
        shakeValue.value = withRepeat(
            withSequence(
                withTiming(1, { duration: 75 }),
                withTiming(-1, { duration: 150 }),
                withTiming(0, { duration: 75 })
            ),
            -1
        )
    }, [shakeValue])

    const stopShake = useCallback(() => {
        cancelAnimation(shakeValue)
        shakeValue.value = 0
    }, [shakeValue])

    const resetDragOnly = useCallback(() => {
        dragIdxRef.current = null
        setDragIdx(null)
        isDragging.value = false
        dragScale.value = withTiming(1, { duration: 200 })
        cardOffsets.forEach(o => {
            o.x.value = withTiming(0, { duration: 200 })
            o.y.value = withTiming(0, { duration: 200 })
        })
    }, [isDragging, dragScale, cardOffsets])

    const exitRearrange = useCallback(() => {
        rearrangingRef.current = false
        setRearranging(false)
        resetDragOnly()
        stopShake()
        onRearrangeChangeRef.current?.(false)
    }, [resetDragOnly, stopShake])

    const startDrag = useCallback((idx: number, absX: number, absY: number) => {
        if (!rearrangingRef.current) {
            hapticFeedbackSwitch()
            rearrangingRef.current = true
            setRearranging(true)
            startShake()
            onRearrangeChangeRef.current?.(true)
        }

        cardOffsets.forEach(o => { o.x.value = 0; o.y.value = 0 })
        inlineBarRef.current?.measureInWindow((x, y, w, h) => {
            inlineBarLayout.current = { x, y, width: w, height: h }
        })
        containerRef.current?.measureInWindow((_x, y) => {
            containerOffsetY.current = y
        })
        dragIdxRef.current = idx
        dragStartIdx.current = idx
        dragStartAbs.current = { x: absX, y: absY }
        lastTargetRef.current = idx
        setDragIdx(idx)
        dragAbsX.value = absX - CELL_SIZE / 2
        dragAbsY.value = absY - containerOffsetY.current - CELL_SIZE / 2
        isDragging.value = true
        dragScale.value = withTiming(1.1, { duration: 150 })
    }, [cardOffsets, dragAbsX, dragAbsY, dragScale, isDragging, startShake])

    // Compute insert index for dropping into the pinned bar
    const computeInsertIndex = useCallback((absX: number): number | null => {
        const bar = inlineBarLayout.current
        if (bar.width === 0) return null

        const order = screenOrderRef.current
        const totalWidth = order.length * INLINE_BAR_ITEM_STEP
        const barStartX = bar.x + (bar.width - totalWidth) / 2

        const relX = absX - barStartX
        const idx = Math.round(relX / INLINE_BAR_ITEM_STEP)
        return Math.max(0, Math.min(order.length, idx))
    }, [])

    const isOverInlineBar = useCallback((absY: number): boolean => {
        const bar = inlineBarLayout.current
        if (bar.width === 0) return false
        return absY < bar.y + bar.height + 30
    }, [])

    const handleDragMove = useCallback((absX: number, absY: number) => {
        const fromIdx = dragIdxRef.current
        if (fromIdx === null) return

        dragAbsX.value = absX - CELL_SIZE / 2
        dragAbsY.value = absY - containerOffsetY.current - CELL_SIZE / 2

        const draggedKey = toolOrderRef.current[fromIdx]
        const alreadyPinned = pinnedToolsRef.current.includes(draggedKey)
        const barFull = pinnedToolsRef.current.length >= MAX_PINNED_TOOLS
        const overBar = isOverInlineBar(absY) && !alreadyPinned && !barFull

        setHighlightBarKey(isOverInlineBar(absY) && alreadyPinned ? draggedKey : null)

        if (overBar) {
            const insertIdx = computeInsertIndex(absX) ?? screenOrderRef.current.length
            setDropTarget(draggedKey)
            setDropInsertIndex(insertIdx)
            // Shift bar items to make room for the drop preview
            const barCount = screenOrderRef.current.length
            for (let i = 0; i < barCount; i++) {
                barItemOffsets[i].value = withTiming(
                    i >= insertIdx ? INLINE_BAR_ITEM_STEP : 0,
                    { duration: 200 }
                )
            }
        } else {
            setDropTarget(null)
            setDropInsertIndex(null)
            // Reset bar item offsets when leaving bar
            const barCount = screenOrderRef.current.length
            for (let i = 0; i < barCount; i++) {
                barItemOffsets[i].value = withTiming(0, { duration: 200 })
            }
        }

        // Grid reorder logic — use relative movement from drag start
        const startCol = dragStartIdx.current % COLUMNS
        const startRow = Math.floor(dragStartIdx.current / COLUMNS)
        const deltaX = absX - dragStartAbs.current.x
        const deltaY = absY - dragStartAbs.current.y
        const count = toolOrderRef.current.length
        const maxRow = Math.ceil(count / COLUMNS) - 1

        const col = Math.max(0, Math.min(COLUMNS - 1, startCol + Math.round(deltaX / CELL_SIZE)))
        const row = Math.max(0, Math.min(maxRow, startRow + Math.round(deltaY / CELL_SIZE)))
        const targetIdx = Math.min(count - 1, Math.max(0, row * COLUMNS + col))
        lastTargetRef.current = targetIdx

        for (let i = 0; i < count; i++) {
            if (i === fromIdx) continue
            const homePos = getPosition(i)
            let displayIdx = i
            if (targetIdx > fromIdx) {
                if (i > fromIdx && i <= targetIdx) displayIdx = i - 1
            } else if (targetIdx < fromIdx) {
                if (i >= targetIdx && i < fromIdx) displayIdx = i + 1
            }
            const displayPos = getPosition(displayIdx)
            const offset = cardOffsets[i]
            if (offset) {
                offset.x.value = withTiming(displayPos.x - homePos.x, { duration: 200 })
                offset.y.value = withTiming(displayPos.y - homePos.y, { duration: 200 })
            }
        }
    }, [dragAbsX, dragAbsY, computeInsertIndex, isOverInlineBar, cardOffsets, barItemOffsets])

    const handleDragEnd = useCallback((absX: number, absY: number) => {
        const fromIdx = dragIdxRef.current
        if (fromIdx === null) return

        const draggedKey = toolOrderRef.current[fromIdx]
        const alreadyPinned = pinnedToolsRef.current.includes(draggedKey)
        const barFull = pinnedToolsRef.current.length >= MAX_PINNED_TOOLS
        const overBar = isOverInlineBar(absY) && !alreadyPinned

        if (overBar) {
            if (barFull) {
                showToast("Toolbar is full (max 5)")
            } else {
                const insertIdx = computeInsertIndex(absX)
                const currentOrder = screenOrderRef.current.slice()
                const idx = insertIdx !== null ? Math.min(insertIdx, currentOrder.length) : currentOrder.length
                currentOrder.splice(idx, 0, draggedKey)
                onPinnedToolsChangeRef.current?.(currentOrder)
            }
        }

        // Reorder grid
        const toIdx = lastTargetRef.current
        const reordered = [...toolOrderRef.current]
        const [item] = reordered.splice(fromIdx, 1)
        reordered.splice(toIdx, 0, item)
        toolOrderRef.current = reordered

        // Update state first so React re-renders with the new order
        setDropTarget(null)
        setDropInsertIndex(null)
        setHighlightBarKey(null)
        setToolOrder(reordered)
        AsyncStorage.setItem(TOOL_ORDER_KEY, JSON.stringify(reordered))

        // Defer visual cleanup until after re-render to avoid flash of old order
        requestAnimationFrame(() => {
            dragIdxRef.current = null
            setDragIdx(null)
            isDragging.value = false
            dragScale.value = withTiming(1, { duration: 200 })
            cardOffsets.forEach(o => { o.x.value = 0; o.y.value = 0 })
            for (let i = 0; i < MAX_BAR_ITEMS; i++) barItemOffsets[i].value = 0
        })
    }, [computeInsertIndex, isOverInlineBar, isDragging, dragScale, cardOffsets, barItemOffsets, showToast])

    const handleCardPressOut = useCallback((idx: number) => {
        setTimeout(() => {
            if (dragIdxRef.current === idx && !isDragging.value) {
                resetDragOnly()
            }
        }, 50)
    }, [resetDragOnly, isDragging])

    const unpinTool = useCallback((key: string) => {
        if (!onPinnedToolsChangeRef.current) return
        const next = screenOrderRef.current.filter(k => k !== key)
        onPinnedToolsChangeRef.current(next)
    }, [])

    // Inline bar reorder handlers (same pattern as grid card drag)
    const startBarDrag = useCallback((idx: number, absX: number, absY: number) => {
        hapticFeedbackSwitch()
        for (let i = 0; i < MAX_BAR_ITEMS; i++) barItemOffsets[i].value = 0
        barDragIdxRef.current = idx
        barLastTargetRef.current = idx
        setBarDragIdx(idx)
        barFloatingX.value = absX - INLINE_BAR_ITEM_WIDTH / 2
        barFloatingY.value = absY - containerOffsetY.current - INLINE_BAR_ITEM_HEIGHT / 2
        barFloatingScale.value = withTiming(1.15, { duration: 150 })
        barFloatingOpacity.value = 1
    }, [barItemOffsets, barFloatingX, barFloatingY, barFloatingScale, barFloatingOpacity])

    const handleBarDragMove = useCallback((absX: number, absY: number) => {
        const fromIdx = barDragIdxRef.current
        if (fromIdx === null) return

        barFloatingX.value = absX - INLINE_BAR_ITEM_WIDTH / 2
        barFloatingY.value = absY - containerOffsetY.current - INLINE_BAR_ITEM_HEIGHT / 2

        const bar = inlineBarLayout.current
        if (bar.width === 0) return

        const order = screenOrderRef.current
        const totalWidth = order.length * INLINE_BAR_ITEM_STEP
        const barStartX = bar.x + (bar.width - totalWidth) / 2
        const relX = absX - barStartX
        const targetIdx = Math.max(0, Math.min(order.length - 1, Math.round(relX / INLINE_BAR_ITEM_STEP)))
        barLastTargetRef.current = targetIdx

        for (let i = 0; i < order.length; i++) {
            if (i === fromIdx) continue
            let shift = 0
            if (targetIdx > fromIdx) {
                if (i > fromIdx && i <= targetIdx) shift = -INLINE_BAR_ITEM_STEP
            } else if (targetIdx < fromIdx) {
                if (i >= targetIdx && i < fromIdx) shift = INLINE_BAR_ITEM_STEP
            }
            barItemOffsets[i].value = withTiming(shift, { duration: 200 })
        }
    }, [barItemOffsets, barFloatingX, barFloatingY])

    const handleBarDragEnd = useCallback(() => {
        const fromIdx = barDragIdxRef.current
        const toIdx = barLastTargetRef.current

        // Update state first so React re-renders with the new order
        if (fromIdx !== null && fromIdx !== toIdx) {
            const order = screenOrderRef.current.slice()
            const [item] = order.splice(fromIdx, 1)
            order.splice(toIdx, 0, item)
            onPinnedToolsChangeRef.current?.(order)
        }

        // Defer visual cleanup until after re-render to avoid flash of old order
        requestAnimationFrame(() => {
            barDragIdxRef.current = null
            setBarDragIdx(null)
            for (let i = 0; i < MAX_BAR_ITEMS; i++) barItemOffsets[i].value = 0
            barFloatingScale.value = withTiming(0, { duration: 150 })
            barFloatingOpacity.value = 0
        })
    }, [barItemOffsets, barFloatingScale, barFloatingOpacity])

    const handleBarPressOut = useCallback((idx: number) => {
        setTimeout(() => {
            if (barDragIdxRef.current === idx) {
                barDragIdxRef.current = null
                setBarDragIdx(null)
                for (let i = 0; i < MAX_BAR_ITEMS; i++) barItemOffsets[i].value = 0
                barFloatingScale.value = withTiming(0, { duration: 150 })
                barFloatingOpacity.value = 0
            }
        }, 50)
    }, [barItemOffsets, barFloatingScale, barFloatingOpacity])

    // Animated styles
    const floatingCardStyle = useAnimatedStyle(() => {
        return {
            transform: [
                { translateX: dragAbsX.value },
                { translateY: dragAbsY.value },
                { scale: dragScale.value },
            ] as const,
            opacity: isDragging.value ? 1 : 0,
        }
    })

    const floatingBarIconStyle = useAnimatedStyle(() => ({
        transform: [
            { translateX: barFloatingX.value },
            { translateY: barFloatingY.value },
            { scale: barFloatingScale.value },
        ] as const,
        opacity: barFloatingOpacity.value,
    }))

    const dropPreviewAnimStyle = useAnimatedStyle(() => ({
        opacity: dropPreviewScale.value,
        transform: [{ scale: dropPreviewScale.value }],
    }))

    const dropPreviewBgStyle = useAnimatedStyle(() => ({
        opacity: 0.15 + pulseValue.value * 0.2,
    }))

    // Swipe-back gesture for detail views
    const detailTranslateX = useSharedValue(0)

    const openTool = useCallback((tool: ConverterTool) => {
        detailTranslateX.value = screenWidth
        setSelectedTool(tool)
        detailTranslateX.value = withTiming(0, { duration: 300 })
    }, [detailTranslateX])

    const goBack = useCallback(() => {
        detailTranslateX.value = withTiming(screenWidth, { duration: 200 }, () => {
            runOnJS(setSelectedTool)(null)
        })
    }, [detailTranslateX])

    const clearSelectedTool = useCallback(() => {
        setSelectedTool(null)
    }, [])

    const detailPanGesture = Gesture.Pan()
        .activeOffsetX(10)
        .failOffsetY([-20, 20])
        .onUpdate((e) => {
            if (e.translationX > 0) {
                detailTranslateX.value = e.translationX
            }
        })
        .onEnd((e) => {
            if (e.translationX > screenWidth * 0.3 || e.velocityX > 500) {
                detailTranslateX.value = withTiming(screenWidth, { duration: 200 }, () => {
                    runOnJS(clearSelectedTool)()
                })
            } else {
                detailTranslateX.value = withTiming(0, { duration: 200 })
            }
        })

    const detailAnimStyle = useAnimatedStyle(() => ({
        transform: [{ translateX: detailTranslateX.value }],
    }))

    const rows = Math.ceil(orderedTools.length / COLUMNS)
    const gridHeight = rows * CELL_SIZE

    // Build inline bar items with absolute positioning (same as grid cards)
    const renderInlineBarItems = () => {
        if (!rearranging) return null

        const items: React.ReactNode[] = []

        screenOrder.forEach((key, i) => {
            // Drop preview from grid-to-bar drag
            if (dropTarget && dropInsertIndex === i) {
                items.push(
                    <Animated.View
                        key="__drop_preview"
                        style={[styles.inlineBarItem, styles.barItemAbsolute, { left: i * INLINE_BAR_ITEM_STEP, zIndex: 2 }, dropPreviewAnimStyle]}
                    >
                        <Animated.View style={[styles.dropPreviewBg, dropPreviewBgStyle]} />
                        <LucideIcon name={iconForKey(dropTarget)} size={INLINE_BAR_ICON} color="#F69A06" />
                    </Animated.View>
                )
            }

            items.push(
                <DraggableBarItem
                    key={key}
                    itemKey={key}
                    index={i}
                    positionX={i * INLINE_BAR_ITEM_STEP}
                    isDraggedIdx={barDragIdx}
                    highlighted={highlightBarKey === key}
                    barOffset={barItemOffsets[i]}
                    onLongPress={(absX: number, absY: number) => startBarDrag(i, absX, absY)}
                    onDragMove={handleBarDragMove}
                    onDragEnd={handleBarDragEnd}
                    onPressOut={() => handleBarPressOut(i)}
                    onUnpin={unpinTool}
                    showUnpin={key !== "_calculator"}
                />
            )
        })

        // Drop preview at end
        if (dropTarget && (dropInsertIndex === null || dropInsertIndex >= screenOrder.length)) {
            items.push(
                <Animated.View
                    key="__drop_preview"
                    style={[styles.inlineBarItem, styles.barItemAbsolute, { left: screenOrder.length * INLINE_BAR_ITEM_STEP, zIndex: 2 }, dropPreviewAnimStyle]}
                >
                    <Animated.View style={[styles.dropPreviewBg, dropPreviewBgStyle]} />
                    <LucideIcon name={iconForKey(dropTarget)} size={INLINE_BAR_ICON} color="#F69A06" />
                </Animated.View>
            )
        }

        const totalWidth = screenOrder.length * INLINE_BAR_ITEM_STEP
        return (
            <View style={{ width: totalWidth, height: INLINE_BAR_ITEM_HEIGHT }}>
                {items}
            </View>
        )
    }

    return (
        <SafeAreaView style={styles.container}>
            <View style={styles.innerContainer} ref={containerRef} onLayout={() => {
                containerRef.current?.measureInWindow((_x, y) => { containerOffsetY.current = y })
            }}>
                <View
                    style={styles.inlineBar}
                    ref={inlineBarRef}
                    onLayout={() => {
                        inlineBarRef.current?.measureInWindow((x, y, w, h) => {
                            inlineBarLayout.current = { x, y, width: w, height: h }
                        })
                    }}
                >
                    {renderInlineBarItems()}
                </View>
                <ScrollView
                    scrollEnabled={!rearranging}
                    contentContainerStyle={styles.scrollContent}
                    contentInsetAdjustmentBehavior="automatic"
                >
                    <View style={[styles.gridContainer, { height: gridHeight }]}>
                        {rearranging && (
                            <Pressable
                                style={styles.dismissOverlay}
                                onPress={exitRearrange}
                            />
                        )}
                        {orderedTools.map((tool, i) => (
                            <DraggableCard
                                key={tool.key}
                                tool={tool}
                                index={i}
                                isDraggedIdx={dragIdx}
                                rearranging={rearranging}
                                shakeValue={shakeValue}
                                offsetX={cardOffsets[i]?.x}
                                offsetY={cardOffsets[i]?.y}
                                onPress={() => openTool(tool)}
                                onLongPress={(absX: number, absY: number) => startDrag(i, absX, absY)}
                                onPressOut={() => handleCardPressOut(i)}
                                onDragMove={handleDragMove}
                                onDragEnd={handleDragEnd}
                            />
                        ))}
                    </View>
                </ScrollView>
                {dragIdx !== null && orderedTools[dragIdx] && (
                    <Animated.View
                        pointerEvents="none"
                        style={[
                            styles.floatingCard,
                            { width: CELL_SIZE, height: CELL_SIZE },
                            floatingCardStyle,
                        ]}
                    >
                        <ConverterToolCard tool={orderedTools[dragIdx]} />
                    </Animated.View>
                )}
                {barDragIdx !== null && screenOrder[barDragIdx] && (
                    <Animated.View
                        pointerEvents="none"
                        style={[styles.floatingBarIcon, floatingBarIconStyle]}
                    >
                        <LucideIcon name={iconForKey(screenOrder[barDragIdx])} size={INLINE_BAR_ICON} color="#999" />
                    </Animated.View>
                )}
                {toastMessage && (
                    <Animated.View pointerEvents="none" style={[styles.toast, toastAnimStyle]}>
                        <Text style={styles.toastText}>{toastMessage}</Text>
                    </Animated.View>
                )}
            </View>
            {selectedTool && (
                <GestureDetector gesture={detailPanGesture}>
                    <Animated.View style={[styles.detailOverlay, detailAnimStyle]}>
                        {selectedTool.key === "currency"
                            ? <Currency onBack={goBack} />
                            : <ConverterDetail tool={selectedTool} onBack={goBack} />
                        }
                    </Animated.View>
                </GestureDetector>
            )}
        </SafeAreaView>
    )
}

// Draggable inline bar item (same gesture pattern as DraggableCard)
type DraggableBarItemProps = {
    itemKey: string
    index: number
    positionX: number
    isDraggedIdx: number | null
    highlighted?: boolean
    barOffset?: SharedValue<number>
    onLongPress: (absX: number, absY: number) => void
    onDragMove: (absX: number, absY: number) => void
    onDragEnd: () => void
    onPressOut: () => void
    onUnpin: (key: string) => void
    showUnpin?: boolean
}

const DraggableBarItem = React.memo(({
    itemKey, index, positionX, isDraggedIdx, highlighted,
    barOffset, onLongPress, onDragMove, onDragEnd, onPressOut,
    onUnpin, showUnpin = true,
}: DraggableBarItemProps) => {
    const isDragged = isDraggedIdx === index
    const activated = useSharedValue(false)

    const longPressGesture = Gesture.LongPress()
        .minDuration(100)
        .onStart((e) => {
            activated.value = true
            runOnJS(onLongPress)(e.absoluteX, e.absoluteY)
        })

    const panGesture = Gesture.Pan()
        .activateAfterLongPress(100)
        .onUpdate((e) => {
            runOnJS(onDragMove)(e.absoluteX, e.absoluteY)
        })
        .onEnd(() => {
            activated.value = false
            runOnJS(onDragEnd)()
        })
        .onFinalize(() => {
            if (!activated.value) return
            activated.value = false
            runOnJS(onPressOut)()
        })

    const composedGesture = Gesture.Simultaneous(longPressGesture, panGesture)

    const animStyle = useAnimatedStyle(() => {
        const tx = barOffset ? barOffset.value : 0
        return {
            opacity: isDragged ? 0 : 1,
            zIndex: 1,
            transform: [{ translateX: tx }],
        }
    })

    return (
        <GestureDetector gesture={composedGesture}>
            <Animated.View
                style={[
                    styles.cardWrapper,
                    {
                        left: positionX,
                        top: 0,
                        width: INLINE_BAR_ITEM_WIDTH,
                        height: INLINE_BAR_ITEM_HEIGHT,
                        alignItems: "center" as const,
                        justifyContent: "center" as const,
                        overflow: "visible" as const,
                    },
                    animStyle,
                ]}
            >
                <LucideIcon name={iconForKey(itemKey)} size={INLINE_BAR_ICON} color={highlighted ? "#F69A06" : "#999"} />
                {showUnpin && (
                    <Pressable style={styles.unpinBadge} onPress={() => onUnpin(itemKey)} hitSlop={6}>
                        <LucideIcon name="x" size={8} color="#fff" />
                    </Pressable>
                )}
            </Animated.View>
        </GestureDetector>
    )
})

// Draggable grid card wrapper using gesture handler
type DraggableCardProps = {
    tool: ConverterTool
    index: number
    isDraggedIdx: number | null
    rearranging: boolean
    shakeValue: SharedValue<number>
    offsetX?: SharedValue<number>
    offsetY?: SharedValue<number>
    onPress: () => void
    onLongPress: (absX: number, absY: number) => void
    onPressOut: () => void
    onDragMove: (absX: number, absY: number) => void
    onDragEnd: (absX: number, absY: number) => void
}

const DraggableCard = React.memo(({
    tool,
    index,
    isDraggedIdx,
    rearranging,
    shakeValue,
    offsetX,
    offsetY,
    onPress,
    onLongPress,
    onPressOut,
    onDragMove,
    onDragEnd,
}: DraggableCardProps) => {
    const pos = getPosition(index)
    const isDragged = isDraggedIdx === index
    const activated = useSharedValue(false)

    const longPressGesture = Gesture.LongPress()
        .minDuration(rearranging ? 100 : 300)
        .onStart((e) => {
            activated.value = true
            runOnJS(onLongPress)(e.absoluteX, e.absoluteY)
        })

    const panGesture = Gesture.Pan()
        .activateAfterLongPress(rearranging ? 100 : 300)
        .onUpdate((e) => {
            runOnJS(onDragMove)(e.absoluteX, e.absoluteY)
        })
        .onEnd((e) => {
            activated.value = false
            runOnJS(onDragEnd)(e.absoluteX, e.absoluteY)
        })
        .onFinalize(() => {
            if (!activated.value) return
            activated.value = false
            runOnJS(onPressOut)()
        })

    const composedGesture = Gesture.Simultaneous(longPressGesture, panGesture)

    const direction = index % 2 === 0 ? 1 : -1
    const animStyle = useAnimatedStyle(() => {
        const tx = offsetX ? offsetX.value : 0
        const ty = offsetY ? offsetY.value : 0
        const rotation = rearranging ? shakeValue.value * 2 * direction : 0

        return {
            opacity: isDragged ? 0 : 1,
            zIndex: 1,
            transform: [
                { translateX: tx },
                { translateY: ty },
                { rotate: `${rotation}deg` },
            ] as const,
        }
    })

    return (
        <GestureDetector gesture={composedGesture}>
            <Animated.View
                style={[
                    styles.cardWrapper,
                    {
                        left: pos.x,
                        top: pos.y,
                        width: CELL_SIZE,
                        height: CELL_SIZE,
                    },
                    animStyle,
                ]}
            >
                <ConverterToolCard
                    tool={tool}
                    onPress={rearranging ? undefined : onPress}
                />
            </Animated.View>
        </GestureDetector>
    )
})

const styles = StyleSheet.create({
    container: {
        flex: 1,
        width: "100%",
        backgroundColor: "black",
    },
    innerContainer: {
        flex: 1,
    },
    detailOverlay: {
        ...StyleSheet.absoluteFillObject,
        backgroundColor: "black",
        zIndex: 200,
    },
    scrollContent: {
        flexGrow: 1,
        justifyContent: "center",
        alignItems: "center",
        paddingHorizontal: GRID_PADDING,
    },
    gridContainer: {
        width: COLUMNS * CELL_SIZE,
    },
    cardWrapper: {
        position: "absolute",
    },
    floatingCard: {
        position: "absolute",
        top: 0,
        left: 0,
        zIndex: 100,
    },
    floatingBarIcon: {
        position: "absolute",
        top: 0,
        left: 0,
        zIndex: 100,
        alignItems: "center",
        justifyContent: "center",
        width: INLINE_BAR_ITEM_WIDTH,
        height: INLINE_BAR_ITEM_HEIGHT,
    },
    dismissOverlay: {
        position: "absolute",
        top: -2000,
        bottom: -2000,
        left: -2000,
        right: -2000,
        zIndex: 0,
    },
    inlineBar: {
        flexDirection: "row",
        alignItems: "center",
        justifyContent: "center",
        minHeight: INLINE_BAR_ICON + 16 + 16,
        paddingHorizontal: 4,
        gap: 2,
    },
    inlineBarItem: {
        position: "relative",
        alignItems: "center",
        justifyContent: "center",
        paddingHorizontal: 10,
        paddingVertical: 8,
        borderRadius: 12,
        overflow: "visible",
    },
    barItemAbsolute: {
        position: "absolute" as const,
        top: 0,
    },
    unpinBadge: {
        position: "absolute",
        top: -2,
        right: 0,
        width: 14,
        height: 14,
        borderRadius: 7,
        backgroundColor: "rgba(120,120,120,0.9)",
        alignItems: "center",
        justifyContent: "center",
    },
    dropPreviewBg: {
        ...StyleSheet.absoluteFillObject,
        backgroundColor: "#F69A06",
        borderRadius: 12,
    },
    toast: {
        position: "absolute",
        top: 12,
        alignSelf: "center",
        backgroundColor: "rgba(50,50,50,0.95)",
        paddingHorizontal: 16,
        paddingVertical: 10,
        borderRadius: 10,
        zIndex: 150,
    },
    toastText: {
        color: "#fff",
        fontSize: 14,
        fontWeight: "500",
    },
})
