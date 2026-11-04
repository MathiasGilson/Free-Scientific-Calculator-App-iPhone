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

// Selecting a row takes effect at once. Standard button styles fade the row for half a second.
private func withoutAnimation(_ changes: () -> Void) {
    var transaction = Transaction(animation: nil)
    transaction.disablesAnimations = true
    withTransaction(transaction, changes)
}

private struct InstantButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
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

    /// The box behind the row that is receiving input: unit rows, tool fields and currency rows.
    /// A plain fill, because glass cannot get this faint on the black background. It extends past
    /// the row so the text keeps lining up with the rows around it.
    func appActiveRow(_ isActive: Bool, cornerRadius: CGFloat = 12) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let opacity = isActive ? 0.072 : 0
        return background(
            shape.fill(Color.white.opacity(opacity))
                .overlay(shape.stroke(Color.white.opacity(opacity), lineWidth: 0.8))
                .padding(.horizontal, -8)
                .padding(.vertical, -ToolDetailLayout.activeRowOverhang)
        )
        // Keeps the box from crowding the rows above and below it.
        .padding(.vertical, isActive ? 8 : 0)
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
    /// Unit labels per unit tool, in the order the user dragged them into.
    @Published private(set) var unitOrders: [String: [String]] {
        didSet { saveUnitOrders() }
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
    private let unitOrderKey: String

    init(
        userDefaults: UserDefaults = .standard,
        key: String = "pinnedConverterTools",
        toolOrderKey: String = "converterToolOrder",
        unitOrderKey: String = "converterUnitOrder"
    ) {
        self.defaults = userDefaults
        self.key = key
        self.toolOrderKey = toolOrderKey
        self.unitOrderKey = unitOrderKey
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

        if
            let data = defaults.data(forKey: unitOrderKey),
            let decoded = try? JSONDecoder().decode([String: [String]].self, from: data)
        {
            unitOrders = decoded
        } else {
            unitOrders = [:]
        }
    }

    func orderedUnits(for tool: ConverterTool) -> [UnitDefinition] {
        ConverterCore.orderedUnits(tool.units, savedOrder: unitOrders[tool.key] ?? [])
    }

    /// Called on every drag update; only a real move should re-render and persist.
    func setUnitOrder(_ labels: [String], for toolKey: String) {
        guard unitOrders[toolKey] != labels else { return }
        unitOrders[toolKey] = labels
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
        let knownKeys = Set(ConverterTool.all.map(\.key)).union(["_calculator"])
        let tabs = order.filter { key in
            // A pin saved for a tool that no longer exists, such as BMI, would be a blank page.
            guard knownKeys.contains(key), !seen.contains(key) else { return false }
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

    private func saveUnitOrders() {
        guard let data = try? JSONEncoder().encode(unitOrders) else { return }
        defaults.set(data, forKey: unitOrderKey)
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
    // Selected by key: pinning shifts every page's index, which must not move the user.
    @State private var selectedPage = "_calculator"
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

            TabView(selection: $selectedPage) {
                ForEach(appState.screenOrder, id: \.self) { key in
                    pagerScreen(for: key)
                        .tag(key)
                }

                ConverterGridScreen(onOpenTool: openGridTool)
                    .tag(Self.converterPage)
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
            .onChange(of: selectedPage) { _ in
                if selectedPage != Self.converterPage, !appState.isRearrangingTools {
                    appState.draggedToolKey = nil
                    activeGridTool = nil
                } else if selectedPage != Self.converterPage {
                    appState.draggedToolKey = nil
                    appState.endRearrangingTools()
                }
                showToolbarBriefly()
            }
            .onChange(of: appState.screenOrder) { order in
                if selectedPage != Self.converterPage, !order.contains(selectedPage) {
                    selectedPage = Self.converterPage
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
        .sheet(isPresented: $historyVisible) {
            HistorySheet(
                onSelect: { expression in
                    calculatorModel.setExpression(expression)
                    historyVisible = false
                    selectedPage = "_calculator"
                },
                onClose: { historyVisible = false }
            )
            .environmentObject(historyStore)
        }
    }

    private static let converterPage = "_converter"

    private var pageIndex: Int {
        appState.screenOrder.firstIndex(of: selectedPage) ?? converterPageIndex
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
    @State private var dragOrigin = CGPoint.zero
    @State private var dragTranslation = CGSize.zero

    private static let iconWidth: CGFloat = 40
    private static let barHeight: CGFloat = 36

    var body: some View {
        let tabs = appState.screenOrder + ["_converter"]

        bar(tabs: tabs)
        .padding(.horizontal, 6)
        .appGlass(cornerRadius: 18, tint: Color.white.opacity(0.04), fallbackOpacity: 0.08)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onChange(of: appState.isRearrangingTools) { isRearranging in
            if !isRearranging {
                finishDrag()
            }
        }
    }

    private func bar(tabs: [String]) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, key in
                let isActive = activeTabKey == key
                tabIcon(key: key, index: index)
                    .overlay(
                        ReorderTouchSurface(
                            isRearranging: appState.isRearrangingTools,
                            onDragBegan: { beginDrag(key: key, at: index) },
                            onDragChanged: { updateDrag($0, tabs: tabs) },
                            onDragEnded: finishDrag
                        )
                    )
                    .scaleEffect(isActive ? 1.25 : 1)
                    .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isActive)
                    .position(position(for: index, isActive: isActive))
                    .shadow(color: isActive ? Color.black.opacity(0.35) : .clear, radius: 12, x: 0, y: 8)
                    .zIndex(isActive ? 10 : 1)
                    .animation(isActive ? nil : .interactiveSpring(response: 0.22, dampingFraction: 0.84), value: tabs)
            }
        }
        .frame(width: barWidth(tabCount: tabs.count), height: Self.barHeight)
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

    private func beginDrag(key: String, at index: Int) {
        // The bar also flashes while paging, but only the grid can exit rearranging.
        guard pageIndex == appState.screenOrder.count else { return }
        if !appState.isRearrangingTools {
            impact(.heavy)
            appState.beginRearrangingTools()
        }
        guard canDrag(key) else { return }
        appState.draggedToolKey = key
        activeTabKey = key
        dragOrigin = slotCenter(for: index)
        dragTranslation = .zero
    }

    private func updateDrag(_ translation: CGSize, tabs: [String]) {
        guard let activeTabKey else { return }
        dragTranslation = translation

        let targetIndex = tabIndex(for: activeCenter().x, tabCount: tabs.count)
        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.84)) {
            appState.moveToolbarTab(activeTabKey, to: targetIndex)
        }
    }

    private func finishDrag() {
        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.84)) {
            activeTabKey = nil
        }
        appState.draggedToolKey = nil
        dragTranslation = .zero
    }

    private func position(for index: Int, isActive: Bool) -> CGPoint {
        isActive ? activeCenter() : slotCenter(for: index)
    }

    private func activeCenter() -> CGPoint {
        CGPoint(x: dragOrigin.x + dragTranslation.width, y: dragOrigin.y + dragTranslation.height)
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

    // One structure in both states: swapping branches rebuilds the views around the content,
    // and with them a touch surface whose touch started the shaking.
    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: nil, paused: !active)) { timeline in
            content
                .rotationEffect(.degrees(active ? angle(at: timeline.date) : 0))
                .transaction { transaction in
                    transaction.animation = nil
                }
        }
        .onChange(of: active) { isActive in
            if isActive {
                shakeStart = Date()
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
            // RootView ends rearranging when the user pages away.
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
    @State private var pressedToolKey: String?
    @State private var dragOrigin = CGPoint.zero
    @State private var dragTranslation = CGSize.zero
    @State private var blockToolbarPlacementUntil = Date.distantPast
    @State private var pinToggleLockedUntil = Date.distantPast

    private static let columnCount = 4
    private static let columnSpacing: CGFloat = 14
    private static let rowSpacing: CGFloat = 18
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
        .onChange(of: appState.isRearrangingTools) { isRearranging in
            if !isRearranging {
                finishDrag()
            }
        }
    }

    @ViewBuilder
    private func toolInteraction(for tool: ConverterTool, at index: Int) -> some View {
        let isActive = activeToolKey == tool.key
        let isPressed = pressedToolKey == tool.key
        let card = ConverterToolCard(
            tool: tool,
            rearranging: appState.isRearrangingTools && !isActive,
            pinned: appState.isToolPinned(tool.key),
            pressed: isPressed
        )
        .frame(width: itemSize, height: itemSize)
        .overlay(
            ReorderTouchSurface(
                isRearranging: appState.isRearrangingTools,
                onPressChanged: { pressing in
                    pressedToolKey = pressing ? tool.key : nil
                },
                onTap: {
                    if appState.isRearrangingTools {
                        handlePinTap(tool)
                    } else {
                        onSelect(tool)
                    }
                },
                onDragBegan: { beginDrag(toolKey: tool.key, at: index) },
                onDragChanged: updateDrag,
                onDragEnded: endDrag
            )
        )
        .scaleEffect(cardScale(isActive: isActive, isPressed: isPressed))
        // Snap down fast on press; ease back up gently.
        .animation(.easeOut(duration: isPressed ? 0.05 : 0.18), value: isPressed)
        .animation(.spring(response: 0.28, dampingFraction: 0.62), value: appState.isRearrangingTools)
        .animation(.spring(response: 0.28, dampingFraction: 0.62), value: isActive)

        // NOTE: position cards with `.position`, not `.offset`. `.offset` is a
        // render-only transform that does not move a view's hit-testing frame,
        // so every card's touches collapse onto the un-offset top-leading slot
        // and only the topmost card in the ZStack ever responds. `.position`
        // is layout-based, so hit-testing follows the card to its slot.
        card
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

    private func positionPoint(for index: Int, isActive: Bool) -> CGPoint {
        isActive ? activeCenter() : slotCenter(for: index)
    }

    /// Scale a grid card: lifted while dragged, pressed-down while held, and
    /// nudged up in rearrange mode so it visibly reads as "movable".
    private func cardScale(isActive: Bool, isPressed: Bool) -> CGFloat {
        if isActive { return 1.2 }
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

    private func beginDrag(toolKey: String, at index: Int) {
        if !appState.isRearrangingTools {
            impact(.heavy)
            appState.beginRearrangingTools()
        }
        appState.draggedToolKey = toolKey
        activeToolKey = toolKey
        dragOrigin = slotCenter(for: index)
        dragTranslation = .zero
    }

    private func updateDrag(_ translation: CGSize) {
        guard let activeToolKey else { return }
        dragTranslation = translation

        let targetIndex = index(for: activeCenter())
        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.82)) {
            appState.moveTool(activeToolKey, to: targetIndex)
        }
    }

    private func endDrag() {
        if let activeToolKey, dragTranslation.height <= -Self.toolbarDropDragThreshold {
            placeInShortcutBarIfNeeded(activeToolKey, center: activeCenter())
        }
        finishDrag()
    }

    private func finishDrag() {
        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.82)) {
            activeToolKey = nil
        }
        appState.draggedToolKey = nil
        dragTranslation = .zero
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
        CGPoint(x: dragOrigin.x + dragTranslation.width, y: dragOrigin.y + dragTranslation.height)
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

