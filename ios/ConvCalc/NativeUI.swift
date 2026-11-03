import LucideSwift
import SwiftUI
import UIKit

private struct AppIcon: View {
    let name: String
    var size: CGFloat = 24
    var color: Color? = nil
    var filled: Bool = false
    var strokeWidth: CGFloat = 2

    var body: some View {
        LucideIcon(
            name: name,
            style: filled ? .filled : .stroked,
            size: size,
            color: color,
            strokeWidth: strokeWidth
        )
    }
}

private enum AppColor {
    static let background = Color.black
    static let accent = Color(red: 0.96, green: 0.60, blue: 0.02)
}

private let toolPageAnimation = Animation.interactiveSpring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.02)
private let toolPageTransition = AnyTransition.asymmetric(
    insertion: .move(edge: .trailing),
    removal: .move(edge: .trailing)
)

private extension View {
    @ViewBuilder
    func appGlass(cornerRadius: CGFloat, tint: Color? = nil, interactive: Bool = false, fallbackOpacity: Double = 0.16) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            self
                .glassEffect(appGlassStyle(tint: tint, interactive: interactive), in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.12), lineWidth: 0.8))
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .background(shape.fill((tint ?? Color.white).opacity(fallbackOpacity)))
                .overlay(shape.stroke(Color.white.opacity(0.14), lineWidth: 0.8))
        }
    }

    @ViewBuilder
    func appGlassCircle(tint: Color? = nil, interactive: Bool = false, fallbackOpacity: Double = 0.16) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(appGlassStyle(tint: tint, interactive: interactive), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.8))
        } else {
            self
                .background(.ultraThinMaterial, in: Circle())
                .background(Circle().fill((tint ?? Color.white).opacity(fallbackOpacity)))
                .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 0.8))
        }
    }

    @ViewBuilder
    func appGlassWhen(_ condition: Bool, cornerRadius: CGFloat, tint: Color? = nil, interactive: Bool = false, fallbackOpacity: Double = 0.16) -> some View {
        if condition {
            self.appGlass(cornerRadius: cornerRadius, tint: tint, interactive: interactive, fallbackOpacity: fallbackOpacity)
        } else {
            self
        }
    }
}

@available(iOS 26.0, *)
private func appGlassStyle(tint: Color?, interactive: Bool) -> Glass {
    let glass = tint.map { Glass.regular.tint($0) } ?? Glass.regular
    return glass.interactive(interactive)
}

struct CalculationEntry: Codable, Identifiable, Equatable {
    let expression: String
    let result: String
    let timestamp: Date

    var id: String { "\(timestamp.timeIntervalSince1970)-\(expression)-\(result)" }

    /// `result` is locale-independent so that it can be loaded back into the calculator.
    var displayResult: String {
        Double(result).map { CalculatorNumberFormat.display($0) } ?? result
    }
}

final class CalculationHistoryStore: ObservableObject {
    @Published private(set) var entries: [CalculationEntry] = []

    private let defaults: UserDefaults
    private let key: String
    private let maxEntries = 100

    init(userDefaults: UserDefaults = .standard, key: String = "calculationHistory") {
        self.defaults = userDefaults
        self.key = key
        load()
    }

    func save(expression: String, result: String) {
        let entry = CalculationEntry(expression: expression, result: result, timestamp: Date())
        entries = Array(([entry] + entries).prefix(maxEntries))
        persist()
    }

    func clear() {
        entries = []
        defaults.removeObject(forKey: key)
    }

    private func load() {
        guard
            let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode([CalculationEntry].self, from: data)
        else {
            entries = []
            return
        }
        entries = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}

final class ConvCalcAppState: ObservableObject {
    static let maxPinnedTools = 5

    @Published var screenOrder: [String] {
        didSet { saveScreenOrder() }
    }
    @Published var toolOrder: [String] {
        didSet { saveToolOrder() }
    }
    @Published var isRearrangingTools = false
    @Published var draggedToolKey: String?

    var allowsToolOpening: Bool {
        !isRearrangingTools
    }

    func beginRearrangingTools() {
        isRearrangingTools = true
    }

    func endRearrangingTools() {
        isRearrangingTools = false
        draggedToolKey = nil
    }

    private let defaults: UserDefaults
    private let key: String
    private let toolOrderKey: String

    init(userDefaults: UserDefaults = .standard, key: String = "pinnedConverterTools", toolOrderKey: String = "converterToolOrder") {
        self.defaults = userDefaults
        self.key = key
        self.toolOrderKey = toolOrderKey
        if
            let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode([String].self, from: data),
            !decoded.isEmpty
        {
            screenOrder = Self.sanitizeScreenOrder(decoded)
        } else {
            screenOrder = ["_calculator", "currency"]
        }

        if
            let data = defaults.data(forKey: toolOrderKey),
            let decoded = try? JSONDecoder().decode([String].self, from: data)
        {
            toolOrder = Self.normalizedToolOrder(decoded)
        } else {
            toolOrder = Self.defaultToolOrder
        }
    }

    var pinnedToolKeys: [String] {
        screenOrder.filter { $0 != "_calculator" && $0 != "_converter" }
    }

    var canPinMoreTools: Bool {
        pinnedToolKeys.count < Self.maxPinnedTools
    }

    func isToolPinned(_ key: String) -> Bool {
        key != "_calculator" && pinnedToolKeys.contains(key)
    }

    var orderedTools: [ConverterTool] {
        let toolsByKey = Dictionary(uniqueKeysWithValues: ConverterTool.all.map { ($0.key, $0) })
        return Self.normalizedToolOrder(toolOrder).compactMap { toolsByKey[$0] }
    }

    func setPinnedToolKeys(_ keys: [String]) {
        // The calculator tab can be dragged too, so pinning must not reset its position.
        var order = keys
        order.insert("_calculator", at: min(screenOrder.firstIndex(of: "_calculator") ?? 0, keys.count))
        screenOrder = Self.sanitizeScreenOrder(order)
    }

    private static func sanitizeScreenOrder(_ order: [String]) -> [String] {
        var seen: Set<String> = []
        let tabs = order.filter { key in
            guard key != "_converter", !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
        return tabs.contains("_calculator") ? tabs : ["_calculator"] + tabs
    }

    func pin(_ key: String) -> Bool {
        guard key != "_calculator", !isToolPinned(key), canPinMoreTools else {
            return false
        }
        setPinnedToolKeys(pinnedToolKeys + [key])
        return true
    }

    func unpin(_ key: String) {
        guard isToolPinned(key) else { return }
        var keys = pinnedToolKeys
        keys.removeAll { $0 == key }
        setPinnedToolKeys(keys)
    }

    func moveTool(_ sourceKey: String, to destinationIndex: Int) {
        var order = Self.normalizedToolOrder(toolOrder)
        guard let sourceIndex = order.firstIndex(of: sourceKey) else { return }

        let clampedIndex = min(max(destinationIndex, 0), order.count - 1)
        guard clampedIndex != sourceIndex else { return }

        let moving = order.remove(at: sourceIndex)
        order.insert(moving, at: min(clampedIndex, order.count))
        toolOrder = order
    }

    @discardableResult
    func reorderToolbarTab(_ sourceKey: String, before targetKey: String) -> Bool {
        guard sourceKey != targetKey, sourceKey != "_converter" else { return false }

        if screenOrder.contains(sourceKey) {
            var order = screenOrder
            guard let sourceIndex = order.firstIndex(of: sourceKey) else { return false }
            order.remove(at: sourceIndex)

            let destinationIndex: Int
            if targetKey == "_converter" {
                destinationIndex = order.count
            } else if let targetIndex = order.firstIndex(of: targetKey) {
                destinationIndex = targetIndex
            } else {
                return false
            }

            order.insert(sourceKey, at: min(destinationIndex, order.count))
            screenOrder = order
            return true
        }

        return placePinnedTool(sourceKey, before: targetKey)
    }

    func moveToolbarTab(_ sourceKey: String, to destinationIndex: Int) {
        guard sourceKey != "_converter" else { return }

        var tabs = screenOrder + ["_converter"]
        guard let sourceIndex = tabs.firstIndex(of: sourceKey) else { return }

        tabs.remove(at: sourceIndex)
        let converterIndex = tabs.firstIndex(of: "_converter") ?? tabs.count
        let clampedIndex = min(max(destinationIndex, 0), converterIndex)
        tabs.insert(sourceKey, at: min(clampedIndex, tabs.count))

        if tabs.last == "_converter" {
            tabs.removeLast()
        }
        // Called on every drag update; only a real move should re-render and persist.
        guard tabs != screenOrder else { return }
        screenOrder = tabs
    }

    @discardableResult
    func placePinnedTool(_ sourceKey: String, before targetKey: String) -> Bool {
        guard sourceKey != "_calculator", sourceKey != "_converter" else { return false }
        guard ConverterTool.all.contains(where: { $0.key == sourceKey }) else { return false }

        var keys = pinnedToolKeys
        if let existingIndex = keys.firstIndex(of: sourceKey) {
            keys.remove(at: existingIndex)
        } else if keys.count >= Self.maxPinnedTools {
            return false
        }

        let destinationIndex: Int
        if targetKey == "_calculator" {
            destinationIndex = 0
        } else if targetKey == "_converter" {
            destinationIndex = keys.count
        } else if let targetIndex = keys.firstIndex(of: targetKey) {
            destinationIndex = targetIndex
        } else {
            destinationIndex = keys.count
        }

        keys.insert(sourceKey, at: destinationIndex)
        setPinnedToolKeys(keys)
        return true
    }

    private func saveScreenOrder() {
        guard let data = try? JSONEncoder().encode(screenOrder) else { return }
        defaults.set(data, forKey: key)
    }

    private func saveToolOrder() {
        guard let data = try? JSONEncoder().encode(Self.normalizedToolOrder(toolOrder)) else { return }
        defaults.set(data, forKey: toolOrderKey)
    }

    private static var defaultToolOrder: [String] {
        ConverterTool.all.map(\.key)
    }

    private static func normalizedToolOrder(_ keys: [String]) -> [String] {
        let validKeys = defaultToolOrder
        var seen: Set<String> = []
        let existing = keys.filter { key in
            guard validKeys.contains(key), !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
        return existing + validKeys.filter { !seen.contains($0) }
    }
}

struct RootView: View {
    @EnvironmentObject private var historyStore: CalculationHistoryStore
    @EnvironmentObject private var appState: ConvCalcAppState
    @StateObject private var calculatorModel = CalculatorViewModel()
    @State private var pageIndex = 0
    @State private var historyVisible = false
    @State private var toolbarVisibleDuringSwipe = false
    @State private var toolbarHideToken = 0
    @State private var activeGridTool: ConverterTool?
    private let debugRoute = DebugRoute.current

    var body: some View {
        Group {
            if let debugRoute {
                DebugRouteView(route: debugRoute)
            } else {
                mainPager
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mainPager: some View {
        ZStack(alignment: .top) {
            AppColor.background.ignoresSafeArea()

            TabView(selection: $pageIndex) {
                ForEach(Array(appState.screenOrder.enumerated()), id: \.element) { offset, key in
                    pagerScreen(for: key)
                        .tag(offset)
                }

                ConverterGridScreen(onOpenTool: openGridTool)
                    .tag(appState.screenOrder.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)
            .accessibilityHidden(activeGridTool != nil)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        guard isHorizontalPagingDrag(value.translation) else { return }
                        showToolbarForPaging()
                    }
                    .onEnded { value in
                        guard isHorizontalPagingDrag(value.translation) else { return }
                        hideToolbarAfterPagingDelay()
                    }
            )
            .onChange(of: pageIndex) { _ in
                if pageIndex != converterPageIndex, !appState.isRearrangingTools {
                    appState.draggedToolKey = nil
                    activeGridTool = nil
                } else if pageIndex != converterPageIndex {
                    appState.draggedToolKey = nil
                    appState.endRearrangingTools()
                }
                showToolbarBriefly()
            }
            // The grid is the last tab, so its index == screenOrder.count.
            // Pinning/unpinning while editing mutates screenOrder and shifts
            // that index; without re-syncing, the selection would land on the
            // newly pinned tool's page. Keep the user on the grid while editing.
            .onChange(of: appState.screenOrder) { _ in
                if appState.isRearrangingTools {
                    pageIndex = converterPageIndex
                }
            }

            if shouldShowPinnedTabBar {
                PinnedTabBar(pageIndex: pageIndex)
                    .padding(.top, 6)
                    .transition(.opacity)
                    .zIndex(appState.isRearrangingTools ? 50 : tabBarZIndex)
            }

            if let activeGridTool {
                ToolDetailPage(tool: activeGridTool, onClose: closeGridTool)
                    .transition(toolPageTransition)
                    .zIndex(20)
            }
        }
        .onAppear {
            pageIndex = appState.screenOrder.firstIndex(of: "_calculator") ?? 0
        }
        .sheet(isPresented: $historyVisible) {
            HistorySheet(
                onSelect: { expression in
                    calculatorModel.setExpression(expression)
                    historyVisible = false
                    pageIndex = appState.screenOrder.firstIndex(of: "_calculator") ?? 0
                },
                onClose: { historyVisible = false }
            )
            .environmentObject(historyStore)
        }
    }

    private var converterPageIndex: Int {
        appState.screenOrder.count
    }

    private var tabBarZIndex: Double {
        if appState.isRearrangingTools { return 50 }
        if pageIndex == converterPageIndex { return 10 }
        return 0
    }

    @ViewBuilder
    private func pagerScreen(for key: String) -> some View {
        if key == "_calculator" {
            CalculatorScreen(model: calculatorModel) {
                historyVisible = true
            }
        } else {
            PinnedToolScreen(toolKey: key)
        }
    }

    private var shouldShowPinnedTabBar: Bool {
        activeGridTool == nil && (appState.isRearrangingTools || pageIndex == converterPageIndex || toolbarVisibleDuringSwipe)
    }

    private func openGridTool(_ tool: ConverterTool) {
        guard appState.allowsToolOpening else { return }
        appState.endRearrangingTools()
        withAnimation(toolPageAnimation) {
            activeGridTool = tool
        }
    }

    private func closeGridTool() {
        withAnimation(toolPageAnimation) {
            activeGridTool = nil
        }
    }

    private func showToolbarForPaging() {
        toolbarHideToken += 1
        guard !toolbarVisibleDuringSwipe else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            toolbarVisibleDuringSwipe = true
        }
    }

    private func showToolbarBriefly() {
        showToolbarForPaging()
        hideToolbarAfterPagingDelay()
    }

    private func hideToolbarAfterPagingDelay() {
        toolbarHideToken += 1
        let token = toolbarHideToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard toolbarHideToken == token else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                toolbarVisibleDuringSwipe = false
            }
        }
    }

    private func isHorizontalPagingDrag(_ translation: CGSize) -> Bool {
        let horizontalDistance = abs(translation.width)
        let verticalDistance = abs(translation.height)
        return horizontalDistance > 18 && horizontalDistance > verticalDistance * 1.25
    }
}

private enum DebugRoute: Equatable {
    case calculator
    case calculatorInput
    case calculatorExpanded
    case calculatorExpression(String)
    case history
    case historyEmpty
    case currency
    case currencyPicker
    case converterGrid
    case converterGridRearranging
    case tool(String)

