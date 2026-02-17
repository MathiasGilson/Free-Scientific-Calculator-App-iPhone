import React, { useState, useRef, useCallback, useEffect, useMemo } from "react"
import { View, StyleSheet, ScrollView, Pressable, Dimensions } from "react-native"
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
const NUM_TOOLS = converterTools.length

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

    // Inline bar reorder drag state — all refs to avoid re-renders mid-drag
    const [barDragVersion, setBarDragVersion] = useState(0)
    const barDragKeyRef = useRef<string | null>(null)
    const barDragInsertIdxRef = useRef<number | null>(null)

    useEffect(() => { onRearrangeChangeRef.current = onRearrangeChange }, [onRearrangeChange])
    useEffect(() => { pinnedToolsRef.current = pinnedTools }, [pinnedTools])
    useEffect(() => { onPinnedToolsChangeRef.current = onPinnedToolsChange }, [onPinnedToolsChange])
    useEffect(() => { screenOrderRef.current = screenOrder }, [screenOrder])

    useEffect(() => {
        onDetailChange?.(selectedTool !== null)
    }, [selectedTool, onDetailChange])

    useEffect(() => {
        if (dropTarget) {
            dropPreviewScale.value = withSpring(1, { damping: 12, stiffness: 200 })
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
        dragScale.value = withSpring(1)
        cardOffsets.forEach(o => {
            o.x.value = withSpring(0, { damping: 20, stiffness: 200 })
            o.y.value = withSpring(0, { damping: 20, stiffness: 200 })
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
        dragIdxRef.current = idx
        lastTargetRef.current = idx
        setDragIdx(idx)
        dragAbsX.value = absX - CELL_SIZE / 2
        dragAbsY.value = absY - containerOffsetY.current - CELL_SIZE / 2
        isDragging.value = true
        dragScale.value = withSpring(1.1)
    }, [cardOffsets, dragAbsX, dragAbsY, dragScale, isDragging, startShake])

    // Compute insert index for dropping into the pinned bar
    const computeInsertIndex = useCallback((absX: number): number | null => {
        const bar = inlineBarLayout.current
        if (bar.width === 0) return null

        const pinnedKeysNoCalc = screenOrderRef.current.filter(k => k !== "_calculator")
        const itemCount = pinnedKeysNoCalc.length

        // Calculate where pinned items are rendered in the bar
        const totalItems = screenOrderRef.current.length + 1 // all screenOrder + grid icon
        const totalWidth = totalItems * (INLINE_BAR_ITEM_WIDTH + 2)
        const barStartX = bar.x + (bar.width - totalWidth) / 2

        // Find where pinned items start (after _calculator)
        const calcIdx = screenOrderRef.current.indexOf("_calculator")
        const pinnedStartX = barStartX + (calcIdx + 1) * (INLINE_BAR_ITEM_WIDTH + 2)

        const relX = absX - pinnedStartX
        const idx = Math.round(relX / (INLINE_BAR_ITEM_WIDTH + 2))
        return Math.max(0, Math.min(itemCount, idx))
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
        const overBar = isOverInlineBar(absY) && !pinnedToolsRef.current.includes(draggedKey)

        if (overBar) {
            setDropTarget(draggedKey)
            setDropInsertIndex(computeInsertIndex(absX))
        } else {
            setDropTarget(null)
            setDropInsertIndex(null)
        }

        // Grid reorder logic
        const fromPos = getPosition(fromIdx)
        const gridLeft = (screenWidth - COLUMNS * CELL_SIZE) / 2
        const currentX = absX - gridLeft
        const currentY = absY - containerOffsetY.current

        const col = Math.max(0, Math.min(COLUMNS - 1, Math.floor(currentX / CELL_SIZE)))
        const row = Math.max(0, Math.floor(currentY / CELL_SIZE))
        const count = toolOrderRef.current.length
        const maxRow = Math.ceil(count / COLUMNS) - 1
        const clampedRow = Math.min(maxRow, row)
        const targetIdx = Math.min(count - 1, Math.max(0, clampedRow * COLUMNS + col))
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
                offset.x.value = withSpring(displayPos.x - homePos.x, { damping: 20, stiffness: 200 })
                offset.y.value = withSpring(displayPos.y - homePos.y, { damping: 20, stiffness: 200 })
            }
        }
    }, [dragAbsX, dragAbsY, computeInsertIndex, isOverInlineBar, cardOffsets])

    const handleDragEnd = useCallback((absX: number, absY: number) => {
        const fromIdx = dragIdxRef.current
        if (fromIdx === null) return

        const draggedKey = toolOrderRef.current[fromIdx]
        const overBar = isOverInlineBar(absY) && !pinnedToolsRef.current.includes(draggedKey)

        if (overBar) {
            const insertIdx = computeInsertIndex(absX)
            const currentPinned = pinnedToolsRef.current.slice()
            const idx = insertIdx !== null ? Math.min(insertIdx, currentPinned.length) : currentPinned.length
            currentPinned.splice(idx, 0, draggedKey)
            onPinnedToolsChangeRef.current?.(currentPinned)
        }

        // Reorder grid
        const toIdx = lastTargetRef.current
        const reordered = [...toolOrderRef.current]
        const [item] = reordered.splice(fromIdx, 1)
        reordered.splice(toIdx, 0, item)
        toolOrderRef.current = reordered

        // Reset
        dragIdxRef.current = null
        setDragIdx(null)
        setDropTarget(null)
        setDropInsertIndex(null)
        isDragging.value = false
        dragScale.value = withSpring(1)
        cardOffsets.forEach(o => { o.x.value = 0; o.y.value = 0 })
        setToolOrder(reordered)
        AsyncStorage.setItem(TOOL_ORDER_KEY, JSON.stringify(reordered))
    }, [computeInsertIndex, isOverInlineBar, isDragging, dragScale, cardOffsets])

    const handleCardPressOut = useCallback((idx: number) => {
        setTimeout(() => {
            if (dragIdxRef.current === idx && !isDragging.value) {
                resetDragOnly()
            }
        }, 50)
    }, [resetDragOnly, isDragging])

    const unpinTool = useCallback((key: string) => {
        if (!onPinnedToolsChangeRef.current) return
        const next = pinnedToolsRef.current.filter(k => k !== key)
        onPinnedToolsChangeRef.current(next)
    }, [])

    // Inline bar reorder handlers — stable callbacks using refs
    const handleBarDragStart = useCallback((key: string) => {
        hapticFeedbackSwitch()
        barDragKeyRef.current = key
        barDragInsertIdxRef.current = null
        setBarDragVersion(v => v + 1)
    }, [])

    const handleBarDragMove = useCallback((key: string, absX: number) => {
        const pinned = pinnedToolsRef.current
        const currentIdx = pinned.indexOf(key)
        if (currentIdx < 0) return

        const bar = inlineBarLayout.current
        if (bar.width === 0) return

        const totalItems = screenOrderRef.current.length + 1
        const totalWidth = totalItems * (INLINE_BAR_ITEM_WIDTH + 2)
        const barStartX = bar.x + (bar.width - totalWidth) / 2
        const calcIdx = screenOrderRef.current.indexOf("_calculator")
        const pinnedStartX = barStartX + (calcIdx + 1) * (INLINE_BAR_ITEM_WIDTH + 2)

        const relX = absX - pinnedStartX
        const targetIdx = Math.max(0, Math.min(pinned.length - 1, Math.round(relX / (INLINE_BAR_ITEM_WIDTH + 2))))
        barDragInsertIdxRef.current = targetIdx
    }, [])

    const handleBarDragEnd = useCallback((key: string) => {
        const targetIdx = barDragInsertIdxRef.current
        barDragKeyRef.current = null
        barDragInsertIdxRef.current = null
        setBarDragVersion(v => v + 1)

        if (targetIdx !== null) {
            const pinned = pinnedToolsRef.current.slice()
            const fromIdx = pinned.indexOf(key)
            if (fromIdx >= 0 && fromIdx !== targetIdx) {
                const [item] = pinned.splice(fromIdx, 1)
                pinned.splice(targetIdx, 0, item)
                onPinnedToolsChangeRef.current?.(pinned)
            }
        }
    }, [])

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

    const dropPreviewAnimStyle = useAnimatedStyle(() => ({
        opacity: dropPreviewScale.value,
        transform: [{ scale: dropPreviewScale.value }],
    }))

    const dropPreviewBgStyle = useAnimatedStyle(() => ({
        opacity: 0.15 + pulseValue.value * 0.2,
    }))

    // Swipe-back gesture for detail views
    const detailTranslateX = useSharedValue(0)

    const goBack = useCallback(() => {
        setSelectedTool(null)
        detailTranslateX.value = 0
    }, [detailTranslateX])

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
                    runOnJS(goBack)()
                })
            } else {
                detailTranslateX.value = withSpring(0, { damping: 20, stiffness: 200 })
            }
        })

    const detailAnimStyle = useAnimatedStyle(() => ({
        transform: [{ translateX: detailTranslateX.value }],
    }))

    // Detail views
    if (selectedTool) {
        const detailContent = selectedTool.key === "currency"
            ? <Currency onBack={goBack} />
            : <ConverterDetail tool={selectedTool} onBack={goBack} />

        return (
            <GestureDetector gesture={detailPanGesture}>
                <Animated.View style={[styles.container, detailAnimStyle]}>
                    {detailContent}
                </Animated.View>
            </GestureDetector>
        )
    }

    const rows = Math.ceil(orderedTools.length / COLUMNS)
    const gridHeight = rows * CELL_SIZE

    // Build inline bar items with drop-position-aware preview
    const renderInlineBarItems = () => {
        if (!rearranging) return null

        const items: React.ReactNode[] = []
        const pinnedKeysNoCalc = screenOrder.filter(k => k !== "_calculator")

        // Calculator icon
        items.push(
            <View key="_calculator" style={[styles.inlineBarItem, styles.inlineBarCalc]}>
                <LucideIcon name="calculator" size={INLINE_BAR_ICON} color="#ccc" />
            </View>
        )

        // Pinned items with insertion point for drop preview
        pinnedKeysNoCalc.forEach((key, i) => {
            // Insert drop preview before this item if this is the insert position
            if (dropTarget && dropInsertIndex === i) {
                items.push(
                    <Animated.View
                        key="__drop_preview"
                        style={[styles.inlineBarItem, dropPreviewAnimStyle]}
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
                    onDragStart={handleBarDragStart}
                    onDragMove={handleBarDragMove}
                    onDragEnd={handleBarDragEnd}
                    onUnpin={unpinTool}
                />
            )
        })

        // Insert drop preview at end if insert index is past all items
        if (dropTarget && (dropInsertIndex === null || dropInsertIndex >= pinnedKeysNoCalc.length)) {
            items.push(
                <Animated.View
                    key="__drop_preview"
                    style={[styles.inlineBarItem, dropPreviewAnimStyle]}
                >
                    <Animated.View style={[styles.dropPreviewBg, dropPreviewBgStyle]} />
                    <LucideIcon name={iconForKey(dropTarget)} size={INLINE_BAR_ICON} color="#F69A06" />
                </Animated.View>
            )
        }

        // Grid icon (active)
        items.push(
            <View key="__grid" style={[styles.inlineBarItem, styles.inlineBarActive]}>
                <LucideIcon name="layout-grid" size={INLINE_BAR_ICON} color="#F69A06" />
            </View>
        )

        return items
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
                                onPress={() => setSelectedTool(tool)}
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
            </View>
        </SafeAreaView>
    )
}