/// Carries one touch from press to drop, the way the iOS home screen does. A SwiftUI drag added once
/// rearranging begins never sees the touch that started it, so the recognizers live here for good:
/// a long press keeps reporting movement after it fires, and a swipe that moves first still reaches the pager.
private struct ReorderTouchSurface: UIViewRepresentable {
    let isRearranging: Bool
    var onPressChanged: (Bool) -> Void = { _ in }
    var onTap: () -> Void = {}
    /// Replaces `onTap` for a surface covering several targets, such as a currency row's code and amount.
    var onTapAt: ((CGPoint) -> Void)?
    let onDragBegan: () -> Void
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(surface: self)
    }

    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        view.isExclusiveTouch = true // a second finger must not start a second drag
        let coordinator = context.coordinator

        view.addGestureRecognizer(UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleTap)))

        let hold = UILongPressGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleDrag))
        hold.minimumPressDuration = 0.42
        hold.allowableMovement = 28
        view.addGestureRecognizer(hold)

        let move = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.handleDrag))
        move.delegate = coordinator
        move.isEnabled = isRearranging
        view.addGestureRecognizer(move)
        coordinator.move = move

        view.onPressChanged = onPressChanged
        return view
    }

    func updateUIView(_ view: TouchView, context: Context) {
        context.coordinator.surface = self
        context.coordinator.move?.isEnabled = isRearranging
        view.onPressChanged = onPressChanged
    }

    final class TouchView: UIView {
        var onPressChanged: (Bool) -> Void = { _ in }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event)
            onPressChanged(true)
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesEnded(touches, with: event)
            onPressChanged(false)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesCancelled(touches, with: event)
            onPressChanged(false)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var surface: ReorderTouchSurface
        weak var move: UIPanGestureRecognizer?
        private var dragStart = CGPoint.zero

        init(surface: ReorderTouchSurface) {
            self.surface = surface
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            if let onTapAt = surface.onTapAt {
                onTapAt(recognizer.location(in: recognizer.view))
            } else {
                surface.onTap()
            }
        }

        @objc func handleDrag(_ recognizer: UIGestureRecognizer) {
            let location = recognizer.location(in: nil)
            switch recognizer.state {
            case .began:
                dragStart = location
                surface.onDragBegan()
            case .changed:
                surface.onDragChanged(CGSize(width: location.x - dragStart.x, height: location.y - dragStart.y))
            case .ended, .cancelled, .failed:
                surface.onDragEnded()
            default:
                break
            }
        }

        // While rearranging, a card under the finger moves rather than the page.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            otherGestureRecognizer.view is UIScrollView
        }
    }
}