    static var current: DebugRoute? {
        guard let raw = ProcessInfo.processInfo.environment["CONVCALC_DEBUG_ROUTE"] else { return nil }
        if raw == "calculator" { return .calculator }
        if raw == "calculatorInput" { return .calculatorInput }
        if raw == "calculatorExpanded" { return .calculatorExpanded }
        if raw == "history" { return .history }
        if raw == "historyEmpty" { return .historyEmpty }
        if raw == "currency" { return .currency }
        if raw == "currencyPicker" { return .currencyPicker }
        if raw == "converterGrid" { return .converterGrid }
        if raw == "converterGridRearranging" { return .converterGridRearranging }
        if raw.hasPrefix("expression:") {
            return .calculatorExpression(String(raw.dropFirst("expression:".count)))
        }
        if raw.hasPrefix("tool:") {
            return .tool(String(raw.dropFirst("tool:".count)))
        }
        return nil
    }
}

private struct DebugRouteView: View {
    @EnvironmentObject private var historyStore: CalculationHistoryStore
    let route: DebugRoute
    @StateObject private var calculatorModel = CalculatorViewModel()
    @State private var showHistory = false

    var body: some View {
        Group {
            switch route {
            case .calculator:
                CalculatorScreen(model: calculatorModel) {
                    showHistory = true
                }
            case .calculatorInput:
                CalculatorScreen(model: calculatorModel) {
                    showHistory = true
                }
                .onAppear {
                    calculatorModel.setExpression("2+3*4")
                }
            case .calculatorExpanded:
                CalculatorScreen(model: calculatorModel) {
                    showHistory = true
                }
                .onAppear {
                    calculatorModel.expanded = true
                    calculatorModel.angleMode = .degrees
                }
            case .calculatorExpression(let expression):
                CalculatorScreen(model: calculatorModel) {
                    showHistory = true
                }
                .onAppear {
                    calculatorModel.setExpression(expression)
                }
            case .history:
                HistorySheet(onSelect: { _ in }, onClose: {})
                    .onAppear {
                        historyStore.clear()
                        historyStore.save(expression: "2+3*4", result: "14")
                        historyStore.save(expression: "sin(90)", result: "1")
                    }
            case .historyEmpty:
                HistorySheet(onSelect: { _ in }, onClose: {})
                    .onAppear {
                        historyStore.clear()
                    }
            case .currency:
                CurrencyScreen(onBack: nil)
            case .currencyPicker:
                CurrencyScreen(onBack: nil, initialPickerVisible: true)
            case .converterGrid:
                DebugConverterGridPreview(initialRearranging: false)
            case .converterGridRearranging:
                DebugConverterGridPreview(initialRearranging: true)
            case .tool(let key):
                if key == "currency" {
                    CurrencyScreen(onBack: {})
                } else if let tool = ConverterTool.all.first(where: { $0.key == key }) {
                    ConverterDetailScreen(tool: tool, onBack: {})
                } else {
                    ConverterGridScreen()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.ignoresSafeArea(edges: .bottom))
        .sheet(isPresented: $showHistory) {
            HistorySheet(onSelect: { _ in }, onClose: { showHistory = false })
        }
    }
}

private struct DebugConverterGridPreview: View {
    @EnvironmentObject private var appState: ConvCalcAppState
    @State private var activeTool: ConverterTool?
    let initialRearranging: Bool

    var body: some View {
        ZStack(alignment: .top) {
            ConverterGridScreen(initialRearranging: initialRearranging, onOpenTool: openTool)

            if activeTool == nil {
                PinnedTabBar(pageIndex: appState.screenOrder.count)
                    .padding(.top, 6)
            }

            if let activeTool {
                ToolDetailPage(tool: activeTool, onClose: closeTool)
                    .transition(toolPageTransition)
                    .zIndex(20)
            }
        }
    }

    private func openTool(_ tool: ConverterTool) {
        guard appState.allowsToolOpening else { return }
        appState.endRearrangingTools()
        withAnimation(toolPageAnimation) {
            activeTool = tool
        }
    }

    private func closeTool() {
        withAnimation(toolPageAnimation) {
            activeTool = nil
        }
    }
}

struct PinnedTabBar: View {
    @EnvironmentObject private var appState: ConvCalcAppState
    let pageIndex: Int

    @State private var activeTabKey: String?
    @State private var dragLocation = CGPoint.zero
    @State private var fingerOffset = CGSize.zero

    private static let coordinateSpace = "pinnedTabBar"
    private static let iconWidth: CGFloat = 40
    private static let barHeight: CGFloat = 36

    var body: some View {
        let tabs = appState.screenOrder + ["_converter"]

        Group {
            if appState.isRearrangingTools {
                reorderableBar(tabs: tabs)
            } else {
                staticBar(tabs: tabs)
            }
        }
        .padding(.horizontal, 6)
        .appGlass(cornerRadius: 18, tint: Color.white.opacity(0.04), fallbackOpacity: 0.08)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onLongPressGesture(minimumDuration: 0.42, maximumDistance: 24) {
            // The bar also flashes while paging, but only the grid can exit rearranging.
            guard pageIndex == appState.screenOrder.count else { return }
            impact(.heavy)
            appState.beginRearrangingTools()
        }
        .onChange(of: appState.isRearrangingTools) { isRearranging in
            if !isRearranging {
                finishDrag()
            }
        }
    }

    private func staticBar(tabs: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, key in
                tabIcon(key: key, index: index)
            }
        }
    }

    private func reorderableBar(tabs: [String]) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, key in
                let isActive = activeTabKey == key
                tabIcon(key: key, index: index)
                    .position(position(for: index, isActive: isActive))
                    .shadow(color: isActive ? Color.black.opacity(0.35) : .clear, radius: 12, x: 0, y: 8)
                    .zIndex(isActive ? 10 : 1)
                    .animation(isActive ? nil : .interactiveSpring(response: 0.22, dampingFraction: 0.84), value: tabs)
                    .simultaneousGesture(dragGesture(for: key, at: index, tabs: tabs))
            }
        }
        .frame(width: barWidth(tabCount: tabs.count), height: Self.barHeight)
        .coordinateSpace(name: Self.coordinateSpace)
    }

    private func tabIcon(key: String, index: Int) -> some View {
        PinnedTabIcon(
            key: key,
            symbolName: symbolName(for: key),
            selected: index == pageIndex,
            rearranging: appState.isRearrangingTools
        )
        .frame(width: Self.iconWidth, height: Self.barHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityName(for: key))
        .accessibilityValue(index == pageIndex ? "Selected" : "")
    }

    private func symbolName(for key: String) -> String {
        if key == "_calculator" { return "calculator" }
        if key == "_converter" { return "grid3X3" }
        return ConverterTool.all.first(where: { $0.key == key })?.symbolName ?? "bookmark"
    }

    private func accessibilityName(for key: String) -> String {
        if key == "_calculator" { return "Calculator tab" }
        if key == "_converter" { return "All tools tab" }
        return "\(ConverterTool.all.first(where: { $0.key == key })?.label ?? key) tab"
    }

    private func canDrag(_ key: String) -> Bool {
        key != "_converter"
    }

    private func barWidth(tabCount: Int) -> CGFloat {
        CGFloat(tabCount) * Self.iconWidth
    }

    private func dragGesture(for key: String, at index: Int, tabs: [String]) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.coordinateSpace))
            .onChanged { value in
                guard appState.isRearrangingTools, canDrag(key) else { return }
                if activeTabKey != key {
                    beginDrag(key: key, at: index, drag: value)
                }
                updateDrag(value, tabs: tabs)
            }
            .onEnded { _ in
                guard appState.isRearrangingTools else { return }
                finishDrag()
            }
    }

    private func beginDrag(key: String, at index: Int, drag: DragGesture.Value) {
        appState.draggedToolKey = key
        activeTabKey = key

        let center = slotCenter(for: index)
        fingerOffset = CGSize(
            width: drag.startLocation.x - center.x,
            height: drag.startLocation.y - center.y
        )
        dragLocation = drag.location
    }

    private func updateDrag(_ drag: DragGesture.Value, tabs: [String]) {
        dragLocation = drag.location
        guard let activeTabKey else { return }

        let targetIndex = tabIndex(for: activeCenter().x, tabCount: tabs.count)
        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.84)) {
            appState.moveToolbarTab(activeTabKey, to: targetIndex)
        }
    }

    private func finishDrag() {
        activeTabKey = nil
        appState.draggedToolKey = nil
        dragLocation = .zero
        fingerOffset = .zero
    }

    private func position(for index: Int, isActive: Bool) -> CGPoint {
        isActive ? activeCenter() : slotCenter(for: index)
    }

    private func activeCenter() -> CGPoint {
        CGPoint(
            x: dragLocation.x - fingerOffset.width,
            y: dragLocation.y - fingerOffset.height
        )
    }

    private func slotCenter(for index: Int) -> CGPoint {
        CGPoint(
            x: Self.iconWidth / 2 + CGFloat(index) * Self.iconWidth,
            y: Self.barHeight / 2
        )
    }

    private func tabIndex(for centerX: CGFloat, tabCount: Int) -> Int {
        let rawIndex = Int(round((centerX - Self.iconWidth / 2) / Self.iconWidth))
        let converterIndex = tabCount - 1
        return min(max(rawIndex, 0), converterIndex)
    }
}

