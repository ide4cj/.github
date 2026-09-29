#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///
"""Syncs labels.yml to the organization's repositories, through `gh api`.

    scripts/sync_labels.py [--dry-run] [repo ...]

With no repo, every repository of the organization that is not archived. A label of labels.yml is
created, or its color and description updated; a label named by one of its `aliases` is renamed to
it, so its issues keep it. Labels labels.yml does not name are left alone.
"""

import json
import pathlib
import subprocess
import sys
import urllib.parse

import yaml

ORG = "ide4cj"


def gh(*args: str, body: dict | None = None) -> object:
    cmd = ["gh", "api", *args]
    if body is not None:
        cmd += ["--input", "-"]
    out = subprocess.run(cmd, input=json.dumps(body) if body else None, capture_output=True, text=True, check=True)
    return json.loads(out.stdout) if out.stdout.strip() else None


def gh_list(path: str) -> list[dict]:
    out = subprocess.run(["gh", "api", "--paginate", "--jq", ".[]", path], capture_output=True, text=True, check=True)
    return [json.loads(line) for line in out.stdout.splitlines() if line.strip()]


def sync(repo: str, wanted: list[dict], dry_run: bool) -> None:
    have = {label["name"].lower(): label for label in gh_list(f"repos/{repo}/labels")}
    for label in wanted:
        body = {"color": label["color"], "description": label.get("description", "")}
        old = next((have[a.lower()] for a in [label["name"], *label.get("aliases", [])] if a.lower() in have), None)
        if old is None:
            print(f"{repo}: create {label['name']}")
            if not dry_run:
                gh("-X", "POST", f"repos/{repo}/labels", body={"name": label["name"], **body})
            continue
        if old["name"] == label["name"] and old["color"] == body["color"] and (old["description"] or "") == body["description"]:
            continue
        print(f"{repo}: update {old['name']}" + (f" -> {label['name']}" if old["name"] != label["name"] else ""))
        if not dry_run:
            path = f"repos/{repo}/labels/{urllib.parse.quote(old['name'], safe='')}"
            gh("-X", "PATCH", path, body={"new_name": label["name"], **body})
        have.pop(old["name"].lower())


def main() -> None:
    args = sys.argv[1:]
    dry_run = "--dry-run" in args
    repos = [a for a in args if a != "--dry-run"] or [
        r["full_name"] for r in gh_list(f"orgs/{ORG}/repos") if not r["archived"]
    ]
    wanted = yaml.safe_load((pathlib.Path(__file__).parents[1] / "labels.yml").read_text())
    for repo in repos:
        sync(repo, wanted, dry_run)


if __name__ == "__main__":
    main()