// MARK: - Vertical List Reordering

/// Lets the rows of a vertical list be held and dragged into a new order, the way the tool grid is.
/// Rows differ in height (the active row is taller), so the order comes from their measured heights
/// rather than from frames read back after each move, which trail the finger by a layout pass.
private final class VerticalReorderModel: ObservableObject {
    @Published private(set) var draggedID: String?
    @Published private(set) var draggedOffset: CGFloat = 0

    var heights: [String: CGFloat] = [:]
    private var order: [String] = []
    private var startTop: CGFloat = 0

    func begin(_ id: String, order: [String]) {
        guard order.contains(id) else { return }
        impact(.medium)
        self.order = order
        startTop = top(of: id, in: order)
        draggedID = id
        draggedOffset = 0
    }

    /// Returns the order that puts the dragged row where the finger is, or nil while it stays put.
    func update(translation: CGFloat) -> [String]? {
        guard let draggedID else { return nil }
        let center = startTop + translation + height(of: draggedID) / 2

        var next = order.filter { $0 != draggedID }
        var insertion = next.count
        var top: CGFloat = 0
        for (index, id) in next.enumerated() {
            if center < top + height(of: id) / 2 {
                insertion = index
                break
            }
            top += height(of: id)
        }
        next.insert(draggedID, at: insertion)

        // The row's slot moves when the order changes; the offset keeps it under the finger.
        draggedOffset = startTop + translation - self.top(of: draggedID, in: next)
        guard next != order else { return nil }
        order = next
        return next
    }