private struct PinnedTabIcon: View {
    let key: String
    let symbolName: String
    let selected: Bool
    let rearranging: Bool

    var body: some View {
        AppIcon(name: symbolName, size: 19, color: selected ? .white : Color(red: 0.33, green: 0.33, blue: 0.33))
            .frame(width: 40, height: 36)
            .reorderShake(rearranging && key != "_converter")
            .contentShape(Rectangle())
    }
}

private struct ReorderShakeModifier: ViewModifier {
    let active: Bool
    @State private var shakeStart = Date()

    @ViewBuilder
    func body(content: Content) -> some View {
        if active {
            TimelineView(.animation) { timeline in
                content
                    .rotationEffect(.degrees(angle(at: timeline.date)))
                    .transaction { transaction in
                        transaction.animation = nil
                    }
            }
            .onAppear {
                shakeStart = Date()
            }
        } else {
            content
                .rotationEffect(.degrees(0))
                .transaction { transaction in
                    transaction.animation = nil
                }
        }
    }

    private func angle(at date: Date) -> Double {
        let cycleDuration = 0.38
        let elapsed = date.timeIntervalSince(shakeStart)
        return sin(elapsed * 2 * Double.pi / cycleDuration) * 3.0
    }
}

private extension View {
    func reorderShake(_ active: Bool) -> some View {
        modifier(ReorderShakeModifier(active: active))
    }
}

// MARK: - Calculator

final class CalculatorViewModel: ObservableObject {
    @Published private(set) var expression = ""
    @Published var sessionHistory: [String] = []
    @Published var selectedChunkIndex: Int?
    @Published var tempResult = ""
    @Published var error = ""
    @Published var expanded = false
    @Published var inverted = false
    @Published var hyperbolic = false
    @Published var angleMode: AngleMode = .degrees {
        didSet { computeTempResult() }
    }

    private var reducer = CalculatorInputReducer()
    private var isEditingChunk = false

    var engine: CalculatorEngine {
        CalculatorEngine(angleMode: angleMode)
    }

    func setExpression(_ value: String) {
        reducer.replace(with: value)
        expression = reducer.expression
        selectedChunkIndex = nil
        error = ""
        computeTempResult()
    }

    func press(_ value: String) {
        error = ""
        if let selectedChunkIndex {
            editSelectedChunk(with: value, at: selectedChunkIndex)
        } else {
            reducer.append(value)
        }
        syncExpression()
    }

    /// For values that begin a new number, such as 1/x, rather than extending the current one.
    func pressFactor(_ value: String) {
        error = ""
        selectedChunkIndex = nil
        reducer.appendFactor(value)
        syncExpression()
    }

    func decimalPoint() {
        error = ""
        if let selectedChunkIndex {
            var chunks = splitExpression(expression)
            guard chunks.indices.contains(selectedChunkIndex) else { return }
            if Self.isOperatorChunk(chunks[selectedChunkIndex]) {
                self.selectedChunkIndex = nil
                reducer.appendDecimalPoint()
            } else {
                chunks[selectedChunkIndex] = isEditingChunk ? "0." : CalculatorInputReducer.addingDecimalPoint(to: chunks[selectedChunkIndex])
                isEditingChunk = false
                reducer.replace(with: chunks.joined())
            }
        } else {
            reducer.appendDecimalPoint()
        }
        syncExpression()
    }

    func nextParenthesis() {
        error = ""
        reducer.appendNextParenthesis()
        syncExpression()
    }

    func random() {
        pressFactor(String(format: "%.5f", Double.random(in: 0..<1)))
    }

    func clear() {
        impact(.heavy)
        let wasEmpty = expression.isEmpty
        reducer.clear()
        expression = ""
        tempResult = ""
        error = ""
        if wasEmpty {
            sessionHistory = []
        }
        selectedChunkIndex = nil
    }

    func backspace() {
        impact(.light)
        if let selectedChunkIndex {
            var chunks = splitExpression(expression)
            guard chunks.indices.contains(selectedChunkIndex) else { return }
            chunks[selectedChunkIndex] = CalculatorInputReducer.removingLastToken(from: chunks[selectedChunkIndex])
            reducer.replace(with: chunks.joined())
            // An emptied chunk disappears, which would shift the selection onto its neighbor.
            if chunks[selectedChunkIndex].isEmpty {
                self.selectedChunkIndex = nil
            }
        } else {
            reducer.backspace()
        }
        syncExpression()
    }

    func calculate(historyStore: CalculationHistoryStore) {
        guard !expression.isEmpty else { return }
        do {
            let result = try engine.evaluate(expression)
            let resultValue = CalculatorNumberFormat.expressionValue(result)
            // Pressing = again on a lone result has nothing new to record.
            guard resultValue != expression else { return }
            let parsedResult = "\(expression) = \(CalculatorNumberFormat.display(result))"
            if sessionHistory.last != parsedResult {
                sessionHistory.append(parsedResult)
            }
            historyStore.save(expression: expression, result: resultValue)
            reducer.replace(with: resultValue)
            selectedChunkIndex = nil
            isEditingChunk = false
            syncExpression()
        } catch {
            self.error = "Invalid input"
        }
    }

    func selectChunk(_ index: Int) {
        if selectedChunkIndex == index {
            selectedChunkIndex = nil
            isEditingChunk = false
        } else {
            selectedChunkIndex = index
            isEditingChunk = true
        }
    }

    func copyChunk(_ chunk: String) {
        success()
        UIPasteboard.general.string = chunk
    }

    func pasteClipboard() {
        guard let string = UIPasteboard.general.string else { return }
        let pasted = CalculatorNumberFormat.normalizedPaste(string)
        // The clipboard can hold anything; only an expression belongs on the display.
        guard (try? CalculatorEngine().evaluate(pasted)) != nil else { return }
        error = ""
        reducer.replace(with: pasted)
        syncExpression()
    }

    func formattedChunks() -> [String] {
        splitExpression(expression)
    }

    func formatChunk(_ chunk: String) -> String {
        if chunk == "*" { return "×" }
        if chunk == "/" { return "÷" }
        if chunk.contains("E"), let value = Double(chunk) {
            return CalculatorNumberFormat.display(value)
        }
        return CalculatorNumberFormat.typedNumber(chunk)
    }

    func formatResult(_ result: String) -> String {
        Double(result).map { CalculatorNumberFormat.display($0) } ?? result
    }

    private func syncExpression() {
        expression = reducer.expression
        computeTempResult()
    }

    private func computeTempResult() {
        guard !expression.isEmpty else {
            tempResult = ""
            return
        }
        tempResult = ((try? engine.evaluate(expression)).map(CalculatorNumberFormat.expressionValue)) ?? ""
    }

    private func editSelectedChunk(with value: String, at index: Int) {
        var chunks = splitExpression(expression)
        guard chunks.indices.contains(index) else {
            selectedChunkIndex = nil
            reducer.append(value)
            return
        }

        if Self.isOperatorChunk(chunks[index]) {
            // A selected operator can be swapped for another, but typing a digit over it
            // would merge the numbers on either side.
            selectedChunkIndex = nil
            if Self.isOperatorChunk(value) {
                chunks[index] = value
                reducer.replace(with: chunks.joined())
            } else {
                reducer.append(value)
            }
        } else if value.range(of: #"^[0-9.,]$"#, options: .regularExpression) != nil {
            if isEditingChunk {
                chunks[index] = value
                isEditingChunk = false
            } else {
                chunks[index] += value
            }
            reducer.replace(with: chunks.joined())
        } else {
            selectedChunkIndex = nil
            reducer.append(value)
        }
    }

    private static func isOperatorChunk(_ chunk: String) -> Bool {
        ["+", "-", "*", "/"].contains(chunk)
    }

