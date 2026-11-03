"""Run journeys one at a time on one simulator: each starts from a clean install, Jev gets only the goal,
the judge scores every state, and exact expectations are asserted in code on the final screen."""

import argparse
import json
import os
import re
import sys
import time
import traceback
from pathlib import Path

# browser_harness reads these at import time. Nothing here talks to a browser.
os.environ.setdefault("BU_NAME", "convcalc")
os.environ.setdefault("BU_CDP_URL", "http://127.0.0.1:9")

from jev_ultrafast import agent as jev_agent  # noqa: E402
from jev_ultrafast.browser import StalePage  # noqa: E402

from . import openrouter  # noqa: E402
from .device import Simulator  # noqa: E402
from .judge import ERROR_FAIL, judge  # noqa: E402
from .journeys import JOURNEYS  # noqa: E402

ARTIFACTS = Path(__file__).parent.parent / "artifacts"


def run_jev(journey, device, folder):
    jev_agent.Browser = lambda _url: device
    problems, reached, last, cost, steps = [], [], None, 0.0, []
    device.gestures = journey.gestures
    agent = jev_agent.Agent("app://convcalc", journey.goal, record_dir=folder, screenshots=True)
    try:
        while agent.state["status"] not in {"done", "blocked"}:
            if len(agent.state["history"]) >= journey.max_actions:
                problems.append(f"Jev used all {journey.max_actions} actions")
                break
            try:
                agent.command("tick")
            except StalePage:
                continue
            history = agent.state["history"]
            if history and history[-1]["action"] != last:
                last = history[-1]["action"]
                steps.append(f"{history[-1]['kind']}: {last}" + (f" = {history[-1]['text']}" if history[-1].get("text") else ""))
            verdict = judge(journey, agent.state["page"], reached, last)
            reached, cost = verdict["reached"], cost + verdict["cost"]
            if verdict["error"] >= ERROR_FAIL and not journey.expects_error:
                problems.append(f"Judge saw an error screen after {last!r}: {agent.state['page']['text'][:300]}")
                break
        if agent.state["status"] == "blocked":
            problems.append(f"Jev was blocked after {steps[-1:] or 'no actions'}")
        missing = [c for i, c in enumerate(journey.checkpoints) if i not in reached]
        if missing and not problems:
            problems.append(f"Checkpoints never seen: {missing}")
    finally:
        device.gestures = False
    return problems, steps, cost


def run_journey(journey, device, root):
    folder = root / journey.name
    folder.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    problems, steps, cost = [], [], 0.0
    try:
        device.fresh_install(journey.locale)
        if journey.before:
            journey.before(device)
        if journey.goal:
            problems, steps, cost = run_jev(journey, device, folder)
        if not problems and journey.script:
            journey.script(device)
        if not problems:
            screen = device.text()
            for pattern in journey.expect:
                if not re.search(pattern, screen):
                    problems.append(f"Final screen is missing {pattern!r}")
            for pattern in journey.forbid:
                if re.search(pattern, screen):
                    problems.append(f"Final screen must not contain {pattern!r}")
            if problems:
                problems.append("Screen was:\n" + screen)
        if not problems and journey.verify:
            problem = journey.verify(device)
            if problem:
                problems.append(problem)
    except AssertionError as exc:
        problems.append(str(exc))
    except Exception:
        problems.append(traceback.format_exc(limit=4))
    try:
        (folder / "final.jpg").write_bytes(__import__("base64").b64decode(device.screenshot()))
    except Exception:
        pass
    return {"name": journey.name, "ok": not problems, "problems": problems, "steps": steps, "cost": cost, "seconds": round(time.monotonic() - started)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--udid", required=True)
    parser.add_argument("--app", required=True)
    parser.add_argument("--only", help="regex of journey names")
    parser.add_argument("--retries", type=int, default=1, help="reruns of a failed journey, to tell flakes from bugs")
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()
    selected = [j for j in JOURNEYS if not args.only or re.search(args.only, j.name)]
    if args.list:
        print("\n".join(j.name for j in selected))
        return
    openrouter.configure()
    device = Simulator(args.udid, args.app)
    root = ARTIFACTS / time.strftime("%Y%m%d-%H%M%S")
    results = []
    for journey in selected:
        result = run_journey(journey, device, root)
        attempts = 1
        while not result["ok"] and attempts <= args.retries:
            attempts += 1
            result = {**run_journey(journey, device, root), "failed_first": result["problems"]}
        result["attempts"] = attempts
        results.append(result)
        mark = "PASS" if result["ok"] and attempts == 1 else "FLAKY" if result["ok"] else "FAIL"
        print(f"{mark:5} {journey.name} ({result['seconds']}s, {len(result['steps'])} actions)", flush=True)
        if not result["ok"]:
            print("      " + "\n      ".join(result["problems"]), flush=True)
        (root / "results.json").write_text(json.dumps(results, indent=1))
    passed = sum(r["ok"] for r in results)
    print(f"\n{passed}/{len(results)} journeys passed; ${sum(r['cost'] for r in results):.3f} of judge calls; {root}", flush=True)
    sys.exit(0 if passed == len(results) else 1)


main()