    func end() {
        draggedID = nil
        draggedOffset = 0
    }

    private func height(of id: String) -> CGFloat {
        heights[id] ?? 0
    }

    private func top(of id: String, in order: [String]) -> CGFloat {
        order.prefix { $0 != id }.reduce(0) { $0 + height(of: $1) }
    }
}

private struct VerticalReorderHeightsKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] { [:] }

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct VerticalReorderRow: ViewModifier {
    let id: String
    let order: [String]
    @ObservedObject var model: VerticalReorderModel
    let onReorder: ([String]) -> Void
    let onTap: (CGPoint) -> Void

    private static let animation = Animation.interactiveSpring(response: 0.24, dampingFraction: 0.82)

    func body(content: Content) -> some View {
        let dragged = model.draggedID == id
        let index = order.firstIndex(of: id) ?? 0

        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: VerticalReorderHeightsKey.self, value: [id: proxy.size.height])
                }
            )
            .overlay(
                ReorderTouchSurface(
                    isRearranging: false,
                    onTapAt: onTap,
                    onDragBegan: { model.begin(id, order: order) },
                    onDragChanged: { translation in
                        guard let next = model.update(translation: translation.height) else { return }
                        impact(.light)
                        withAnimation(Self.animation) { onReorder(next) }
                    },
                    onDragEnded: {
                        withAnimation(Self.animation) { model.end() }
                    }
                )
            )
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(red: 0.17, green: 0.17, blue: 0.17))
                    .padding(.horizontal, -8)
                    .opacity(dragged ? 1 : 0)
            )
            .scaleEffect(dragged ? 1.03 : 1)
            .shadow(color: dragged ? Color.black.opacity(0.38) : .clear, radius: 14, x: 0, y: 10)
            .offset(y: dragged ? model.draggedOffset : 0)
            .zIndex(dragged ? 1 : 0)
            // The lifted row follows the finger exactly; only the rows it passes animate.
            .transaction { transaction in
                if dragged { transaction.animation = nil }
            }
            .accessibilityAction(named: "Move up") {
                guard index > 0 else { return }
                onReorder(Self.moving(order, from: index, to: index - 1))
            }
            .accessibilityAction(named: "Move down") {
                guard index < order.count - 1 else { return }
                onReorder(Self.moving(order, from: index, to: index + 1))
            }
    }

    private static func moving(_ order: [String], from source: Int, to destination: Int) -> [String] {
        var next = order
        next.insert(next.remove(at: source), at: destination)
        return next
    }
}

