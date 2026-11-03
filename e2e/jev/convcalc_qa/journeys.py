"""Every user journey in ConvCalc. Jev gets only the goal; `expect` is asserted in code on the final screen,
because Jev reads text but is weak at exact values. Drags need finger paths, so those are scripted."""

import time
from collections.abc import Callable
from dataclasses import dataclass, field

from .device import run


@dataclass(frozen=True)
class Journey:
    name: str
    goal: str = ""
    checkpoints: list[str] = field(default_factory=list)
    expect: list[str] = field(default_factory=list)
    forbid: list[str] = field(default_factory=list)
    before: Callable | None = field(default=None, compare=False)
    script: Callable | None = field(default=None, compare=False)
    verify: Callable | None = field(default=None, compare=False)
    locale: str | None = None
    gestures: bool = False  # offer Jev long-press actions
    expects_error: bool = False
    max_actions: int = 40


def to_currency(device):
    device.next_page()


def to_grid(device):
    device.next_page()
    device.next_page()


def open_tool(label):
    def go(device):
        to_grid(device)
        device.tap_label(label, exact=True)
        device.find("Back", exact=True)

    return go


def press(device, *labels):
    for label in labels:
        device.tap_label(label, exact=True)


def tab_order(device):
    tabs = sorted((e for e in device.settled() if e["label"].endswith(" tab")), key=lambda e: e["x"])
    return [e["label"].removesuffix(" tab") for e in tabs]


def tool_order(device):
    tools = [e for e in device.settled() if e["button"] and e["value"] in {"Pinned", "Not pinned", ""} and not e["label"].endswith(" tab")]
    return [e["label"] for e in sorted(tools, key=lambda e: (round(e["y"]), e["x"]))]


def expand_collapse_script(device):
    device.tap_label("Expand keypad", exact=True)
    device.find("sin", exact=True)
    device.tap_label("Collapse keypad", exact=True)


def keys(*labels):
    return lambda device: press(device, *labels)


def recovers_after_error_script(device):
    press(device, "5", "Divide", "0", "Equals")
    device.find("Invalid input")
    press(device, "All clear", "7")


def edit_chunk_script(device):
    press(device, "1", "2", "Plus", "3", "4")
    device.tap_label("12", exact=True)
    assert device.find("12", exact=True)["value"] == "Selected"
    press(device, "9", "Equals")


def hold_display(device, label):
    element = next(e for e in device.settled() if e["label"] == label and (e["chunk"] or not e["button"]))
    device.tap(element["x"], element["y"], duration=1.0)
    time.sleep(0.5)


def choose_paste(device):
    hold_display(device, "0")
    device.tap_label("Paste", exact=True)
    time.sleep(1)
    if any(e["label"] == "Allow Paste" for e in device.settled()):
        device.tap_label("Allow Paste", exact=True)
    time.sleep(0.5)


def paste_script(device):
    press(device, "1", "0", "0", "0")
    hold_display(device, "1,000")
    device.tap_label("Copy", exact=True)
    time.sleep(0.5)
    press(device, "All clear")
    choose_paste(device)


def temp_negative_script(device):
    device.tap_label("Celsius")
    press(device, "4", "0", "+/-")


def loan_zero_script(device):
    press(device, "1", "2", "0", "0")
    device.tap_label("Rate")
    press(device, "0")
    device.tap_label("Duration")
    press(device, "1")