    private func splitExpression(_ text: String) -> [String] {
        var chunks: [String] = []
        var current = ""
        for character in text {
            // The sign of a scientific exponent such as 1E+20 belongs to its number.
            if "+-*/".contains(character), current.last != "E" {
                if !current.isEmpty {
                    chunks.append(current)
                    current = ""
                }
                chunks.append(String(character))
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}

private enum CalculatorButtonTheme {
    case number
    case primary
    case secondary
    case equal
    case expand
}

private struct CalculatorButtonDefinition: Identifiable {
    let id: String
    let label: String
    let value: String
    let theme: CalculatorButtonTheme
    let expandedOnly: Bool
    let action: CalculatorAction?

    init(label: String? = nil, value: String, theme: CalculatorButtonTheme, expandedOnly: Bool = false, action: CalculatorAction? = nil) {
        self.id = "\(value)-\(label ?? value)-\(expandedOnly)"
        self.label = label ?? value
        self.value = value
        self.theme = theme
        self.expandedOnly = expandedOnly
        self.action = action
    }
}

private enum CalculatorAction {
    case clear
    case calculate
    case expand
    case inverse
    case hyperbolic
    case angle
    case decimal
    case parenthesis
    case random
}

struct CalculatorScreen: View {
    private static let expressionScrollID = "expression"
    /// History button, input row and live result, with the session history scrolled away.
    private static let minimumHeaderHeight: CGFloat = 40 + 100 + 40 + 18

    @EnvironmentObject private var historyStore: CalculationHistoryStore
    @ObservedObject var model: CalculatorViewModel
    let onOpenHistory: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let columnCount = model.expanded ? 5 : 4
            let spacing: CGFloat = 8
            let horizontalPadding: CGFloat = model.expanded ? 18 : 24
            let availableWidth = geometry.size.width - (horizontalPadding * 2)
            let buttonSize = floor((availableWidth - (CGFloat(columnCount - 1) * spacing)) / CGFloat(columnCount))
            let bottomPadding: CGFloat = model.expanded ? 10 : 12
            // On small phones the expanded keypad is taller than the space under the display,
            // so the keys flatten instead of pushing the layout off screen.
            let rowCount = CGFloat(keypadRows.count)
            let availableHeight = geometry.size.height - Self.minimumHeaderHeight - bottomPadding
            let buttonHeight = min(buttonSize, floor((availableHeight - (rowCount - 1) * spacing) / rowCount))

            VStack(spacing: 0) {
                calculatorHeader

                VStack(spacing: spacing) {
                    ForEach(Array(keypadRows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: spacing) {
                            ForEach(row) { button in
                                Button {
                                    handle(button)
                                } label: {
                                    CalculatorButton(definition: button, expanded: model.expanded, inverted: model.inverted, hyperbolic: model.hyperbolic, angleMode: model.angleMode)
                                        .frame(width: buttonSize, height: buttonHeight)
                                }
                                .buttonStyle(PressableButtonStyle(cornerRadius: model.expanded ? 18 : 24))
                                .accessibilityLabel(accessibilityName(for: button))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, bottomPadding)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(AppColor.background)
        }
    }

    private var calculatorHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    impact(.light)
                    onOpenHistory()
                }) {
                    AppIcon(name: "clock", size: 20, color: Color(red: 0.53, green: 0.53, blue: 0.53))
                        .frame(width: 36, height: 36)
                        .appGlassCircle(tint: Color.white.opacity(0.06), interactive: true, fallbackOpacity: 0.10)
                }
                .accessibilityLabel("History")
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, ToolDetailLayout.headerTopExtra)

            ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .trailing, spacing: 8) {
                    ForEach(Array(model.sessionHistory.enumerated()), id: \.offset) { _, item in
                        Button {
                            impact(.light)
                            let expression = item.components(separatedBy: "=").first?.trimmingCharacters(in: .whitespaces) ?? item
                            model.setExpression(expression)
                        } label: {
                            Text(item)
                                .font(.system(size: 22))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .contextMenu {
                            Button("Copy Result") {
                                UIPasteboard.general.string = item.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces)
                            }
                        }
                    }
                }
                .padding(10)
            }
            .onChange(of: model.sessionHistory.count) { count in
                reader.scrollTo(count - 1, anchor: .bottom)
            }
            }
            .frame(maxHeight: .infinity)

            inputView

            if !model.expression.isEmpty, !model.tempResult.isEmpty {
                Text("= \(model.formatResult(model.tempResult))")
                    .font(.system(size: 25))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .frame(height: 40)
                    .padding(.trailing, 30)
                    .padding(.bottom, model.expanded ? 18 : 20)
            } else {
                Color.clear.frame(height: 40)
                    .padding(.bottom, model.expanded ? 18 : 20)
            }
        }
    }

    private var inputView: some View {
        HStack(alignment: .center, spacing: 0) {
            Spacer(minLength: 10)
            if !model.error.isEmpty {
                Text(model.error)
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            } else if model.expression.isEmpty {
                Text("0")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                    .contextMenu {
                        Button("Paste") { model.pasteClipboard() }
                    }
            } else {
                HStack(alignment: .center, spacing: 8) {
                    GeometryReader { container in
                    ScrollViewReader { reader in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(Array(model.formattedChunks().enumerated()), id: \.offset) { index, chunk in
                                Text(model.formatChunk(chunk))
                                    .font(.system(size: 48))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 3)
                                    .background(model.selectedChunkIndex == index ? Color(red: 0.16, green: 0.31, blue: 0.78).opacity(0.55) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .onTapGesture { model.selectChunk(index) }
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityValue(model.selectedChunkIndex == index ? "Selected" : "")
                                    .accessibilityIdentifier("expressionChunk")
                                    .contextMenu {
                                        Button("Copy") { model.copyChunk(chunk) }
                                    }
                                }
                            }
                            .frame(minWidth: container.size.width, minHeight: container.size.height, alignment: .trailing)
                            .id(Self.expressionScrollID)
                    }
                    // Long expressions stay pinned to what is being typed, unless editing a chunk.
                    .onChange(of: model.expression) { _ in
                        guard model.selectedChunkIndex == nil else { return }
                        reader.scrollTo(Self.expressionScrollID, anchor: .trailing)
                    }
                    .onAppear {
                        reader.scrollTo(Self.expressionScrollID, anchor: .trailing)
                    }
                    }
                    }
                    .frame(height: 70)

                    Button(action: model.backspace) {
                        AppIcon(name: "delete", size: 27, color: Color(red: 0.71, green: 0.71, blue: 0.71))
                            .frame(width: 38, height: 44)
                    }
                    .accessibilityLabel("Delete")
                }
            }
        }
        .frame(minHeight: 100)
        .padding(.trailing, 20)
    }

    private var buttons: [CalculatorButtonDefinition] {
        [
            CalculatorButtonDefinition(label: "HYP", value: "HYP", theme: .secondary, expandedOnly: true, action: .hyperbolic),
            CalculatorButtonDefinition(label: "INV", value: "INV", theme: .secondary, expandedOnly: true, action: .inverse),
            CalculatorButtonDefinition(label: "sin", value: "sin", theme: .secondary, expandedOnly: true),
            CalculatorButtonDefinition(label: "cos", value: "cos", theme: .secondary, expandedOnly: true),
            CalculatorButtonDefinition(label: "tan", value: "tan", theme: .secondary, expandedOnly: true),
            CalculatorButtonDefinition(label: "x^y", value: "^", theme: .secondary, expandedOnly: true),
            CalculatorButtonDefinition(label: "lg", value: "log(", theme: .secondary, expandedOnly: true),
            CalculatorButtonDefinition(label: "lg10", value: "log10(", theme: .secondary, expandedOnly: true),
            CalculatorButtonDefinition(label: "Rand", value: "Rand", theme: .secondary, expandedOnly: true, action: .random),
            CalculatorButtonDefinition(label: "DEG", value: "DEG", theme: .secondary, expandedOnly: true, action: .angle),
            CalculatorButtonDefinition(label: "√x", value: "sqrt(", theme: .secondary, expandedOnly: true),
            CalculatorButtonDefinition(label: "AC", value: "AC", theme: .secondary, action: .clear),
            CalculatorButtonDefinition(label: "(  )", value: "()", theme: .secondary, action: .parenthesis),
            CalculatorButtonDefinition(label: "%", value: "%", theme: .secondary),
            CalculatorButtonDefinition(label: "÷", value: "/", theme: .primary),
            CalculatorButtonDefinition(label: "x!", value: "!", theme: .secondary, expandedOnly: true),
            CalculatorButtonDefinition(value: "7", theme: .number),
            CalculatorButtonDefinition(value: "8", theme: .number),
            CalculatorButtonDefinition(value: "9", theme: .number),
            CalculatorButtonDefinition(label: "×", value: "*", theme: .primary),
            CalculatorButtonDefinition(label: "1/x", value: "1/", theme: .secondary, expandedOnly: true),
            CalculatorButtonDefinition(value: "4", theme: .number),
            CalculatorButtonDefinition(value: "5", theme: .number),
            CalculatorButtonDefinition(value: "6", theme: .number),
            CalculatorButtonDefinition(value: "-", theme: .primary),
            CalculatorButtonDefinition(label: "π", value: "pi", theme: .secondary, expandedOnly: true),
            CalculatorButtonDefinition(value: "1", theme: .number),
            CalculatorButtonDefinition(value: "2", theme: .number),
            CalculatorButtonDefinition(value: "3", theme: .number),
            CalculatorButtonDefinition(value: "+", theme: .primary),
            CalculatorButtonDefinition(label: "X", value: "expand", theme: .expand, action: .expand),
            CalculatorButtonDefinition(value: "e", theme: .number, expandedOnly: true),
            CalculatorButtonDefinition(value: "0", theme: .number),
            CalculatorButtonDefinition(label: Locale.current.decimalSeparator ?? ".", value: ".", theme: .number, action: .decimal),
            CalculatorButtonDefinition(label: "=", value: "=", theme: .equal, action: .calculate)
        ]
    }

    private var keypadRows: [[CalculatorButtonDefinition]] {
        let visibleButtons = buttons.filter { model.expanded || !$0.expandedOnly }
        let columnCount = model.expanded ? 5 : 4
        return stride(from: 0, to: visibleButtons.count, by: columnCount).map { start in
            Array(visibleButtons[start..<min(start + columnCount, visibleButtons.count)])
        }
    }

    private func accessibilityName(for button: CalculatorButtonDefinition) -> String {
        switch button.value {
        case "expand": return model.expanded ? "Collapse keypad" : "Expand keypad"
        case "/": return "Divide"
        case "*": return "Multiply"
        case "-": return "Minus"
        case "+": return "Plus"
        case "=": return "Equals"
        case "()": return "Parentheses"
        case ".": return "Decimal point"
        case "^": return "Power"
        case "!": return "Factorial"
        case "1/": return "Reciprocal"
        case "pi": return "Pi"
        case "sqrt(": return "Square root"
        case "log(": return "Natural logarithm"
        case "log10(": return "Logarithm base 10"
        case "HYP": return model.hyperbolic ? "Hyperbolic on" : "Hyperbolic off"
        case "INV": return model.inverted ? "Inverse on" : "Inverse off"
        case "DEG": return model.angleMode == .degrees ? "Degrees" : "Radians"
        case "AC": return "All clear"
        default: return button.label
        }
    }

    private func handle(_ button: CalculatorButtonDefinition) {
        // Clearing plays its own heavier haptic.
        if button.action != .clear {
            impact(.light)
        }
        switch button.action {
        case .clear:
            model.clear()
        case .calculate:
            model.calculate(historyStore: historyStore)
        case .expand:
            model.expanded.toggle()
        case .inverse:
            model.inverted.toggle()
        case .hyperbolic:
            model.hyperbolic.toggle()
        case .angle:
            model.angleMode = model.angleMode == .degrees ? .radians : .degrees
        case .decimal:
            model.decimalPoint()
        case .parenthesis:
            model.nextParenthesis()
        case .random:
            model.random()
        case nil:
            if ["sin", "cos", "tan"].contains(button.value) {
                model.pressFactor("\(model.inverted ? "a" : "")\(button.value)\(model.hyperbolic ? "h" : "")(")
            } else if ["1/", "pi", "e", "log(", "log10(", "sqrt("].contains(button.value) {
                model.pressFactor(button.value)
            } else {
                model.press(button.value)
            }
        }
    }
}