private extension View {
    /// One row of a list that `VerticalReorderModel` reorders. The row's own taps arrive through `onTap`,
    /// since the surface that catches the hold also catches every other touch on the row.
    func verticalReorderRow(
        id: String,
        order: [String],
        model: VerticalReorderModel,
        onReorder: @escaping ([String]) -> Void,
        onTap: @escaping (CGPoint) -> Void
    ) -> some View {
        modifier(VerticalReorderRow(id: id, order: order, model: model, onReorder: onReorder, onTap: onTap))
    }

    /// Hands the measured row heights of a reorderable list to its model.
    func verticalReorderList(_ model: VerticalReorderModel) -> some View {
        onPreferenceChange(VerticalReorderHeightsKey.self) { heights in
            model.heights = heights
        }
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
        } else if tool.key == "tip" {
            TipCalculatorScreen(onBack: onBack)
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
    static let activeRowOverhang: CGFloat = 5

    static func contentTopInset(hasBackButton: Bool) -> CGFloat {
        hasBackButton ? 0 : pinnedContentTopExtra
    }
}

struct UnitConverterScreen: View {
    let tool: ConverterTool
    let onBack: (() -> Void)?

    @EnvironmentObject private var appState: ConvCalcAppState
    @StateObject private var reorder = VerticalReorderModel()
    @State private var input = "1"
    @State private var inputEdited = false
    // Kept by label so the typed value stays on its unit when the rows are reordered.
    @State private var activeLabel: String?

    private var units: [UnitDefinition] {
        appState.orderedUnits(for: tool)
    }

    /// The unit being typed into: the one last tapped, else the top of the user's order.
    private var fromIndex: Int {
        units.firstIndex { $0.label == activeLabel } ?? 0
    }

    private var results: [ConversionResult] {
        ConverterCore.convertToAll(value: Double(input) ?? 0, fromIndex: fromIndex, units: units)
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
                    let order = results.map(\.id)
                    VStack(spacing: 0) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                            Button {
                                select(result.label)
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
                                .appActiveRow(index == fromIndex)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(InstantButtonStyle())
                            .accessibilityValue(index == fromIndex ? "Active" : "")
                            .verticalReorderRow(
                                id: result.id,
                                order: order,
                                model: reorder,
                                onReorder: reorderUnits,
                                onTap: { _ in select(result.label) }
                            )
                        }
                    }
                    .verticalReorderList(reorder)
                    .padding(.horizontal, 16)
                    .padding(.top, topPadding)
                    .padding(.vertical, ToolDetailLayout.activeRowOverhang)
                }
                // Room for the active row's box, which the scroll view would clip, without moving the rows.
                .padding(.top, -ToolDetailLayout.activeRowOverhang)

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