CALCULATOR = [
    Journey("calc-arithmetic", "On the calculator keypad press 1, 2, Plus, 3, 0, then Equals.", ["The expression 12 + 30 is on the display", "The result 42 is shown"], [r"(?m)^42$"]),
    Journey("calc-precedence", "Calculate 2 plus 3 times 4 by pressing 2, Plus, 3, Multiply, 4, Equals.", ["A live result of 14 is previewed", "The final result 14 is shown"], [r"(?m)^14$"]),
    Journey("calc-parentheses", "Calculate (2+3) times 4: press Parentheses, 2, Plus, 3, Parentheses, Multiply, 4, Equals.", ["The result 20 is shown"], [r"(?m)^20$"]),
    Journey("calc-decimal", "Press 1, the decimal point, 5, Plus, 2, the decimal point, 2, 5, then Equals.", ["The result 3.75 is shown"], [r"(?m)^3\.75$"]),
    Journey("calc-percent-of-left-operand", script=keys("1", "0", "0", "Plus", "1", "0", "%", "Equals"), expect=[r"(?m)^110$"]),
    Journey("calc-divide-by-zero", "Press 5, Divide, 0, Equals. The app should say the input is invalid.", ["The display says Invalid input"], ["Invalid input"], expects_error=True),
    Journey("calc-recovers-after-error", script=recovers_after_error_script, expect=[r"(?m)^7$"], forbid=[r"Invalid input"]),
    Journey("calc-backspace", "Press 1, 2, 3, then Delete once.", ["The expression on the display is 12"], [r"(?m)^12$"], [r"(?m)^123$"]),
    Journey("calc-all-clear", script=keys("4", "5", "Plus", "6", "All clear"), expect=[r"(?m)^0$"], forbid=[r"(?m)^45$"]),
    Journey("calc-continue-from-result", "Press 2, Plus, 3, Equals. Then press Multiply, 4, Equals.", ["A result of 5 is shown", "A result of 20 is shown"], [r"(?m)^20$"]),
    Journey("calc-repeat-equals", "Press 2, Plus, 3, Equals, then press Equals two more times.", ["The result 5 is shown"], [r"(?m)^5$"], verify=lambda d: None),
    Journey("calc-empty-equals", script=keys("Equals"), expect=[r"(?m)^0$"], forbid=[r"Invalid input"]),
    Journey("calc-edit-number-chunk", script=edit_chunk_script, expect=[r"(?m)^43$"]),
    Journey("calc-replace-operator-chunk", "Press 6, Plus, 2. Tap the plus sign on the display to select it, then press Multiply. Then press Equals.", ["The result 12 is shown"], [r"(?m)^12$"]),
    Journey("calc-paste", script=paste_script, expect=[r"(?m)^1,000$"]),
    Journey("calc-copy-chunk", "Press 4, 2. Long-press the 42 on the display, then choose Copy from the menu.", [], [r"(?m)^42$"], gestures=True, verify=lambda d: None if d.pasteboard().strip() == "42" else f"Pasteboard is {d.pasteboard()!r}"),
    Journey("locale-french-decimals", "Press 1, Divide, 4, Equals.", ["The result 0,25 is shown"], [r"(?m)^0,25$"], locale="fr-FR"),
]