private struct CalculatorButton: View {
    let definition: CalculatorButtonDefinition
    let expanded: Bool
    let inverted: Bool
    let hyperbolic: Bool
    let angleMode: AngleMode

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: expanded ? 18 : 24, style: .continuous)
        if definition.theme == .expand {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        } else {
            ZStack {
                shape.fill(baseFill)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .appGlass(cornerRadius: expanded ? 18 : 24, tint: glassTint, interactive: false, fallbackOpacity: fallbackOpacity)
            .contentShape(shape)
        }
    }

    @ViewBuilder
    private var content: some View {
        if definition.label == "X" {
            Image(systemName: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                .font(.system(size: expanded ? 30 : 36, weight: .medium))
                .foregroundColor(Color(red: 0.74, green: 0.74, blue: 0.74))
        } else if definition.value == "()" {
            Text("()")
                .font(.system(size: expanded ? 24 : 34, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let iconName = operatorIconName {
            AppIcon(name: iconName, size: operatorIconSize, color: foregroundColor, strokeWidth: 2.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text(displayLabel)
                .font(.system(size: fontSize, weight: fontWeight))
                .foregroundColor(foregroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var displayLabel: String {
        if definition.value == "DEG", angleMode == .radians { return "RAD" }
        guard ["sin", "cos", "tan"].contains(definition.value) else { return definition.label }
        return "\(definition.label)\(hyperbolic ? "h" : "")\(inverted ? "⁻¹" : "")"
    }

    private var operatorIconName: String? {
        switch definition.value {
        case "/": return "divide"
        case "*": return "x"
        case "-": return "minus"
        case "+": return "plus"
        case "=": return "equal"
        default: return nil
        }
    }

    private var operatorIconSize: CGFloat {
        if definition.theme == .equal { return expanded ? 34 : 38 }
        return expanded ? 28 : 34
    }

    private var baseFill: Color {
        switch definition.theme {
        case .number:
            return Color(red: 0.17, green: 0.17, blue: 0.17)
        case .secondary:
            return Color(red: 0.09, green: 0.09, blue: 0.09)
        case .primary:
            return Color(red: 0.23, green: 0.14, blue: 0.01)
        case .equal:
            return Color(red: 0.80, green: 0.48, blue: 0.00)
        case .expand:
            return Color.clear
        }
    }

    private var glassTint: Color {
        if definition.value == "INV", inverted { return Color(red: 0.2, green: 0.2, blue: 0.2) }
        if definition.value == "HYP", hyperbolic { return Color(red: 0.2, green: 0.2, blue: 0.2) }
        if definition.value == "DEG", angleMode == .radians { return Color(red: 0.2, green: 0.2, blue: 0.2) }
        switch definition.theme {
        case .number:
            return Color.white.opacity(0.04)
        case .primary:
            return AppColor.accent.opacity(0.12)
        case .secondary:
            return Color.black.opacity(0.30)
        case .equal:
            return AppColor.accent.opacity(0.45)
        case .expand:
            return Color.white.opacity(0.03)
        }
    }

    private var fallbackOpacity: Double {
        switch definition.theme {
        case .equal:
            return 0.72
        case .primary:
            return 0.26
        case .number:
            return 0.16
        case .secondary:
            return 0.18
        case .expand:
            return 0.10
        }
    }

    private var foregroundColor: Color {
        switch definition.theme {
        case .primary:
            return Color(red: 1, green: 0.62, blue: 0)
        case .secondary:
            return definition.value == "AC" ? Color(red: 0.75, green: 0.46, blue: 0) : Color(red: 0.75, green: 0.75, blue: 0.75)
        default:
            return .white
        }
    }

    private var fontSize: CGFloat {
        if ["Rand", "DEG", "INV", "HYP"].contains(definition.value) { return expanded ? 18 : 20 }
        if ["sin", "cos", "tan"].contains(definition.value), inverted && hyperbolic { return 13 }
        if ["sin", "cos", "tan"].contains(definition.value), inverted || hyperbolic { return 18 }
        switch definition.theme {
        case .equal:
            return expanded ? 45 : 50
        case .primary:
            return expanded ? 45 : 45
        case .secondary:
            return expanded ? 22 : 38
        case .number:
            return expanded ? 30 : 38
        case .expand:
            return 32
        }
    }

    private var fontWeight: Font.Weight {
        definition.value == "()" ? .medium : .regular
    }
}

// MARK: - Converter Grid

struct ConverterGridScreen: View {
    @EnvironmentObject private var appState: ConvCalcAppState
    @State private var selectedTool: ConverterTool?
    @State private var toast: String?

    private let initialRearranging: Bool
    private let onOpenTool: ((ConverterTool) -> Void)?

    init(initialRearranging: Bool = false, onOpenTool: ((ConverterTool) -> Void)? = nil) {
        self.initialRearranging = initialRearranging
        self.onOpenTool = onOpenTool
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    if appState.isRearrangingTools {
                        appState.endRearrangingTools()
                    }
                }

            GeometryReader { geometry in
                ReorderableConverterToolGrid(
                    tools: appState.orderedTools,
                    pinnedKeys: appState.pinnedToolKeys,
                    availableWidth: max(0, geometry.size.width - 48),
                    onSelect: { tool in
                        openTool(tool)
                    },
                    onExitRearrange: exitRearrange,
                    onSetPinned: { key, shouldPin in
                        setPinned(key, shouldPin: shouldPin)
                    }
                )
                .padding(.horizontal, 24)
                .padding(.top, 88)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            if let toast {
                Text(toast)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.top, 64)
                    .frame(maxHeight: .infinity, alignment: .top)
            }

            if onOpenTool == nil, let selectedTool {
                ToolDetailPage(tool: selectedTool, onClose: closeLocalTool)
                    .transition(toolPageTransition)
                    .zIndex(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            // Pinning retags this page, which makes the TabView rebuild it, so appearing
            // says nothing about rearranging. RootView ends it when the user pages away.
            if initialRearranging {
                appState.isRearrangingTools = true
            }
        }
    }

    private func exitRearrange() {
        appState.endRearrangingTools()
    }

    private func openTool(_ tool: ConverterTool) {
        guard appState.allowsToolOpening else { return }
        exitRearrange()
        if let onOpenTool {
            onOpenTool(tool)
        } else {
            withAnimation(toolPageAnimation) {
                selectedTool = tool
            }
        }
    }

    private func closeLocalTool() {
        withAnimation(toolPageAnimation) {
            selectedTool = nil
        }
    }

    private func setPinned(_ key: String, shouldPin: Bool) {
        if shouldPin {
            guard appState.pin(key) else {
                showToast("Toolbar is full (max \(ConvCalcAppState.maxPinnedTools))")
                return
            }
        } else {
            appState.unpin(key)
        }
    }

    private func showToast(_ message: String) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if toast == message { toast = nil }
        }
    }
}

private struct ReorderableConverterToolGrid: View {
    @EnvironmentObject private var appState: ConvCalcAppState

    let tools: [ConverterTool]
    let pinnedKeys: [String]
    let availableWidth: CGFloat
    let onSelect: (ConverterTool) -> Void
    let onExitRearrange: () -> Void
    let onSetPinned: (String, Bool) -> Void

    @State private var activeToolKey: String?
    @State private var heldToolKey: String?
    @GestureState private var pressedToolKey: String?
    @State private var dragLocation = CGPoint.zero
    @State private var fingerOffset = CGSize.zero
    @State private var blockToolbarPlacementUntil = Date.distantPast
    @State private var activeDragTranslation = CGSize.zero
    @State private var pinToggleLockedUntil = Date.distantPast

    private static let coordinateSpace = "converterToolReorderGrid"
    private static let columnCount = 4
    private static let columnSpacing: CGFloat = 14
    private static let rowSpacing: CGFloat = 18
    private static let longPressDuration: TimeInterval = 0.42
    private static let longPressMaxDistance: CGFloat = 28
    private static let dragMinimumDistance: CGFloat = 12
    private static let toolbarDropDragThreshold: CGFloat = 36

    private var itemSize: CGFloat {
        let spacing = Self.columnSpacing * CGFloat(Self.columnCount - 1)
        return max(64, floor((availableWidth - spacing) / CGFloat(Self.columnCount)))
    }

    private var gridHeight: CGFloat {
        let rows = max(1, Int(ceil(Double(tools.count) / Double(Self.columnCount))))
        return CGFloat(rows) * itemSize + CGFloat(rows - 1) * Self.rowSpacing
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                toolInteraction(for: tool, at: index)
            }
        }
        .frame(width: availableWidth, height: gridHeight, alignment: .topLeading)
        .background {
            if appState.isRearrangingTools {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onExitRearrange()
                    }
            }
        }
        .coordinateSpace(name: Self.coordinateSpace)
        .onChange(of: appState.isRearrangingTools) { isRearranging in
            if !isRearranging {
                finishDrag()
            }
        }
    }

    @ViewBuilder
    private func toolInteraction(for tool: ConverterTool, at index: Int) -> some View {
        let isActive = activeToolKey == tool.key
        let isPressed = pressedToolKey == tool.key || heldToolKey == tool.key
        let card = ConverterToolCard(
            tool: tool,
            rearranging: appState.isRearrangingTools && !isActive,
            pinned: appState.isToolPinned(tool.key),
            pressed: isPressed
        )
        .frame(width: itemSize, height: itemSize)
        .contentShape(Rectangle())
        .scaleEffect(cardScale(isActive: isActive, isPressed: isPressed))
        // Snap down fast on press; ease back up gently.
        .animation(.easeOut(duration: isPressed ? 0.05 : 0.18), value: isPressed)
        .animation(.spring(response: 0.28, dampingFraction: 0.62), value: appState.isRearrangingTools)

        // NOTE: position cards with `.position`, not `.offset`. `.offset` is a
        // render-only transform that does not move a view's hit-testing frame,
        // so every card's touches collapse onto the un-offset top-leading slot
        // and only the topmost card in the ZStack ever responds. `.position`
        // is layout-based, so hit-testing follows the card to its slot.
        gestured(card, for: tool, at: index)
            .shadow(color: isActive ? Color.black.opacity(0.38) : .clear, radius: 18, x: 0, y: 14)
            .zIndex(isActive ? 10 : 0)
            .position(positionPoint(for: index, isActive: isActive))
            .animation(isActive ? nil : .interactiveSpring(response: 0.24, dampingFraction: 0.82), value: tools.map(\.key))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(tool.label)
            .accessibilityValue(appState.isRearrangingTools ? (appState.isToolPinned(tool.key) ? "Pinned" : "Not pinned") : "")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                if appState.isRearrangingTools {
                    handlePinTap(tool)
                } else {
                    onSelect(tool)
                }
            }
    }

    @ViewBuilder
    private func gestured(_ card: some View, for tool: ConverterTool, at index: Int) -> some View {
        if appState.isRearrangingTools {
            card
                .onTapGesture {
                    handlePinTap(tool)
                }
                .gesture(dragGesture(for: tool, at: index))
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .updating($pressedToolKey) { _, state, _ in
                            state = tool.key
                        }
                )
        } else {
            // A Button, unlike a custom tap gesture, lets a swipe that starts on the card reach
            // the pager. Rearrange mode replaces this Button, so a hold never also opens the tool.
            Button {
                onSelect(tool)
            } label: {
                card
            }
            .buttonStyle(PressReportingButtonStyle { pressing in
                heldToolKey = pressing ? tool.key : nil
            })
            .simultaneousGesture(
                LongPressGesture(
                    minimumDuration: Self.longPressDuration,
                    maximumDistance: Self.longPressMaxDistance
                )
                .onEnded { _ in
                    impact(.heavy)
                    appState.beginRearrangingTools()
                }
            )
        }
    }

    private func positionPoint(for index: Int, isActive: Bool) -> CGPoint {
        isActive ? activeCenter() : slotCenter(for: index)
    }

    /// Scale a grid card: lifted while dragged, pressed-down while held, and
    /// nudged up in rearrange mode so it visibly reads as "movable".
    private func cardScale(isActive: Bool, isPressed: Bool) -> CGFloat {
        if isActive { return 1.12 }
        if isPressed { return 0.88 }
        if appState.isRearrangingTools { return 1.08 }
        return 1
    }

    private func handlePinTap(_ tool: ConverterTool) {
        let now = Date()
        guard now >= pinToggleLockedUntil else { return }
        pinToggleLockedUntil = now.addingTimeInterval(0.3)
        blockToolbarPlacementUntil = now.addingTimeInterval(0.5)

        let shouldPin = !appState.isToolPinned(tool.key)
        impact(.light)
        onSetPinned(tool.key, shouldPin)
    }

    private func dragGesture(for tool: ConverterTool, at index: Int) -> some Gesture {
        DragGesture(minimumDistance: Self.dragMinimumDistance, coordinateSpace: .named(Self.coordinateSpace))
        .onChanged { value in
            guard appState.isRearrangingTools else { return }
            activeDragTranslation = value.translation
            if activeToolKey != tool.key {
                beginDrag(toolKey: tool.key, at: index, drag: value)
            }
            updateDrag(value)
        }
        .onEnded { _ in
            guard appState.isRearrangingTools else { return }
            if let activeToolKey, activeDragTranslation.height <= -Self.toolbarDropDragThreshold {
                placeInShortcutBarIfNeeded(activeToolKey, center: activeCenter())
            }
            activeDragTranslation = .zero
            finishDrag()
        }
    }

    private func beginDrag(toolKey: String, at index: Int, drag: DragGesture.Value) {
        appState.beginRearrangingTools()
        appState.draggedToolKey = toolKey
        activeToolKey = toolKey

        let center = slotCenter(for: index)
        fingerOffset = CGSize(
            width: drag.startLocation.x - center.x,
            height: drag.startLocation.y - center.y
        )
        dragLocation = drag.location
    }

    private func updateDrag(_ drag: DragGesture.Value) {
        dragLocation = drag.location

        guard let activeToolKey else { return }
        let center = activeCenter()
        let targetIndex = index(for: center)
        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.82)) {
            appState.moveTool(activeToolKey, to: targetIndex)
        }
    }

    private func finishDrag() {
        activeToolKey = nil
        appState.draggedToolKey = nil
        dragLocation = .zero
        fingerOffset = .zero
    }

    private func slotOffset(for index: Int) -> CGSize {
        let row = index / Self.columnCount
        let column = index % Self.columnCount
        return CGSize(
            width: CGFloat(column) * (itemSize + Self.columnSpacing),
            height: CGFloat(row) * (itemSize + Self.rowSpacing)
        )
    }

    private func slotCenter(for index: Int) -> CGPoint {
        let offset = slotOffset(for: index)
        return CGPoint(x: offset.width + itemSize / 2, y: offset.height + itemSize / 2)
    }

    private func activeCenter() -> CGPoint {
        CGPoint(
            x: dragLocation.x - fingerOffset.width,
            y: dragLocation.y - fingerOffset.height
        )
    }

    private func index(for center: CGPoint) -> Int {
        let column = Int(round((center.x - itemSize / 2) / (itemSize + Self.columnSpacing)))
        let row = Int(round((center.y - itemSize / 2) / (itemSize + Self.rowSpacing)))
        let clampedColumn = min(max(column, 0), Self.columnCount - 1)
        let maxRow = max(0, Int(ceil(Double(tools.count) / Double(Self.columnCount))) - 1)
        let clampedRow = min(max(row, 0), maxRow)
        return min(clampedRow * Self.columnCount + clampedColumn, max(0, tools.count - 1))
    }

    private func placeInShortcutBarIfNeeded(_ sourceKey: String, center: CGPoint) {
        guard Date() >= blockToolbarPlacementUntil else { return }
        guard center.y < -34 else { return }
        guard appState.isToolPinned(sourceKey) || appState.canPinMoreTools else { return }

        let tabs = appState.screenOrder + ["_converter"]
        guard !tabs.isEmpty else { return }

        let iconWidth: CGFloat = 40
        let barWidth = CGFloat(tabs.count) * iconWidth + 12
        let leftEdge = (availableWidth - barWidth) / 2 + 6
        let rawIndex = Int(floor((center.x - leftEdge) / iconWidth))
        let targetIndex = min(max(rawIndex, 0), tabs.count - 1)

        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.84)) {
            _ = appState.reorderToolbarTab(sourceKey, before: tabs[targetIndex])
        }
    }
}

