#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Puts every open issue of the organization on its board, through `gh api graphql`.

    scripts/add_to_project.py [--dry-run]

An issue form puts its issue there only when whoever opens it may write to the board, and an issue
opened by `gh`, moved from another repository or opened in a repository made since, not at all. One
added has no priority yet: it waits for triage (CONTRIBUTING.md).
"""

import json
import subprocess
import sys

ORG = "ide4cj"
PROJECT = 1


def graphql(query: str, **variables: object) -> dict:
    cmd = ["gh", "api", "graphql", "-f", f"query={query}"]
    for name, value in variables.items():
        cmd += ["-F" if isinstance(value, int) else "-f", f"{name}={value}"]
    out = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return json.loads(out.stdout)["data"]


def off_board() -> list[dict]:
    query = """query($q: String!, $after: String) {
      search(type: ISSUE, query: $q, first: 100, after: $after) {
        nodes { ... on Issue { id url } }
        pageInfo { hasNextPage endCursor }
      }
    }"""
    q = f"org:{ORG} is:issue is:open -project:{ORG}/{PROJECT}"
    issues, after = [], None
    while True:
        page = graphql(query, q=q, **({"after": after} if after else {}))["search"]
        issues += page["nodes"]
        if not page["pageInfo"]["hasNextPage"]:
            return issues
        after = page["pageInfo"]["endCursor"]


def main() -> None:
    dry_run = "--dry-run" in sys.argv[1:]
    project = graphql(
        "query($org: String!, $n: Int!) { organization(login: $org) { projectV2(number: $n) { id } } }",
        org=ORG,
        n=PROJECT,
    )["organization"]["projectV2"]["id"]
    for issue in off_board():
        print(f"add {issue['url']}")
        if not dry_run:
            graphql(
                "mutation($p: ID!, $c: ID!) { addProjectV2ItemById(input: {projectId: $p, contentId: $c}) { item { id } } }",
                p=project,
                c=issue["id"],
            )


if __name__ == "__main__":
    main()