SCIENTIFIC = [
    Journey("sci-expand-collapse", script=expand_collapse_script, expect=["Expand keypad"], forbid=[r"(?m)^sin$"]),
    Journey("sci-sine-degrees", "Press Expand keypad, sin, 9, 0, Parentheses, Equals.", ["The result 1 is shown"], [r"(?m)^1$"]),
    Journey("sci-radians", "Press Expand keypad, press Degrees to switch to radians, then press sin, Pi, Divide, 2, Parentheses, Equals.", ["The angle key shows Radians", "The result 1 is shown"], [r"(?m)^1$", "Radians"]),
    Journey("sci-inverse", "Press Expand keypad, Inverse off, then the sine key, 1, Parentheses, Equals.", ["The result 90 is shown"], [r"(?m)^90$"]),
    Journey("sci-hyperbolic", "Press Expand keypad, Hyperbolic off, then the sine key, 0, Parentheses, Equals.", ["The result 0 is shown"], [r"(?m)^0$"]),
    Journey("sci-power", "Press Expand keypad, 2, Power, 1, 0, Equals.", ["The result 1,024 is shown"], [r"(?m)^1,024$"]),
    Journey("sci-square-root", "Press Expand keypad, Square root, 8, 1, Parentheses, Equals.", ["The result 9 is shown"], [r"(?m)^9$"]),
    Journey("sci-factorial", script=keys("Expand keypad", "5", "Factorial", "Equals"), expect=[r"(?m)^120$"]),
    Journey("sci-reciprocal", "Press Expand keypad, Reciprocal, 4, Equals.", ["The result 0.25 is shown"], [r"(?m)^0\.25$"]),
    Journey("sci-reciprocal-after-number", "Press Expand keypad, 5, Reciprocal, 2, Equals. The reciprocal key multiplies, so this is 5 times one half.", ["The result 2.5 is shown"], [r"(?m)^2\.5$"]),
    Journey("sci-implicit-pi", "Press Expand keypad, 2, Pi, Equals.", ["The result 6.28318530718 is shown"], [r"(?m)^6\.28318530718$"]),
    Journey("sci-euler", "Press Expand keypad, Natural logarithm, e, Parentheses, Equals.", ["The result 1 is shown"], [r"(?m)^1$"]),
    Journey("sci-log10", "Press Expand keypad, Logarithm base 10, 1, 0, 0, Parentheses, Equals.", ["The result 2 is shown"], [r"(?m)^2$"]),
    Journey("sci-rand", "Press Expand keypad, then Rand.", [], [r"(?m)^0\.\d{5}$"]),
    Journey("sci-huge-result-scientific", "Press Expand keypad, 1, 0, Power, 2, 0, Equals.", ["A result in scientific notation is shown"], [r"(?m)^1E20$"]),
]

HISTORY = [
    Journey("history-empty", "Press History.", ["The history sheet says No calculations yet"], ["No calculations yet"]),
    Journey("history-records-and-loads-expression", "Press 2, Plus, 3, Equals. Press History. Tap the entry 2+3 to load it. The history sheet should close and the calculator should show that expression.", ["The history sheet lists 2+3 = 5 under Today", "The calculator shows the expression 2 + 3"], [r"(?m)^\+$", "= 5"], ["Clear History"]),
    Journey("history-close", "Press 2, Plus, 3, Equals. Press History, then press Close.", ["The history sheet is open", "The calculator keypad is showing the result 5"], ["All clear"], ["Clear History"]),
    Journey("history-clear-cancel", "Press 2, Plus, 3, Equals. Press History, press Clear History, then press Cancel in the dialog.", ["A dialog asks to remove all calculation history", "The entry 2+3 is still listed"], [r"2\+3"]),
    Journey("history-clear-confirm", "Press 2, Plus, 3, Equals. Press History, press Clear History, then press Clear in the dialog.", ["A dialog asks to remove all calculation history", "The sheet says No calculations yet"], ["No calculations yet"]),
    Journey("history-session-entry-loads", "Press 2, Plus, 3, Equals, then 9, Plus, 1, Equals, then tap the older line '2+3 = 5' above the display.", ["Earlier calculations are listed above the display"], ["= 5"], before=None),
]