private struct PressReportingButtonStyle: ButtonStyle {
    let onPressChanged: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label.onChange(of: configuration.isPressed, perform: onPressChanged)
    }
}

private struct ConverterToolCard: View {
    let tool: ConverterTool
    let rearranging: Bool
    let pinned: Bool
    var pressed: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        ZStack(alignment: .topTrailing) {
            shape.fill(Color(red: 0.17, green: 0.17, blue: 0.17))
            shape.fill(Color.white.opacity(pressed ? 0.10 : 0))

            VStack(spacing: 7) {
                AppIcon(name: tool.symbolName, size: 27, color: .white)
                    .frame(height: 30)
                    .reorderShake(rearranging)
                Text(tool.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if rearranging {
                AppIcon(
                    name: "pin",
                    size: 16,
                    color: pinned ? AppColor.accent : Color.white.opacity(0.78),
                    filled: pinned,
                    strokeWidth: 2.25
                )
                .padding(7)
                .allowsHitTesting(false)
            }
        }
        .appGlass(cornerRadius: 24, tint: Color.white.opacity(0.04), interactive: false, fallbackOpacity: 0.16)
        .contentShape(shape)
    }
}

struct PinnedToolScreen: View {
    let toolKey: String

    var body: some View {
        if toolKey == "currency" {
            CurrencyScreen(onBack: nil)
        } else if let tool = ConverterTool.all.first(where: { $0.key == toolKey }) {
            ConverterDetailScreen(tool: tool, onBack: nil)
        } else {
            AppColor.background
        }
    }
}

private enum ToolPageCloseGesture {
    static let minimumDistance: CGFloat = 28
    static let horizontalDominanceRatio: CGFloat = 2.0
    static let closeProgressThreshold: CGFloat = 0.45
    static let minimumDragBeforeVelocityClose: CGFloat = 0.2
    static let velocityCloseProgressThreshold: CGFloat = 0.62
}

private struct ToolDetailPage: View {
    let tool: ConverterTool
    let onClose: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ToolDetailHost(tool: tool, onBack: onClose)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .background(AppColor.background.ignoresSafeArea(edges: .bottom))
                .offset(x: dragOffset)
                .contentShape(Rectangle())
                .simultaneousGesture(closeGesture(width: geometry.size.width))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background.ignoresSafeArea(edges: .bottom))
    }

    private func closeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: ToolPageCloseGesture.minimumDistance, coordinateSpace: .local)
            .onChanged { value in
                guard isClosingDrag(value.translation) else { return }
                dragOffset = min(width, max(0, value.translation.width))
            }
            .onEnded { value in
                let shouldClose = shouldCloseToolPage(
                    dragOffset: dragOffset,
                    predictedEndWidth: value.predictedEndTranslation.width,
                    pageWidth: width
                )
                if shouldClose {
                    onClose()
                } else {
                    withAnimation(toolPageAnimation) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func isClosingDrag(_ translation: CGSize) -> Bool {
        translation.width > 0
            && translation.width > abs(translation.height) * ToolPageCloseGesture.horizontalDominanceRatio
    }

    private func shouldCloseToolPage(dragOffset: CGFloat, predictedEndWidth: CGFloat, pageWidth: CGFloat) -> Bool {
        guard pageWidth > 0 else { return false }

        let progress = dragOffset / pageWidth
        if progress >= ToolPageCloseGesture.closeProgressThreshold {
            return true
        }

        let predictedProgress = max(dragOffset, predictedEndWidth) / pageWidth
        return progress >= ToolPageCloseGesture.minimumDragBeforeVelocityClose
            && predictedProgress >= ToolPageCloseGesture.velocityCloseProgressThreshold
    }
}

struct ToolDetailHost: View {
    let tool: ConverterTool
    let onBack: () -> Void

    var body: some View {
        if tool.key == "currency" {
            CurrencyScreen(onBack: onBack)
        } else {
            ConverterDetailScreen(tool: tool, onBack: onBack)
        }
    }
}

// MARK: - Converter Detail

struct ConverterDetailScreen: View {
    let tool: ConverterTool
    let onBack: (() -> Void)?

    var body: some View {
        if tool.kind == .unit {
            UnitConverterScreen(tool: tool, onBack: onBack)
        } else {
            UtilityCalculatorScreen(tool: tool, onBack: onBack)
        }
    }
}

private struct DetailHeader: View {
    let onBack: (() -> Void)?

    var body: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    AppIcon(name: "chevronLeft", size: 20, color: .white, strokeWidth: 2.5)
                        .frame(width: 36, height: 36)
                        .appGlassCircle(tint: Color.white.opacity(0.06), interactive: true, fallbackOpacity: 0.10)
                }
                .accessibilityLabel("Back")
            } else {
                Color.clear.frame(width: 36, height: 36)
            }
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, ToolDetailLayout.headerTopExtra)
        .padding(.bottom, ToolDetailLayout.headerBottomSpacing)
    }
}

private enum ToolDetailLayout {
    static let headerTopExtra: CGFloat = 4
    static let headerBottomSpacing: CGFloat = 18
    static let pinnedContentTopExtra: CGFloat = 4

    static func contentTopInset(hasBackButton: Bool) -> CGFloat {
        hasBackButton ? 0 : pinnedContentTopExtra
    }
}

struct UnitConverterScreen: View {
    let tool: ConverterTool
    let onBack: (() -> Void)?

    @State private var input = "1"
    @State private var inputEdited = false
    @State private var fromIndex = 0

    private var results: [ConversionResult] {
        ConverterCore.convertToAll(value: Double(input) ?? 0, fromIndex: fromIndex, units: tool.units)
    }

