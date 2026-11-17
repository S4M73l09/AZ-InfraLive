import json
import os
import sys
from collections import Counter


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: plan_counts.py <plan.json>", file=sys.stderr)
        return 2

    with open(sys.argv[1], "r", encoding="utf-8") as fh:
        data = json.load(fh)

    changes = data.get("resource_changes", [])
    counts = Counter()
    for rc in changes:
        actions = rc.get("change", {}).get("actions", [])
        if actions == ["create"]:
            counts["add"] += 1
        elif actions == ["update"]:
            counts["change"] += 1
        elif actions == ["delete"]:
            counts["destroy"] += 1
        elif actions == ["create", "delete"]:
            counts["replace"] += 1

    out = os.environ.get("GITHUB_OUTPUT")
    if not out:
        return 1

    with open(out, "a", encoding="utf-8") as fh:
        fh.write(f"add={counts['add']}\n")
        fh.write(f"change={counts['change']}\n")
        fh.write(f"destroy={counts['destroy']}\n")
        fh.write(f"replace={counts['replace']}\n")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