// Draggable inline bar item for reordering pinned tools
type DraggableBarItemProps = {
    itemKey: string
    onDragStart: (key: string) => void
    onDragMove: (key: string, absX: number) => void
    onDragEnd: (key: string) => void
    onUnpin: (key: string) => void
}

const DraggableBarItem = React.memo(({ itemKey, onDragStart, onDragMove, onDragEnd, onUnpin }: DraggableBarItemProps) => {
    const translateX = useSharedValue(0)
    const translateY = useSharedValue(0)
    const scale = useSharedValue(1)
    const isDragging = useSharedValue(false)

    // Keep callbacks in refs so gesture closures always call latest versions
    const onDragStartRef = useRef(onDragStart)
    const onDragMoveRef = useRef(onDragMove)
    const onDragEndRef = useRef(onDragEnd)
    onDragStartRef.current = onDragStart
    onDragMoveRef.current = onDragMove
    onDragEndRef.current = onDragEnd

    const callDragStart = useCallback((key: string) => onDragStartRef.current(key), [])
    const callDragMove = useCallback((key: string, absX: number) => onDragMoveRef.current(key, absX), [])
    const callDragEnd = useCallback((key: string) => onDragEndRef.current(key), [])

    const panGesture = Gesture.Pan()
        .activateAfterLongPress(200)
        .onStart(() => {
            isDragging.value = true
            scale.value = withSpring(1.2)
            runOnJS(callDragStart)(itemKey)
        })
        .onUpdate((e) => {
            translateX.value = e.translationX
            translateY.value = e.translationY
            runOnJS(callDragMove)(itemKey, e.absoluteX)
        })
        .onEnd(() => {
            isDragging.value = false
            translateX.value = withSpring(0)
            translateY.value = withSpring(0)
            scale.value = withSpring(1)
            runOnJS(callDragEnd)(itemKey)
        })
        .onFinalize(() => {
            isDragging.value = false
            translateX.value = withSpring(0)
            translateY.value = withSpring(0)
            scale.value = withSpring(1)
        })

    const animStyle = useAnimatedStyle(() => {
        return {
            transform: [
                { translateX: translateX.value },
                { translateY: translateY.value },
                { scale: scale.value },
            ] as const,
            zIndex: isDragging.value ? 10 : 1,
        }
    })

    return (
        <GestureDetector gesture={panGesture}>
            <Animated.View style={[styles.inlineBarItem, animStyle]}>
                <LucideIcon name={iconForKey(itemKey)} size={INLINE_BAR_ICON} color="#999" />
                <Pressable style={styles.unpinBadge} onPress={() => onUnpin(itemKey)} hitSlop={6}>
                    <LucideIcon name="x" size={8} color="#fff" />
                </Pressable>
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
    inlineBarCalc: {
        opacity: 0.6,
    },
    inlineBarActive: {
        backgroundColor: "rgba(246, 154, 6, 0.15)",
        borderWidth: 1,
        borderColor: "rgba(246, 154, 6, 0.4)",
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
})