    var body: some View {
        GeometryReader { geometry in
            let bottomInset = geometry.resolvedSafeAreaInsets.bottom
            let topPadding = ToolDetailLayout.contentTopInset(hasBackButton: onBack != nil)

            VStack(spacing: 0) {
                if onBack != nil {
                    DetailHeader(onBack: onBack)
                }

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                            Button {
                                guard index != fromIndex else { return }
                                fromIndex = index
                                input = "1"
                                inputEdited = false
                            } label: {
                                HStack(alignment: .center) {
                                    Text(result.name)
                                        .font(.system(size: index == fromIndex ? 22 : 18, weight: .medium))
                                        .foregroundColor(index == fromIndex ? .white : Color(red: 0.6, green: 0.6, blue: 0.6))
                                        .frame(minWidth: 70, alignment: .leading)

                                    Spacer(minLength: 8)

                                    Text(index == fromIndex ? CalculatorNumberFormat.typedNumber(input) : ConverterCore.formatConversionResult(result.value))
                                        .font(.system(size: index == fromIndex ? 26 : 18))
                                        .foregroundColor(index == fromIndex ? AppColor.accent : .white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)

                                    Text(result.label)
                                        .font(.system(size: index == fromIndex ? 16 : 13))
                                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                                        .frame(minWidth: 30, alignment: .leading)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                                .appGlassWhen(index == fromIndex, cornerRadius: 12, tint: Color.white.opacity(0.07), interactive: true, fallbackOpacity: 0.12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityValue(index == fromIndex ? "Active" : "")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, topPadding)
                }

                NumericKeypad(
                    appendValue: appendValue,
                    onClear: clear,
                    onBackspace: backspace,
                    onToggleSign: tool.key == "temperature" ? toggleSign : nil
                )
                .padding(.top, 16)
                .padding(.bottom, bottomInset > 0 ? max(10, bottomInset - 16) : 10)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.ignoresSafeArea(edges: .bottom))
    }

    private func appendValue(_ value: String) {
        if !inputEdited {
            inputEdited = true
            input = value == "." ? "0." : value
            return
        }
        if value == ".", input.contains(".") { return }
        guard input.count < ConverterCore.maxInputLength else { return }
        input = input == "0" && value != "." ? value : input + value
    }

    private func backspace() {
        inputEdited = true
        let remaining = String(input.dropLast())
        input = remaining.isEmpty || remaining == "-" ? "0" : remaining
    }

    private func clear() {
        inputEdited = true
        input = "0"
    }

    private func toggleSign() {
        inputEdited = true
        if input.hasPrefix("-") {
            input.removeFirst()
        } else if input != "0" {
            input = "-" + input
        }
    }
}

private struct CalcFieldConfig: Identifiable {
    let key: String
    let label: String
    let placeholder: String
    let suffix: String

    var id: String { key }
}

struct UtilityCalculatorScreen: View {
    let tool: ConverterTool
    let onBack: (() -> Void)?

    @State private var values: [String: String] = [:]
    @State private var activeField = ""
    @State private var editedFields: Set<String> = []

    private var fields: [CalcFieldConfig] {
        Self.configs[tool.key] ?? []
    }

    private var usesCompactRows: Bool {
        fields.count > 3
    }

    var body: some View {
        GeometryReader { geometry in
            let bottomInset = geometry.resolvedSafeAreaInsets.bottom
            let topPadding = ToolDetailLayout.contentTopInset(hasBackButton: onBack != nil)

            VStack(spacing: 0) {
                if onBack != nil {
                    DetailHeader(onBack: onBack)
                }

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(fields) { field in
                            Button {
                                activeField = field.key
                            } label: {
                                HStack {
                                    Text(field.label)
                                        .font(.system(size: usesCompactRows ? 16 : 18, weight: .medium))
                                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                                        .frame(minWidth: 70, alignment: .leading)
                                    Spacer()
                                    Text("\(formatInputDisplay(values[field.key] ?? field.placeholder))\(field.suffix)")
                                        .font(.system(size: usesCompactRows ? 17 : 18))
                                        .foregroundColor(activeField == field.key ? AppColor.accent : .white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, usesCompactRows ? 7 : 10)
                                .padding(.horizontal, 12)
                                .appGlassWhen(activeField == field.key, cornerRadius: 12, tint: Color.white.opacity(0.07), interactive: true, fallbackOpacity: 0.12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityValue(activeField == field.key ? "Active" : "")
                        }

                        if let result = resultView {
                            result
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .appGlass(cornerRadius: 14, tint: Color.white.opacity(0.07), fallbackOpacity: 0.12)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 16)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, topPadding)
                }

                NumericKeypad(appendValue: appendValue, onClear: clear, onBackspace: backspace)
                    .padding(.top, 16)
                    .padding(.bottom, bottomInset > 0 ? max(10, bottomInset - 16) : 10)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.ignoresSafeArea(edges: .bottom))
        .onAppear {
            if values.isEmpty {
                values = Dictionary(uniqueKeysWithValues: fields.map { ($0.key, $0.placeholder) })
                activeField = fields.first?.key ?? ""
            }
        }
    }

    private var resultView: AnyView? {
        let nums = Dictionary(uniqueKeysWithValues: fields.map { ($0.key, Double(values[$0.key] ?? "") ?? 0) })
        switch tool.key {
        case "age":
            if let result = ConverterCore.calculateAge(year: Int(nums["year"] ?? 0), month: Int(nums["month"] ?? 0), day: Int(nums["day"] ?? 0)) {
                return AnyView(VStack(alignment: .leading, spacing: 6) {
                    Text("Age").resultTitle()
                    Text("\(result.years) years, \(result.months) months, \(result.days) days").resultText()
                })
            }
        case "bmi":
            if let result = ConverterCore.calculateBMI(heightCm: nums["height"] ?? 0, weightKg: nums["weight"] ?? 0) {
                return AnyView(VStack(alignment: .leading, spacing: 6) {
                    Text("BMI").resultTitle()
                    Text("\(ConverterCore.formatNumber(result.bmi, decimals: 1)) - \(result.category)").resultText()
                })
            }
        case "date":
            if let result = ConverterCore.calculateDateDiff(
                year1: Int(nums["year1"] ?? 0),
                month1: Int(nums["month1"] ?? 0),
                day1: Int(nums["day1"] ?? 0),
                year2: Int(nums["year2"] ?? 0),
                month2: Int(nums["month2"] ?? 0),
                day2: Int(nums["day2"] ?? 0)
            ) {
                return AnyView(VStack(alignment: .leading, spacing: 6) {
                    Text("Difference").resultTitle()
                    Text("\(ConverterCore.formatNumber(Double(result.totalDays), decimals: 0)) days").resultText()
                    Text("\(ConverterCore.formatNumber(Double(result.weeks), decimals: 0)) weeks").resultText()
                    Text("\(ConverterCore.formatNumber(result.months, decimals: 1)) months").resultText()
                    Text("\(ConverterCore.formatNumber(result.years)) years").resultText()
                })
            }
        case "discount":
            if let result = ConverterCore.calculateDiscount(price: nums["price"] ?? 0, percent: nums["percent"] ?? 0) {
                return AnyView(VStack(alignment: .leading, spacing: 6) {
                    Text("Result").resultTitle()
                    Text("Savings: \(ConverterCore.formatNumber(result.savings))").resultText()
                    Text("Final price: \(ConverterCore.formatNumber(result.finalPrice))").resultText()
                })
            }
        case "loan":
            if let result = ConverterCore.calculateLoan(principal: nums["principal"] ?? 0, rate: nums["rate"] ?? 0, years: nums["years"] ?? 0) {
                return AnyView(VStack(alignment: .leading, spacing: 6) {
                    Text("Loan Summary").resultTitle()
                    Text("Monthly: \(ConverterCore.formatNumber(result.monthly))").resultText()
                    Text("Total paid: \(ConverterCore.formatNumber(result.totalPaid))").resultText()
                    Text("Total interest: \(ConverterCore.formatNumber(result.totalInterest))").resultText()
                })
            }
        default:
            return nil
        }
        return nil
    }

    private func appendValue(_ value: String) {
        guard !activeField.isEmpty else { return }
        if !editedFields.contains(activeField) {
            editedFields.insert(activeField)
            values[activeField] = value == "." ? "0." : value
            return
        }
        let current = values[activeField] ?? ""
        if value == ".", current.contains(".") { return }
        guard current.count < ConverterCore.maxInputLength else { return }
        values[activeField] = current == "0" && value != "." ? value : current + value
    }

    private func backspace() {
        editedFields.insert(activeField)
        let current = values[activeField] ?? ""
        values[activeField] = current.count <= 1 ? "" : String(current.dropLast())
    }

    private func clear() {
        editedFields.insert(activeField)
        values[activeField] = ""
    }

    private func formatInputDisplay(_ value: String) -> String {
        // Dates read as "1990", not "1,990".
        let isDateField = tool.key == "age" || tool.key == "date"
        return isDateField ? value : CalculatorNumberFormat.typedNumber(value)
    }

    private static let configs: [String: [CalcFieldConfig]] = [
        "age": [
            CalcFieldConfig(key: "year", label: "Year", placeholder: "1990", suffix: ""),
            CalcFieldConfig(key: "month", label: "Month", placeholder: "1", suffix: ""),
            CalcFieldConfig(key: "day", label: "Day", placeholder: "1", suffix: "")
        ],
        "bmi": [
            CalcFieldConfig(key: "height", label: "Height (cm)", placeholder: "170", suffix: ""),
            CalcFieldConfig(key: "weight", label: "Weight (kg)", placeholder: "70", suffix: "")
        ],
        "date": [
            CalcFieldConfig(key: "year1", label: "Year 1", placeholder: "2024", suffix: ""),
            CalcFieldConfig(key: "month1", label: "Month 1", placeholder: "1", suffix: ""),
            CalcFieldConfig(key: "day1", label: "Day 1", placeholder: "1", suffix: ""),
            CalcFieldConfig(key: "year2", label: "Year 2", placeholder: "2025", suffix: ""),
            CalcFieldConfig(key: "month2", label: "Month 2", placeholder: "1", suffix: ""),
            CalcFieldConfig(key: "day2", label: "Day 2", placeholder: "1", suffix: "")
        ],
        "discount": [
            CalcFieldConfig(key: "price", label: "Price", placeholder: "100", suffix: ""),
            CalcFieldConfig(key: "percent", label: "%", placeholder: "20", suffix: "")
        ],
        "loan": [
            CalcFieldConfig(key: "principal", label: "Amount", placeholder: "200000", suffix: ""),
            CalcFieldConfig(key: "rate", label: "Rate", placeholder: "5", suffix: "%"),
            CalcFieldConfig(key: "years", label: "Duration", placeholder: "30", suffix: " yrs")
        ]
    ]
}

private extension Text {
    func resultTitle() -> some View {
        self.font(.system(size: 15, weight: .semibold)).foregroundColor(AppColor.accent)
    }

    func resultText() -> some View {
        self.font(.system(size: 18)).foregroundColor(.white)
    }
}

// MARK: - Currency

struct CurrencyScreen: View {
    let onBack: (() -> Void)?
    private let initialPickerVisible: Bool

    @EnvironmentObject private var currencyRates: CurrencyRatesModel
    private let catalog = Self.sharedCatalog
    @State private var activeCurrencyIndex = 0
    @State private var activeAmount = "1"
    @State private var inputEdited = false
    @State private var pickerVisible = false
    @State private var pickerRowIndex = 0

    // SwiftUI re-creates this struct on every parent update, so the catalog is decoded once.
    private static let sharedCatalog = CurrencyCatalog.load()

    init(onBack: (() -> Void)?, initialPickerVisible: Bool = false) {
        self.onBack = onBack
        self.initialPickerVisible = initialPickerVisible
    }

    var body: some View {
        GeometryReader { geometry in
            let bottomInset = geometry.resolvedSafeAreaInsets.bottom
            let topPadding = ToolDetailLayout.contentTopInset(hasBackButton: onBack != nil)
            // Small phones need tighter rows to show all four currencies above the keypad.
            let compact = geometry.size.height < 700

            VStack(spacing: 0) {
                if onBack != nil {
                    DetailHeader(onBack: onBack)
                }

                // Only scrolls if a tool page's back button still pushes the rows past the keypad.
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(currencyRates.displayedCurrencies.indices, id: \.self) { index in
                            currencyRow(code: currencyRates.displayedCurrencies[index], index: index, compact: compact)
                        }

                        Button {
                            Task { await currencyRates.refresh(force: true) }
                        } label: {
                            // Re-rendered periodically so "Updated 5 minutes ago" doesn't freeze.
                            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                                Text(rateStatus(at: timeline.date))
                                    .font(.system(size: 14))
                                    .foregroundColor(currencyRates.refreshFailed ? AppColor.accent : Color(red: 0.33, green: 0.33, blue: 0.33))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                        .padding(.bottom, 12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, topPadding)
                }

                NumericKeypad(appendValue: appendValue, onClear: reset, onBackspace: backspace)
                    .padding(.top, 16)
                    .padding(.bottom, bottomInset > 0 ? max(10, bottomInset - 16) : 10)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.ignoresSafeArea(edges: .bottom))
        .onAppear {
            if initialPickerVisible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    pickerVisible = true
                }
            } else {
                pickerVisible = false
            }
        }
        .sheet(isPresented: $pickerVisible) {
            CurrencyPicker(catalog: catalog) { code in
                currencyRates.setCurrency(code, at: pickerRowIndex)
                let activeCode = currencyRates.displayedCurrencies[activeCurrencyIndex]
                activeAmount = CalculatorNumberFormat.limitingFraction(of: activeAmount, to: catalog[activeCode]?.decimalDigits ?? 2)
                pickerVisible = false
            }
        }
    }

    private func currencyRow(code: String, index: Int, compact: Bool) -> some View {
        let info = catalog[code]
        let isActive = index == activeCurrencyIndex
        return HStack(alignment: .center) {
            Button {
                // Only opens the picker: the typed amount still belongs to the active row.
                pickerRowIndex = index
                pickerVisible = true
            } label: {
                Text(code)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 88, alignment: .leading)
            }
            .accessibilityLabel("Change currency \(code)")

            Spacer(minLength: 8)

            Button {
                activateRow(index)
            } label: {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(displayedAmount(for: code, index: index))
                        .font(.system(size: compact ? 28 : 42, weight: .regular))
                        .foregroundColor(isActive ? AppColor.accent : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Text(info?.name ?? code)
                        .font(.system(size: compact ? 13 : 18))
                        .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.35))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .accessibilityValue(isActive ? "Active" : "")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, compact ? 4 : 8)
        .appGlassWhen(isActive, cornerRadius: 18, tint: Color.white.opacity(0.055), interactive: true, fallbackOpacity: 0.10)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            activateRow(index)
        }
        .buttonStyle(.plain)
    }

    private func activateRow(_ index: Int) {
        guard index != activeCurrencyIndex else { return }
        activeCurrencyIndex = index
        activeAmount = "1"
        inputEdited = false
    }

    private func displayedAmount(for code: String, index: Int) -> String {
        if index == activeCurrencyIndex {
            return CalculatorNumberFormat.typedNumber(activeAmount)
        }

        guard let value = CurrencyRateStore.convert(
            Double(activeAmount) ?? 0,
            from: currencyRates.displayedCurrencies[activeCurrencyIndex],
            to: code,
            rates: currencyRates.rates
        ) else {
            return "—"
        }
        return CurrencyRateStore.formatAmount(value, decimalDigits: catalog[code]?.decimalDigits ?? 2)
    }

    private func rateStatus(at date: Date) -> String {
        if currencyRates.isRefreshing { return "Refreshing rates..." }
        guard let snapshot = currencyRates.snapshot else {
            return currencyRates.refreshFailed ? "Using built-in rates. Update failed" : "Using built-in rates."
        }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .full
        let relativeText = abs(snapshot.updatedAt.timeIntervalSince(date)) < 5
            ? "just now"
            : relative.localizedString(for: snapshot.updatedAt, relativeTo: date)
        let updatedText = "Updated \(relativeText)"
        return currencyRates.refreshFailed ? "\(updatedText). Update failed" : updatedText
    }

    private func appendValue(_ value: String) {
        let code = currencyRates.displayedCurrencies[activeCurrencyIndex]
        let decimalLimit = catalog[code]?.decimalDigits ?? 2

        if value == "." {
            if decimalLimit == 0 { return }
            if activeAmount.contains(".") { return }
            // Starting from the unedited default: begin a fresh decimal entry.
            activeAmount = inputEdited ? activeAmount + "." : "0."
            inputEdited = true
            return
        }

        // The first keystroke replaces the default placeholder rather than
        // appending to it, so "1" + "100" becomes "100" and not a reset to 0.
        guard inputEdited else {
            activeAmount = value
            inputEdited = true
            return
        }

        // Ignore digits once the fractional part already has the maximum number
        // of decimals this currency displays.
        if let dotIndex = activeAmount.firstIndex(of: ".") {
            let fractionCount = activeAmount.distance(from: activeAmount.index(after: dotIndex), to: activeAmount.endIndex)
            if fractionCount >= decimalLimit { return }
        }
        guard activeAmount.count < ConverterCore.maxInputLength else { return }

        // Replace a lone leading zero so "0" + "5" becomes "5", not "05".
        activeAmount = activeAmount == "0" ? value : activeAmount + value
    }

    private func backspace() {
        inputEdited = true
        activeAmount = activeAmount.count <= 1 ? "0" : String(activeAmount.dropLast())
    }

    private func reset() {
        inputEdited = false
        activeAmount = "1"
    }

}

private struct CurrencyPicker: View {
    let catalog: [String: CurrencyInfo]
    let onSelect: (String) -> Void
    @State private var searchText = ""
    @State private var searchPresented = true
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationView {
            searchableContent
                .navigationTitle("Currency")
        }
    }