    private var activeUnitLabel: String? {
        units.indices.contains(fromIndex) ? units[fromIndex].label : nil
    }

    private func select(_ label: String) {
        guard label != activeUnitLabel else { return }
        withoutAnimation {
            activeLabel = label
            input = "1"
            inputEdited = false
        }
    }

    private func reorderUnits(_ labels: [String]) {
        // Pin the active unit first, so moving another unit to the top doesn't take over the input.
        if activeLabel == nil {
            activeLabel = activeUnitLabel
        }
        appState.setUnitOrder(labels, for: tool.key)
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
                                withoutAnimation {
                                    activeField = field.key
                                }
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
                                .appActiveRow(activeField == field.key)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(InstantButtonStyle())
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
                    .padding(.vertical, ToolDetailLayout.activeRowOverhang)
                }
                // Room for the active row's box, which the scroll view would clip, without moving the rows.
                .padding(.top, -ToolDetailLayout.activeRowOverhang)

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

// MARK: - Tip

struct TipCalculatorScreen: View {
    let onBack: (() -> Void)?

    private enum Input {
        case bill, customPercent
    }

    private static let presets = [10, 15, 18, 20]
    private static let maxPeople = 99
    // Keeps every amount on screen in full, and is well beyond any real restaurant bill.
    private static let maxBillLength = 9
    private static let maxPercentLength = 5
    private static let mutedText = Color(red: 0.6, green: 0.6, blue: 0.6)

    @State private var input = Input.bill
    @State private var bill = "0"
    @State private var billEdited = false
    @State private var preset: Int? = 15
    @State private var customPercent = ""
    @State private var customEdited = false
    @State private var hitTipLimit = false
    @State private var people = 1

