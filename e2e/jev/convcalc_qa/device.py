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
        self.centers = {}

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

    def set_pasteboard(self, text):
        subprocess.run(["xcrun", "simctl", "pbcopy", self.udid], input=text, text=True, check=True, timeout=30)

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
            elif element["button"]:
                actions.append({"id": f"tap_{node}", "kind": "click", "node": node, "role": "button", "label": label})
            display_zero = element["label"] == "0" and not element["button"]
            if self.gestures and (display_zero or (element["button"] and (element["chunk"] or not element["label"].isdigit()))):
                actions.append({"id": f"hold_{node}", "kind": "click", "node": 1000 + node, "role": "button", "label": f"Long-press: {label}"})
                self.centers[1000 + node] = (element["x"], element["y"])
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
        elif ident == "type_search":
            run("idb", "ui", "text", "--udid", self.udid, text)
            time.sleep(0.8)
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
