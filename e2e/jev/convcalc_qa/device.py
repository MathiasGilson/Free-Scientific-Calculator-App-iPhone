"""The iOS simulator behind jev_ultrafast's Browser interface: accessibility tree in, real touches out."""

import base64
import hashlib
import json
import subprocess
import tempfile
import time
from pathlib import Path

from jev_ultrafast.browser import StalePage, fingerprint

BUNDLE = "com.qualtir.convcalc"
SCREEN_W, SCREEN_H = 402, 874
TEXT_TYPES = {"TextField", "SearchField", "SecureTextField"}
IGNORED_TYPES = {"Application", "Group", "Window", "ScrollView", "Other", "Keyboard", "Key"}


def run(*args, check=True):
    return subprocess.run(args, capture_output=True, text=True, check=check, timeout=60).stdout


class Simulator:
    def __init__(self, udid, app):
        self.udid = udid
        self.app = app
        self.gestures = False
        self.drags = False
        self.last_drag = None
        self.centers = {}
        # A freshly booted simulator counts as having a hardware keyboard and hides the on-screen one.
        for setting in ("HardwareKeyboardLastSeen", "AutomaticMinimizationEnabled"):
            run("xcrun", "simctl", "spawn", udid, "defaults", "write", "com.apple.keyboard.preferences", setting, "-bool", "NO")

    # ---- lifecycle
    def fresh_install(self, locale=None):
        run("xcrun", "simctl", "terminate", self.udid, BUNDLE, check=False)
        run("xcrun", "simctl", "uninstall", self.udid, BUNDLE, check=False)
        run("xcrun", "simctl", "install", self.udid, self.app)
        self.launch(locale)

    def launch(self, locale=None):
        self.locale = locale
        run("xcrun", "simctl", "terminate", self.udid, BUNDLE, check=False)
        args = ["-AppleLocale", locale.replace("-", "_"), "-AppleLanguages", f"({locale.split('-')[0]})"] if locale else []
        run("xcrun", "simctl", "launch", self.udid, BUNDLE, *args)
        time.sleep(1.5)

    def to_background_and_back(self, seconds=1.0):
        run("xcrun", "simctl", "launch", self.udid, "com.apple.Preferences")
        time.sleep(seconds)
        run("xcrun", "simctl", "launch", self.udid, BUNDLE)
        time.sleep(1.0)

    def pasteboard(self):
        return run("xcrun", "simctl", "pbpaste", self.udid)

    # ---- keyboard
    def tap_key(self, label):
        """Press a key of the on-screen keyboard. `idb ui text` acts as a hardware keyboard, which hides it."""
        for element in json.loads(run("idb", "ui", "describe-all", "--udid", self.udid)):
            frame = element.get("frame") or {}
            if element.get("type") == "Button" and (element.get("AXLabel") or "").lower() == label.lower():
                self.tap(frame["x"] + frame["width"] / 2, frame["y"] + frame["height"] / 2)
                time.sleep(0.15)
                return
        raise AssertionError(f"The keyboard has no {label!r} key")

    def type_on_keyboard(self, text):
        for character in text:
            self.tap_key(character)

    # ---- reading
    def elements(self):
        raw = json.loads(run("idb", "ui", "describe-all", "--udid", self.udid))
        found = []
        for element in raw:
            frame = element.get("frame") or {}
            if element.get("type") in IGNORED_TYPES or not (element.get("AXLabel") or element.get("AXValue")):
                continue
            cx, cy = frame["x"] + frame["width"] / 2, frame["y"] + frame["height"] / 2
            if not (0 <= cx <= SCREEN_W and 0 <= cy <= SCREEN_H) or not frame["width"] or not frame["height"]:
                continue
            found.append(
                {
                    "type": element["type"],
                    "label": element.get("AXLabel") or "",
                    "value": element.get("AXValue") or "",
                    "x": cx,
                    "y": cy,
                    "frame": frame,
                    "button": "Button" in (element.get("traits") or []) or element["type"] == "Button",
                    "chunk": element.get("AXUniqueId") == "expressionChunk",
                }
            )
        # The system keyboard is not part of the app. Its keys and whatever sits behind them are unreachable.
        self.keyboard = any(e["label"] == "Dictate" for e in found)
        if self.keyboard:
            top = min(e["frame"]["y"] for e in found if e["label"].lower() == "q")
            found = [e for e in found if e["y"] < top - 50 and not e["label"].startswith("“")]
        # Scrolled rows stay in the tree under the keypad; a user cannot reach what is covered.
        visible = []
        for i, element in enumerate(found):
            covered = any(
                other["button"]
                and other["label"] != "Dismiss context menu"
                and other["frame"]["x"] <= element["x"] <= other["frame"]["x"] + other["frame"]["width"]
                and other["frame"]["y"] <= element["y"] <= other["frame"]["y"] + other["frame"]["height"]
                for other in found[i + 1 :]
            )
            if not covered:
                visible.append(element)
        return visible

    @staticmethod
    def signature(elements):
        return [(e["type"], e["label"], e["value"]) for e in elements]

    def settled(self):
        """Animations change the tree; wait until two reads agree."""
        previous = None
        deadline = time.monotonic() + 3
        while True:
            current = self.elements()
            if previous is not None and self.signature(current) == self.signature(previous):
                return current
            if time.monotonic() > deadline:
                return current
            previous = current
            time.sleep(0.12)

    @staticmethod
    def display(element):
        # A display chunk and a keypad key can both read "3"; only the key is renamed, so expectations
        # like ^3$ mean the display.
        label = f"Key {element['label']}" if element["button"] and not element["chunk"] and element["label"].isdigit() else element["label"]
        return f"{label} ({element['value']})" if element["value"] else label

    def text(self):
        return "\n".join(self.display(e) for e in self.settled())

    def find(self, label, exact=False, value=None):
        # Keypads come last in the tree, so a digit resolves to the key rather than a display chunk.
        for element in reversed(self.settled()):
            if value is not None and element["value"] != value:
                continue
            if (element["label"] == label) if exact else (label in element["label"]):
                return element
        raise AssertionError(f"No element labelled {label!r}. Screen:\n{self.text()}")

    @staticmethod
    def is_key(element):
        return element["button"] and not element["chunk"] and element["label"].isdigit()

    def press_keys(self, text):
        keys = {e["label"]: e for e in self.settled() if e["button"] and not e["chunk"]}
        for character in text:
            label = {
                ".": "Decimal point" if "Decimal point" in keys else ".",
                "+": "Plus",
                "-": "Minus",
                "*": "Multiply",
                "/": "Divide",
                "=": "Equals",
                "(": "Parentheses",
                ")": "Parentheses",
            }.get(character, character)
            if label not in keys:
                raise AssertionError(f"Jev asked for key {character!r} in {text!r}, which is not on this keypad")
            self.tap(keys[label]["x"], keys[label]["y"])

    def page_text(self, elements):
        lines = [self.display(e) for e in elements]
        chunks = [e["label"] for e in elements if e["chunk"]]
        if chunks:
            lines.insert(0, f"Expression on the display: {' '.join(chunks)}")
        return "\n".join(lines)

    def observe(self, screenshot=True):
        elements = self.settled()
        actions, self.centers = [], {}
        for node, element in enumerate(elements):
            self.centers[node] = (element["x"], element["y"])
            label = f"Expression part {element['label']}" if element["chunk"] else self.display(element)
            if element["type"] in TEXT_TYPES:
                actions.append({"id": f"fill_{node}", "kind": "fill", "node": node, "role": "textbox", "label": label, "value": element["value"]})
            elif self.is_key(element):
                continue  # pressed through the keypad action below
            elif element["button"]:
                actions.append({"id": f"tap_{node}", "kind": "click", "node": node, "role": "button", "label": label})
            display_zero = element["label"] == "0" and not element["button"]
            menu_open = any(e["label"] == "Dismiss context menu" for e in elements)
            if self.gestures and not menu_open and (display_zero or element["button"]):
                actions.append({"id": f"hold_{node}", "kind": "click", "node": 1000 + node, "role": "button", "label": f"Long-press: {label}"})
                self.centers[1000 + node] = (element["x"], element["y"])
            if self.drags and element["button"]:
                actions.append({"id": f"drag_{node}", "kind": "fill", "node": 2000 + node, "source": element["label"], "role": "textbox", "label": f"Long-press {label} and drag it without lifting. Text: the exact name of the item to drop it on", "value": ""})
        if any(self.is_key(e) for e in elements):
            # Jev drops repeated digits and swaps neighbours when it picks keys one at a time, so
            # the text helper writes the sequence and every key is still a real tap.
            actions.append(
                {
                    "id": "press_keys",
                    "kind": "fill",
                    "node": 9001,
                    "role": "textbox",
                    "label": "Keypad: the digits and decimal point to press next, in order, for example 12 or 1.05",
                    "value": "",
                }
            )
        if self.keyboard:
            # iOS 26 keeps the focused search field out of the accessibility tree; the keyboard proves it exists.
            actions.append({"id": "type_search", "kind": "fill", "node": 9000, "role": "textbox", "label": "Search field", "value": ""})
        actions += [
            {"id": "swipe_left", "kind": "swipe", "label": "Swipe left: go to the next page."},
            {"id": "swipe_right", "kind": "swipe", "label": "Swipe right: go to the previous page, or back out of an open tool."},
            {"id": "scroll_down", "kind": "scroll", "label": "Scroll the list down."},
            {"id": "wait", "kind": "wait", "label": "Wait for something still loading."},
        ]
        page = {
            "url": "app://convcalc",
            "title": "ConvCalc",
            "text": self.page_text(elements),
            "actions": actions,
            "scroll": {},
            "marker": hashlib.sha256(json.dumps(self.signature(elements)).encode()).hexdigest(),
            "page_key": "ios",
            "guards": {},
        }
        page["fingerprint"] = fingerprint(page)
        if screenshot:
            page["screenshot"] = self.screenshot()
        return page

    def screenshot(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "screen.jpg"
            run("xcrun", "simctl", "io", self.udid, "screenshot", "--type=jpeg", str(path))
            return base64.b64encode(path.read_bytes()).decode()

    def fresh(self, page, action=None):
        return hashlib.sha256(json.dumps(self.signature(self.elements())).encode()).hexdigest() == page["marker"]

    # ---- acting
    def tap(self, x, y, duration=None):
        extra = ["--duration", str(duration)] if duration else []
        run("idb", "ui", "tap", "--udid", self.udid, *extra, str(round(x)), str(round(y)))
        time.sleep(0.3)

    def swipe(self, x1, y1, x2, y2, duration=0.3):
        run("idb", "ui", "swipe", "--udid", self.udid, "--duration", str(duration), str(round(x1)), str(round(y1)), str(round(x2)), str(round(y2)))
        time.sleep(0.8)

    def tap_label(self, label, exact=False):
        element = self.find(label, exact)
        self.tap(element["x"], element["y"])

    def hold_label(self, label, exact=False):
        element = self.find(label, exact)
        self.tap(element["x"], element["y"], duration=0.7)
        time.sleep(0.5)

    def touch(self, x, y, phase):
        # idb cannot pause mid-swipe, so a hold that flows into a drag uses AXe. A second "down" moves the same finger.
        run("axe", "touch", "-x", str(round(x)), "-y", str(round(y)), f"--{phase}", "--udid", self.udid)

    def frame(self, label):
        # The dragged card overlaps others, which elements() treats as covered.
        raw = json.loads(run("idb", "ui", "describe-all", "--udid", self.udid))
        return next(e["frame"] for e in raw if e.get("AXLabel") == label and e.get("type") not in IGNORED_TYPES)

    def hold_and_drag(self, source, target):
        """Long-press, then move and drop in one touch, measuring the item at each stage."""
        origin, end = self.find(source, exact=True), self.find(target, exact=True)
        self.touch(origin["x"], origin["y"], "down")
        time.sleep(0.8)
        held = self.frame(source)
        for step in range(1, 13):
            self.touch(origin["x"] + (end["x"] - origin["x"]) * step / 12, origin["y"] + (end["y"] - origin["y"]) * step / 12, "down")
        time.sleep(0.2)
        moved = self.frame(source)
        self.touch(end["x"], end["y"], "up")
        time.sleep(0.7)
        self.last_drag = {"rest": origin["frame"], "held": held, "moved": moved, "dropped": self.frame(source), "finger": (end["x"], end["y"])}
        return self.last_drag

    def next_page(self):
        self.swipe(370, 300, 30, 300)

    def previous_page(self):
        self.swipe(30, 300, 370, 300)

    def act(self, action, page, text=None):
        if action["kind"] != "wait" and not self.fresh(page):
            raise StalePage("Screen changed since this decision.")
        kind, ident = action["kind"], action["id"]
        if ident == "swipe_left":
            self.next_page()
        elif ident == "swipe_right":
            self.previous_page()
        elif ident == "scroll_down":
            self.swipe(200, 360, 200, 160)
        elif ident == "wait":
            time.sleep(1)
        elif ident == "press_keys":
            self.press_keys(text)
        elif ident == "type_search":
            self.type_on_keyboard(text)
            time.sleep(0.8)
        elif ident.startswith("drag_"):
            self.hold_and_drag(action["source"], text)
        elif kind == "fill":
            self.tap(*self.centers[action["node"]])
            run("idb", "ui", "text", "--udid", self.udid, text)
            time.sleep(0.5)
        elif ident.startswith("hold_"):
            self.tap(*self.centers[action["node"]], duration=0.7)
            time.sleep(0.5)
        else:
            self.tap(*self.centers[action["node"]])
        return {"executed": ident}

    def close(self):
        pass