CURRENCY = [
    Journey("currency-convert", "On this currency screen press 1, 0, 0.", ["USD is the active row showing 100"], [r"100, US Dollar \(Active\)", r"Updated|Refreshing"], ["—"], before=to_currency),
    Journey("currency-decimal-entry", "Press 1, the decimal point, 0, 5.", ["The active amount is 1.05"], [r"1\.05, US Dollar \(Active\)"], before=to_currency),
    Journey("currency-decimal-limit", "Press 1, the decimal point, 2, 3, 4, 5. US dollars only keep two decimals.", [], [r"1\.23, US Dollar \(Active\)"], before=to_currency),
    Journey("currency-no-decimals-for-yen", "Tap the amount row for Japanese Yen to make it active. Press 5, the decimal point, 2.", ["Japanese Yen is the active row"], [r"52, Japanese Yen \(Active\)"], before=to_currency),
    Journey("currency-switch-active-row", "Press 5, 0. Then tap the amount row for Euro once, and finish when Euro is Active.", ["Euro is the active row"], [r"1, Euro \(Active\)"], before=to_currency),
    Journey("currency-tap-active-row-keeps-amount", "Press 5, 0. Then tap the amount row for US Dollar, which is already active.", [], [r"50, US Dollar \(Active\)"], before=to_currency),
    Journey("currency-backspace-and-clear", "Press 1, 2, 3, then Delete, then AC.", [], [r"1, US Dollar \(Active\)"], before=to_currency),
    Journey("currency-picker-search-select", "Press Change currency EUR. Type Swiss in the search field, then choose CHF, the Swiss Franc.", ["A currency list with a search field is open", "The currency screen shows CHF"], ["Change currency CHF"], ["Change currency EUR"], before=to_currency),
    Journey("currency-picker-keeps-active-amount", "Press 1, 0, 0. Press Change currency EUR, type Swiss in the search field, then choose CHF.", ["The currency screen shows CHF"], [r"100, US Dollar \(Active\)", "Change currency CHF"], before=to_currency),
    Journey("currency-picker-duplicate-swaps", "Press Change currency EUR. Type JPY in the search field, then choose JPY.", ["The currency screen lists both JPY and EUR"], ["Change currency JPY", "Change currency EUR"], before=to_currency),
    Journey("currency-btc-live-rate", "Press Change currency EUR. Type Bitcoin in the search field, then choose BTC.", ["The currency screen shows BTC"], ["Change currency BTC", r"0\.0000\d+, Bitcoin"], ["—"], before=to_currency),
    Journey("currency-refresh", "Tap the line that says when rates were updated.", ["The status line says rates were updated"], [r"Updated (just now|\d+ seconds? ago)"], ["Update failed"], before=to_currency),
]


def unit(name, tool, row, digits, expected):
    digits = list(digits)
    return Journey(
        f"tool-{name}",
        f"Tap the {row} row to make it active, then press {', '.join(digits)}.",
        [f"{row} is the active row"],
        expected,
        before=open_tool(tool),
    )


