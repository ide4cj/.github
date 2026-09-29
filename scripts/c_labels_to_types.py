#!/usr/bin/env python3
"""One-off: the C- labels become GitHub's issue types, then go.

    scripts/c_labels_to_types.py [--apply]

Every issue (not PR) of the organization carrying C-bug, C-feature, C-tracking or C-docs gets the
type Bug, Feature or Task, unless it has a type already; then those labels are deleted from every
repository. Without --apply it prints what it would do.
"""

import json
import subprocess
import sys
import time

ORG = "ide4cj"
TYPES = {"C-bug": "Bug", "C-feature": "Feature", "C-tracking": "Task", "C-docs": "Task"}


def gh(*args: str) -> str:
    for attempt in range(5):
        out = subprocess.run(["gh", *args], capture_output=True, text=True)
        if out.returncode == 0:
            return out.stdout
        time.sleep(2 ** attempt)
    raise RuntimeError(f"gh {' '.join(args)}: {out.stderr.strip()}")


def main() -> None:
    apply = "--apply" in sys.argv
    repos = [json.loads(l)["name"] for l in gh("api", "--paginate", "--jq", ".[]", f"orgs/{ORG}/repos").splitlines()]
    for repo in repos:
        full = f"{ORG}/{repo}"
        issues = json.loads(gh("issue", "list", "-R", full, "--state", "all", "--limit", "1000",
                               "--json", "number,labels,issueType"))
        for issue in issues:
            labels = [l["name"] for l in issue["labels"] if l["name"] in TYPES]
            if not labels or issue.get("issueType"):
                continue
            kind = TYPES[labels[0]]
            print(f"{full}#{issue['number']}: {','.join(labels)} -> type {kind}")
            if apply:
                gh("issue", "edit", str(issue["number"]), "-R", full, "--type", kind)
        have = {l["name"] for l in json.loads(gh("label", "list", "-R", full, "--limit", "200", "--json", "name"))}
        for label in TYPES:
            if label in have:
                print(f"{full}: delete label {label}")
                if apply:
                    gh("label", "delete", label, "-R", full, "--yes")


if __name__ == "__main__":
    main()