    private var result: TipResult {
        let percent = preset.map(Double.init) ?? Double(customPercent) ?? 0
        return ConverterCore.calculateTip(bill: Double(bill) ?? 0, tipPercent: percent, people: people)
            ?? TipResult(tip: 0, total: 0, perPerson: 0, billShare: 0, tipShare: 0)
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
                        billRow
                        tipSection
                        peopleRow
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 0.5)
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                        results
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, topPadding)
                    .padding(.vertical, ToolDetailLayout.activeRowOverhang)
                }
                .padding(.top, -ToolDetailLayout.activeRowOverhang)
                .staysPutWhenContentFits()

                NumericKeypad(appendValue: appendValue, onClear: clear, onBackspace: backspace)
                    .padding(.top, 16)
                    .padding(.bottom, bottomInset > 0 ? max(10, bottomInset - 16) : 10)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.ignoresSafeArea(edges: .bottom))
    }

    private var billRow: some View {
        Button {
            withoutAnimation {
                input = .bill
                billEdited = false
            }
        } label: {
            HStack {
                Text("Bill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(input == .bill ? .white : Self.mutedText)
                Spacer(minLength: 8)
                Text(CalculatorNumberFormat.typedNumber(bill))
                    .font(.system(size: 26))
                    .foregroundColor(input == .bill ? AppColor.accent : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .appActiveRow(input == .bill)
            // Matches the active row's margin, so moving the keypad elsewhere doesn't shift the screen.
            .padding(.vertical, input == .bill ? 0 : 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(InstantButtonStyle())
        .accessibilityValue(input == .bill ? "Active" : "")
    }

    private var tipSection: some View {
        VStack(spacing: 10) {
            amountRow(tipRowLabel, result.tip, labelColor: isTypingPercent ? AppColor.accent : Self.mutedText)
            HStack(spacing: 8) {
                ForEach(Self.presets, id: \.self) { percent in
                    tipChip(label: "\(percent)%", selected: preset == percent) {
                        preset = percent
                        hitTipLimit = false
                        if input != .bill {
                            input = .bill
                            billEdited = false
                        }
                    } content: {
                        Text("\(percent)%")
                    }
                }
                tipChip(label: otherChipLabel, selected: preset == nil, typing: isTypingPercent) {
                    preset = nil
                    input = .customPercent
                    customEdited = false
                } content: {
                    if isTypingPercent {
                        HStack(spacing: 1) {
                            Text(customPercent)
                            TypingCaret()
                            Text("%")
                        }
                    } else {
                        Text(otherChipLabel)
                    }
                }
                // Room for the longest percentage, and it reads as the field being typed in.
                .frame(width: isTypingPercent ? 92 : nil)
            }
            .padding(.horizontal, 12)
        }
        .padding(.top, 6)
    }

    private var isTypingPercent: Bool {
        input == .customPercent
    }

    private var tipRowLabel: String {
        guard isTypingPercent else { return "Tip" }
        return hitTipLimit ? "Maximum tip is 100%" : "Type tip percentage"
    }

    private var otherChipLabel: String {
        customPercent.isEmpty ? "Other" : "\(customPercent)%"
    }

    private func tipChip<Content: View>(
        label: String,
        selected: Bool,
        typing: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            withoutAnimation(action)
        } label: {
            content()
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(selected ? AppColor.accent : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(shape.fill(selected ? AppColor.accent.opacity(0.2) : Color.white.opacity(0.072)))
                .overlay(shape.stroke(AppColor.accent, lineWidth: typing ? 1.5 : 0))
                .contentShape(Rectangle())
        }
        .buttonStyle(InstantButtonStyle())
        .accessibilityLabel(label)
        .accessibilityValue(typing ? "Typing" : selected ? "Selected" : "")
    }

    private var peopleRow: some View {
        HStack(spacing: 0) {
            Text("People")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Self.mutedText)
            Spacer(minLength: 8)
            stepperButton(icon: "minus", label: "Remove person", enabled: people > 1) {
                people -= 1
            }
            Text("\(people)")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white)
                .frame(minWidth: 48)
                .accessibilityLabel("\(people) people")
            stepperButton(icon: "plus", label: "Add person", enabled: people < Self.maxPeople) {
                people += 1
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }

    private func stepperButton(icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            impact(.light)
            withoutAnimation(action)
        } label: {
            AppIcon(name: icon, size: 20, color: .white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.072)))
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle(cornerRadius: 22))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var results: some View {
        if people > 1 {
            amountRow("Total", result.total)
                .padding(.top, 10)
        }
        HStack(alignment: .firstTextBaseline) {
            Text(people > 1 ? "Each person pays" : "Total")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
            Spacer(minLength: 8)
            Text(Self.money(people > 1 ? result.perPerson : result.total))
                .font(.system(size: 40))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        Text("\(Self.money(result.billShare)) bill + \(Self.money(result.tipShare)) tip")
            .font(.system(size: 15))
            .foregroundColor(Self.mutedText)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
    }

    private func amountRow(_ label: String, _ amount: Double, labelColor: Color = TipCalculatorScreen.mutedText) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            Text(Self.money(amount))
                .font(.system(size: 18))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
    }

    private static func money(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    private func appendValue(_ value: String) {
        withoutAnimation {
            switch input {
            case .bill:
                bill = Self.appending(value, to: bill, edited: billEdited, maxLength: Self.maxBillLength)
                billEdited = true
            case .customPercent:
                let next = Self.appending(value, to: customPercent, edited: customEdited, maxLength: Self.maxPercentLength)
                hitTipLimit = (Double(next) ?? 0) > ConverterCore.maxTipPercent
                guard !hitTipLimit else { return }
                customPercent = next
                customEdited = true
            }
        }
    }

    private static func appending(_ value: String, to current: String, edited: Bool, maxLength: Int) -> String {
        guard edited else { return value == "." ? "0." : value }
        if value == ".", current.contains(".") { return current }
        guard current.count < maxLength else { return current }
        let next = current == "0" && value != "." ? value : current + value
        return CalculatorNumberFormat.limitingFraction(of: next, to: 2)
    }

    private func backspace() {
        withoutAnimation {
            switch input {
            case .bill:
                bill = bill.count <= 1 ? "0" : String(bill.dropLast())
                billEdited = true
            case .customPercent:
                customPercent = String(customPercent.dropLast())
                customEdited = true
                hitTipLimit = false
            }
        }
    }

    private func clear() {
        withoutAnimation {
            switch input {
            case .bill:
                bill = "0"
                billEdited = true
            case .customPercent:
                customPercent = ""
                customEdited = true
                hitTipLimit = false
            }
        }
    }
}

private struct TypingCaret: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let isVisible = Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            RoundedRectangle(cornerRadius: 1)
                .fill(AppColor.accent)
                .frame(width: 2, height: 20)
                .opacity(isVisible ? 1 : 0)
        }
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
    @StateObject private var reorder = VerticalReorderModel()

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
                        // Keyed by code so a dragged row keeps its identity, and its touch, as it moves.
                        ForEach(Array(currencyRates.displayedCurrencies.enumerated()), id: \.element) { index, code in
                            currencyRow(code: code, index: index, compact: compact)
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
                        .padding(.bottom, 4)
                    }
                    .verticalReorderList(reorder)
                    .padding(.horizontal, 20)
                    .padding(.top, topPadding)
                    .padding(.top, ToolDetailLayout.activeRowOverhang)
                }
                .padding(.top, -ToolDetailLayout.activeRowOverhang)
                .staysPutWhenContentFits()

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
                    .font(.system(size: 20, weight: .semibold))
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
                        .font(.system(size: compact ? 28 : 34, weight: .regular))
                        .foregroundColor(isActive ? AppColor.accent : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Text(info?.name ?? code)
                        .font(.system(size: compact ? 13 : 15))
                        .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.35))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .buttonStyle(InstantButtonStyle())
            .accessibilityValue(isActive ? "Active" : "")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, compact ? 4 : 8)
        .appActiveRow(isActive, cornerRadius: 18)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .verticalReorderRow(
            id: code,
            order: currencyRates.displayedCurrencies,
            model: reorder,
            onReorder: reorderCurrencies,
            onTap: { location in
                // Same split as the buttons: the code opens the picker, the rest of the row activates it.
                if location.x < Self.codeTapWidth {
                    pickerRowIndex = index
                    pickerVisible = true
                } else {
                    activateRow(index)
                }
            }
        )
    }

    /// The row's leading padding plus the code button.
    private static let codeTapWidth: CGFloat = 12 + 88

    private func reorderCurrencies(_ codes: [String]) {
        let activeCode = currencyRates.displayedCurrencies[activeCurrencyIndex]
        currencyRates.reorderCurrencies(codes)
        // The typed amount stays with its currency, wherever that row lands.
        activeCurrencyIndex = currencyRates.displayedCurrencies.firstIndex(of: activeCode) ?? 0
    }

    private func activateRow(_ index: Int) {
        guard index != activeCurrencyIndex else { return }
        withoutAnimation {
            activeCurrencyIndex = index
            activeAmount = "1"
            inputEdited = false
        }
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
    @FocusState private var searchFocused: Bool

    private static let drawerColor = Color(red: 0.11, green: 0.11, blue: 0.118)

    // A custom field because the system search bar always offers a button that closes the keyboard.
    var body: some View {
        currencyList
            .safeAreaInset(edge: .bottom, spacing: 0) {
                searchField
                    // Runs behind the keyboard too, so rows stop at the field instead of showing around the keys.
                    .background(Self.drawerColor.ignoresSafeArea())
            }
            .background(Self.drawerColor.ignoresSafeArea())
            .onAppear {
                searchFocused = true
            }
            .onChange(of: searchFocused) { focused in
                if !focused {
                    searchFocused = true
                }
            }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            AppIcon(name: "search", size: 18, color: .secondary)
            TextField("Search", text: $searchText)
                .focused($searchFocused)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    AppIcon(name: "x", size: 18, color: .secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .appGlass(cornerRadius: 22, tint: Color.white.opacity(0.06), fallbackOpacity: 0.12)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .pickerListChrome()
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

private extension View {
    /// A drag on content that fits must not leave it shifted, with the active row's box cut off.
    @ViewBuilder
    func staysPutWhenContentFits() -> some View {
        if #available(iOS 16.4, *) {
            self.scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }

    /// The list sits directly on the drawer, and scrolling it leaves the keyboard up.
    @ViewBuilder
    func pickerListChrome() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden).scrollDismissesKeyboard(.never)
        } else {
            self
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