TOOLS = [
    unit("length", "Length", "Kilometer", "5", [r"Kilometer, 5, km \(Active\)", r"Mile, 3\.10685\d*, mi", r"Meter, 5,000, m"]),
    unit("area", "Area", "Hectare", "2", [r"Square Meter, 20,000, m²", r"Acre, 4\.94\d*, acres"]),
    unit("mass", "Mass", "Pound", "1", [r"Kilogram, 0\.4535\d*, kg", r"Ounce, 16(\.0\d*)?, oz"]),
    unit("volume", "Volume", "Gallon", "1", [r"Liter, 3\.7854\d*, L", r"Quart, 4, qt"]),
    unit("speed", "Speed", "Kilometer per Hour", ["1", "0", "0"], [r"Mile per Hour, 62\.13\d*, mph", r"Meter per Second, 27\.77\d*, m/s"]),
    unit("pressure", "Pressure", "Atmosphere", "1", [r"Pascal, 101,325, Pa", r"Bar, 1\.01325, bar"]),
    unit("power", "Power", "Kilowatt", "1", [r"Watt, 1,000, W", r"Horsepower, 1\.341\d*, hp"]),
    unit("angle", "Angle", "Degree", ["1", "8", "0"], [r"Radian, 3\.14159\d*, rad", r"Arcminute, 10,800, arcmin"]),
    unit("energy", "Energy", "Kilocalorie", "1", [r"Joule, 4,184, J", r"Calorie, 1,000, cal"]),
    unit("force", "Force", "Kilogram-Force", "1", [r"Newton, 9\.80665, N"]),
    unit("fuel", "Fuel", "Liter per 100km", "5", [r"Kilometer per Liter, 20, km/L", r"Mile per Gallon, 47\.04\d*, mpg"]),
    unit("time", "Time", "Hour", "2", [r"Minute, 120, min", r"Second, 7,200, s"]),
    unit("data", "Data", "Gigabyte", "1", [r"Megabyte, 1,024, MB", r"Byte, 1,073,741,824, B"]),
    Journey("tool-temp-fahrenheit", "Tap the Fahrenheit row to make it active, then press 2, 1, 2.", ["Fahrenheit is the active row"], [r"Celsius, 100, °C", r"Kelvin, 373\.15, K"], before=open_tool("Temp")),
    Journey("tool-temp-negative", script=temp_negative_script, expect=[r"Celsius, -40, °C \(Active\)", r"Fahrenheit, -40, °F"], before=open_tool("Temp")),
    Journey("tool-unit-fractional-entry", "Tap the Meter row to make it active. Press 1, the decimal point, 0, 5.", ["Meter shows 1.05"], [r"Meter, 1\.05, m \(Active\)", r"Centimeter, 105, cm"], before=open_tool("Length")),
    Journey("tool-unit-backspace-clear", "Press 1, 2, 3, then Delete, then AC.", [], [r"Millimeter, 0, mm \(Active\)"], before=open_tool("Length")),
    Journey("tool-age", "Year is active: use the Keypad to enter 2000. Then tap Month and use the Keypad to enter 6. Then tap Day and use the Keypad to enter 15.", ["An age result is shown"], [r"Year, 2000", r"26 years, 4 months, \d+ days"], forbid=[r"Year, 2,000"], before=open_tool("Age")),
    Journey("tool-age-future-birthday", "Tap Year and enter 2999.", [], [r"Year, 2999"], forbid=[r"\d+ years, \d+ months"], before=open_tool("Age")),
    Journey("tool-bmi", "Tap Height and enter 180, then tap Weight and enter 81.", ["A BMI of 25 is shown"], [r"25 - Overweight"], before=open_tool("BMI")),
    Journey("tool-date", "Tap Year 2 once to make it active, then use the Keypad to enter 2026.", ["A difference result is shown"], [r"731 days", r"104 weeks"], before=open_tool("Date")),
    Journey("tool-discount", "Tap Price and enter 250, then tap % and enter 10.", ["The result shows savings and a final price"], [r"Savings: 25", r"Final price: 225"], before=open_tool("Discount")),
    Journey("tool-discount-over-100", "Tap % and enter 150.", [], forbid=[r"Final price"], before=open_tool("Discount")),
    Journey("tool-loan", "Do not change anything: this shows the default loan. Finish.", ["A loan summary is shown"], [r"Monthly: 1,073\.64", r"Total interest: 186,511\.57"], before=open_tool("Loan")),
    Journey("tool-loan-zero-interest", script=loan_zero_script, expect=[r"Monthly: 100", r"Total interest: 0"], before=open_tool("Loan")),
    Journey("tool-open-currency-from-grid", script=lambda d: (d.tap_label("Currency", exact=True), press(d, "5")), expect=[r"5, US Dollar \(Active\)", "Back"], before=to_grid),
    Journey("tool-back-button", "Tap Length in the tools grid, then press Back.", ["Length units are listed", "The tools grid is showing again"], ["Discount", "Loan"], ["Millimeter"], before=to_grid),
    Journey("tool-swipe-back", "Tap Length in the tools grid. Then swipe right to go back.", ["Length units are listed", "The tools grid is showing again"], ["Discount", "Loan"], ["Millimeter"], before=to_grid),
]


def enter_rearrange(device):
    device.hold_label("Length", exact=True)
    device.find("", value="Not pinned")


def pin_length_script(device):
    enter_rearrange(device)
    device.tap_label("Length", exact=True)
    assert tab_order(device) == ["Calculator", "Currency", "Length", "All tools"], tab_order(device)
    device.swipe(200, 830, 210, 835, duration=0.05)
    device.tap(200, 800)  # empty background exits rearranging
    assert not any(e["value"] == "Not pinned" for e in device.settled()), "Still rearranging"


