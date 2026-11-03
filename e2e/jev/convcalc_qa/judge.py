"""Per-state verdicts, adapted from RecordMeeting's suite: is this an error, and which checkpoints show?"""

from .openrouter import system_one

ERROR_FAIL = 0.8
CHECKPOINT_PASS = 0.8

ERROR = {
    "true": "The screen tells the user something went wrong: a crash, an error message, or a failure to load.",
    "false": "Normal app content, including empty states, dialogs, and a toolbar-limit notice.",
}


def judge(journey, page, reached, last_action):
    pending = [i for i in range(len(journey.checkpoints)) if i not in reached]
    questions = {"error": {"type": "noul", "instructions": "Does `screen` show that something went wrong for the user?", "criteria": ERROR}}
    for i in pending:
        questions[f"checkpoint_{i}"] = {"type": "noul", "instructions": f"Does `screen` visibly show this: {journey.checkpoints[i]}"}
    result = system_one(
        {
            "model": "jev-latest",
            "state": {
                "journey": {"goal": journey.goal, "checkpoints_already_seen": [journey.checkpoints[i] for i in reached]},
                "screen": {"text": page["text"], "controls": [a["label"] for a in page["actions"] if a["kind"] == "click"][:120]},
                "last_action": last_action,
            },
            "questions": questions,
        }
    )
    answers = result["answers"]
    reached = list(reached)
    for i in pending:
        if answers.get(f"checkpoint_{i}", {}).get("noul", 0) < CHECKPOINT_PASS:
            break
        reached.append(i)
    return {"error": answers["error"]["noul"], "reached": reached, "cost": result.get("usage", {}).get("cost", 0)}