    @ViewBuilder
    private var searchableContent: some View {
        if #available(iOS 18.0, *) {
            currencyList
                .searchable(text: $searchText, isPresented: $searchPresented)
                .searchFocused($searchFocused)
                .onAppear {
                    focusSearchField()
                }
        } else if #available(iOS 17.0, *) {
            currencyList
                .searchable(text: $searchText, isPresented: $searchPresented)
                .onAppear {
                    searchPresented = true
                }
        } else {
            currencyList
                .searchable(text: $searchText)
        }
    }

    private var currencyList: some View {
        List(filteredCodes, id: \.self) { code in
            Button {
                onSelect(code)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(code)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(catalog[code]?.name ?? code)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func focusSearchField() {
        // Focus the search field immediately so the keyboard rises together with
        // the picker. Re-assert on the next runloop as a safety net (no visible
        // delay) in case the field isn't first responder on the first layout pass.
        searchPresented = true
        searchFocused = true
        DispatchQueue.main.async {
            searchPresented = true
            searchFocused = true
        }
    }

    private var filteredCodes: [String] {
        let codes = catalog.keys.sorted()
        guard !searchText.isEmpty else { return codes }
        return codes.filter { code in
            code.localizedCaseInsensitiveContains(searchText) ||
            (catalog[code]?.name.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
}

// MARK: - Shared Keypad

/// Press/active feedback matching the tool grid: a slight scale-down plus a
/// subtle white highlight while the finger is held down.
private struct PressableButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 24

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.10 : 0))
                    .allowsHitTesting(false)
            )
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            // Snap down fast for an immediate, visible press; ease back up gently.
            .animation(.easeOut(duration: configuration.isPressed ? 0.05 : 0.18), value: configuration.isPressed)
    }
}

private struct NumericKeypad: View {
    let appendValue: (String) -> Void
    let onClear: () -> Void
    let onBackspace: () -> Void
    var onToggleSign: (() -> Void)? = nil

    /// Intrinsic height of the 4-row button block, so the keypad reserves
    /// exactly the space it needs (no top clipping, no dead bottom margin).
    static var contentHeight: CGFloat {
        let spacing: CGFloat = 8
        let horizontalPadding: CGFloat = 24
        let availableWidth = UIScreen.main.bounds.width - (horizontalPadding * 2)
        let buttonSize = floor((availableWidth - (spacing * 3)) / 4)
        return (buttonSize * 4) + (spacing * 3)
    }

    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 8
            let horizontalPadding: CGFloat = 24
            let availableWidth = geometry.size.width - (horizontalPadding * 2)
            let buttonSize = floor((availableWidth - (spacing * 3)) / 4)
            let keypadHeight = (buttonSize * 4) + (spacing * 3)

            HStack(spacing: spacing) {
                VStack(spacing: spacing) {
                    ForEach([["7", "8", "9"], ["4", "5", "6"], ["1", "2", "3"], [".", "0", onToggleSign == nil ? "" : "+/-"]], id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(row, id: \.self) { value in
                                if value.isEmpty {
                                    Color.clear.frame(width: buttonSize, height: buttonSize)
                                } else {
                                    Button {
                                        impact(.light)
                                        if value == "+/-" {
                                            onToggleSign?()
                                        } else {
                                            appendValue(value == "." ? "." : value)
                                        }
                                    } label: {
                                        NumericPadButtonContent(label: value == "." ? Locale.current.decimalSeparator ?? "." : value, fontSize: value == "+/-" ? 24 : 38)
                                            .frame(width: buttonSize, height: buttonSize)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(width: buttonSize * 3 + spacing * 2, height: keypadHeight)

                VStack(spacing: spacing) {
                    Button {
                        impact(.heavy)
                        onClear()
                    } label: {
                        NumericPadButtonContent(label: "AC", fontSize: 30, foregroundColor: Color(red: 0.75, green: 0.46, blue: 0), tint: AppColor.accent.opacity(0.20), fallbackOpacity: 0.24)
                            .frame(width: buttonSize, height: buttonSize * 2 + spacing)
                    }

                    Button {
                        impact(.light)
                        onBackspace()
                    } label: {
                        NumericPadButtonContent(iconName: "delete", fontSize: 32, tint: AppColor.accent.opacity(0.72), fallbackOpacity: 0.72)
                            .frame(width: buttonSize, height: buttonSize * 2 + spacing)
                    }
                    .accessibilityLabel("Delete")
                }
                .frame(width: buttonSize, height: keypadHeight)
            }
            .frame(width: (buttonSize * 4) + (spacing * 3), height: keypadHeight)
            .buttonStyle(PressableButtonStyle(cornerRadius: 25))
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .frame(height: Self.contentHeight)
    }
}

private struct ResolvedSafeAreaInsets {
    let top: CGFloat
    let bottom: CGFloat
}

private extension GeometryProxy {
    var resolvedSafeAreaInsets: ResolvedSafeAreaInsets {
        if #available(iOS 17.0, *) {
            return ResolvedSafeAreaInsets(top: safeAreaInsets.top, bottom: safeAreaInsets.bottom)
        }
        let fallbackBottom = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.bottom ?? 20
        return ResolvedSafeAreaInsets(top: 52, bottom: fallbackBottom)
    }
}

private struct NumericPadButtonContent: View {
    var label: String?
    var iconName: String?
    let fontSize: CGFloat
    var foregroundColor: Color = .white
    var tint: Color = Color.white.opacity(0.08)
    var fallbackOpacity: Double = 0.16

    var body: some View {
        ZStack {
            if let iconName {
                AppIcon(name: iconName, size: fontSize, color: foregroundColor)
            } else {
                Text(label ?? "")
                    .font(.system(size: fontSize, weight: .regular))
                    .foregroundColor(foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appGlass(cornerRadius: 25, tint: tint, interactive: false, fallbackOpacity: fallbackOpacity)
        .contentShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
    }
}

// MARK: - History

struct HistorySheet: View {
    @EnvironmentObject private var historyStore: CalculationHistoryStore
    let onSelect: (String) -> Void
    let onClose: () -> Void
    @State private var confirmClear = false
    @State private var copiedEntryID: String?

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(red: 0.33, green: 0.33, blue: 0.33))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 4)

            HStack {
                Text("History")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: onClose) {
                    AppIcon(name: "x", size: 20, color: .gray)
                        .frame(width: 36, height: 36)
                        .appGlassCircle(tint: Color.white.opacity(0.04), interactive: true, fallbackOpacity: 0.08)
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .overlay(Rectangle().fill(Color(red: 0.2, green: 0.2, blue: 0.2)).frame(height: 0.5), alignment: .bottom)

            if historyStore.entries.isEmpty {
                VStack(spacing: 12) {
                    AppIcon(name: "clock", size: 48, color: Color(red: 0.33, green: 0.33, blue: 0.33))
                    Text("No calculations yet")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.33, green: 0.33, blue: 0.33))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                    ForEach(groupedHistory, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)

                            ForEach(section.entries) { entry in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.expression)
                                        .font(.system(size: 15))
                                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                                    Text("= \(entry.displayResult)")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .appGlass(cornerRadius: 14, tint: Color.white.opacity(0.04), interactive: true, fallbackOpacity: 0.08)
                                .padding(.horizontal, 20)
                                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .accessibilityElement(children: .combine)
                                .accessibilityAddTraits(.isButton)
                                .onTapGesture {
                                    guard copiedEntryID != entry.id else {
                                        copiedEntryID = nil
                                        return
                                    }
                                    onSelect(entry.expression)
                                }
                                .onLongPressGesture(minimumDuration: 0.45) {
                                    copiedEntryID = entry.id
                                    success()
                                    UIPasteboard.general.string = entry.displayResult
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                        if copiedEntryID == entry.id {
                                            copiedEntryID = nil
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                    .padding(.vertical, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(AppColor.background)

                Button {
                    confirmClear = true
                } label: {
                    HStack(spacing: 8) {
                        AppIcon(name: "trash2", size: 16, color: Color(red: 1, green: 0.27, blue: 0.27))
                        Text("Clear History")
                    }
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 1, green: 0.27, blue: 0.27))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .appGlass(cornerRadius: 16, tint: Color.red.opacity(0.06), interactive: true, fallbackOpacity: 0.08)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
            }
        }
        .background(AppColor.background.ignoresSafeArea(edges: .bottom))
        .alert("Clear History", isPresented: $confirmClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { historyStore.clear() }
        } message: {
            Text("Remove all calculation history?")
        }
    }

    private var groupedHistory: [(title: String, entries: [CalculationEntry])] {
        let calendar = Calendar.current
        var groups: [(String, [CalculationEntry])] = []
        for entry in historyStore.entries {
            let title: String
            if calendar.isDateInToday(entry.timestamp) {
                title = "Today"
            } else if calendar.isDateInYesterday(entry.timestamp) {
                title = "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .long
                title = formatter.string(from: entry.timestamp)
            }

            if let index = groups.firstIndex(where: { $0.0 == title }) {
                groups[index].1.append(entry)
            } else {
                groups.append((title, [entry]))
            }
        }
        return groups.map { (title: $0.0, entries: $0.1) }
    }
}

// MARK: - Haptics

private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}

private func success() {
    UINotificationFeedbackGenerator().notificationOccurred(.success)
}