def pinned_page_script(device):
    pin_length_script(device)
    device.previous_page()
    assert any("Millimeter" in e["label"] for e in device.settled()), device.text()


def toolbar_full_script(device):
    enter_rearrange(device)
    for tool in ["Length", "Area", "Mass", "Volume"]:
        device.tap_label(tool, exact=True)
        time.sleep(0.4)
    device.tap_label("Speed", exact=True)
    device.find("Toolbar is full")
    assert "Speed" not in tab_order(device), tab_order(device)


def unpin_script(device):
    enter_rearrange(device)
    device.tap_label("Currency", exact=True)
    assert tab_order(device) == ["Calculator", "All tools"], tab_order(device)
    assert device.find("Currency", exact=True)["value"] == "Not pinned", "Unpinning ended rearranging"
    device.next_page()  # already on the last page
    device.tap_label("Length", exact=True)
    assert device.find("Length", exact=True)["value"] == "Pinned", "Tap did not pin"
    time.sleep(0.4)
    device.tap_label("Length", exact=True)
    assert device.find("Length", exact=True)["value"] == "Not pinned", "Tap did not unpin"


def page_away_ends_rearrange_script(device):
    enter_rearrange(device)
    device.swipe(60, 700, 370, 700)
    device.find("Change currency USD", exact=True)
    device.next_page()
    assert device.find("Length", exact=True)["value"] == "", "Still rearranging after leaving the grid"
    device.tap_label("Length", exact=True)
    device.find("Millimeter")


def swipe_from_card_script(device):
    assert device.find("Area", exact=True)
    area = device.find("Area", exact=True)
    device.swipe(area["x"], area["y"], area["x"] + 200, area["y"], duration=0.15)
    device.find("Change currency USD", exact=True)


def hold_does_not_open_script(device):
    enter_rearrange(device)
    assert not any("Millimeter" in e["label"] for e in device.settled()), "Hold opened the tool"


def reorder_grid_script(device):
    enter_rearrange(device)
    before = tool_order(device)
    assert before[:3] == ["Currency", "Length", "Area"], before
    source, target = device.find("Currency", exact=True), device.find("Area", exact=True)
    device.swipe(source["x"], source["y"], target["x"], target["y"], duration=1.0)
    after = tool_order(device)
    assert after[:3] == ["Length", "Area", "Currency"], after
    device.launch()
    to_grid(device)
    enter_rearrange(device)
    assert tool_order(device)[:3] == ["Length", "Area", "Currency"], "Order was not persisted"


def reorder_tabbar_script(device):
    enter_rearrange(device)
    device.tap_label("Length", exact=True)
    time.sleep(0.4)
    source, target = device.find("Length tab", exact=True), device.find("Currency tab", exact=True)
    device.swipe(source["x"], source["y"], target["x"], target["y"], duration=1.0)
    assert tab_order(device) == ["Calculator", "Length", "Currency", "All tools"], tab_order(device)
    device.launch()
    to_grid(device)
    device.next_page()  # the pinned tool added a page
    assert tab_order(device) == ["Calculator", "Length", "Currency", "All tools"], "Tab order was not persisted"


def drag_tool_to_tabbar_script(device):
    enter_rearrange(device)
    source, target = device.find("Mass", exact=True), device.find("All tools tab", exact=True)
    device.swipe(source["x"], source["y"], target["x"], target["y"], duration=1.2)
    assert "Mass" in tab_order(device), tab_order(device)


def drag_calculator_tab_script(device):
    enter_rearrange(device)
    source, target = device.find("Calculator tab", exact=True), device.find("Currency tab", exact=True)
    device.swipe(source["x"], source["y"], target["x"], target["y"], duration=1.0)
    assert tab_order(device) == ["Currency", "Calculator", "All tools"], tab_order(device)
    device.launch()
    device.find("All clear", exact=True)  # still opens on the calculator


def long_press_tabbar_on_other_page_script(device):
    device.next_page()
    # The bar is only briefly visible while paging. A hold where it sits must not start rearranging.
    device.tap(200, 83, duration=0.7)
    device.next_page()
    assert not any(e["value"] in {"Not pinned", "Pinned"} for e in device.settled()), "Rearranging started outside the grid"


def paging_script(device):
    device.find("All clear", exact=True)
    device.next_page()
    device.find("Change currency USD", exact=True)
    device.next_page()
    device.find("Loan", exact=True)
    device.next_page()  # last page: stays put
    device.find("Loan", exact=True)
    device.previous_page()
    device.find("Change currency USD", exact=True)
    device.previous_page()
    device.find("All clear", exact=True)


def keeps_input_across_pages_script(device):
    press(device, "4", "2")
    device.next_page()
    press(device, "7")
    device.next_page()
    device.previous_page()
    device.find("7, US Dollar", exact=False)
    device.previous_page()
    device.find("42", exact=True)


def currency_persist_script(device):
    to_currency(device)
    device.tap_label("Change currency EUR", exact=True)
    time.sleep(1)
    run("idb", "ui", "text", "--udid", device.udid, "CHF")
    time.sleep(1)
    device.tap_label("CHF")
    device.find("Change currency CHF", exact=True)
    device.launch()
    to_currency(device)
    device.find("Change currency CHF", exact=True)


def refresh_on_open_script(device):
    to_currency(device)
    device.find("Updated")
    first = device.find("Updated")["label"]
    device.to_background_and_back(1)
    to_label = device.find("Updated")["label"]
    assert "failed" not in to_label, to_label
    assert first, to_label


def history_persist_script(device):
    press(device, "2", "Plus", "3", "Equals")
    device.launch()
    device.tap_label("History", exact=True)
    device.find("2+3")


NAVIGATION = [
    Journey("nav-paging", script=paging_script),
    Journey("nav-state-kept-across-pages", script=keeps_input_across_pages_script),
    Journey("nav-tabbar-hold-outside-grid", script=long_press_tabbar_on_other_page_script),
    Journey("grid-pin-from-rearrange", script=pin_length_script, before=to_grid),
    Journey("grid-pinned-tool-is-a-page", script=pinned_page_script, before=to_grid),
    Journey("grid-toolbar-full", script=toolbar_full_script, before=to_grid),
    Journey("grid-unpin", script=unpin_script, before=to_grid),
    Journey("grid-page-away-ends-rearrange", script=page_away_ends_rearrange_script, before=to_grid),
    Journey("grid-swipe-from-card", script=swipe_from_card_script, before=to_grid),
    Journey("grid-hold-does-not-open", script=hold_does_not_open_script, before=to_grid),
    Journey("grid-drag-reorder", script=reorder_grid_script, before=to_grid),
    Journey("grid-drag-tool-to-tabbar", script=drag_tool_to_tabbar_script, before=to_grid),
    Journey("tabbar-drag-reorder", script=reorder_tabbar_script, before=to_grid),
    Journey("tabbar-drag-calculator", script=drag_calculator_tab_script, before=to_grid),
    Journey("grid-rearrange-with-jev", "Long-press Volume to start rearranging. Finish as soon as tools show whether they are pinned.", ["Tools show whether they are pinned"], [r"Volume \(Not pinned\)"], before=to_grid, gestures=True),
    Journey("persist-currencies", script=currency_persist_script),
    Journey("persist-history", script=history_persist_script),
    Journey("rates-survive-background", script=refresh_on_open_script),
]

JOURNEYS = CALCULATOR + SCIENTIFIC + HISTORY + CURRENCY + TOOLS + NAVIGATION
