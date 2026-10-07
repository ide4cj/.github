#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Puts every open issue of the organization on its board, through `gh api graphql`.

    scripts/add_to_project.py [--dry-run]

An issue form puts its issue there only when whoever opens it may write to the board, and an issue
opened by `gh`, moved from another repository or opened in a repository made since, not at all. One
added has no priority yet: it waits for triage (CONTRIBUTING.md).

Each repository's open issues are read with the boards they are on, not searched for: a search with
`-project:` under the organization's app found none of six issues off the board (cjls#141..#166).
Every repository the token reaches prints a line, so a run that sees nothing says so.
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


def repositories() -> list[str]:
    query = """query($org: String!, $after: String) {
      organization(login: $org) {
        repositories(first: 100, after: $after, isArchived: false) {
          nodes { name hasIssuesEnabled }
          pageInfo { hasNextPage endCursor }
        }
      }
    }"""
    names, after = [], None
    while True:
        page = graphql(query, org=ORG, **({"after": after} if after else {}))["organization"]["repositories"]
        names += [repo["name"] for repo in page["nodes"] if repo["hasIssuesEnabled"]]
        if not page["pageInfo"]["hasNextPage"]:
            return sorted(names)
        after = page["pageInfo"]["endCursor"]


def open_issues(repo: str) -> list[dict]:
    """The repository's open issues, each with whether it is on the board."""
    query = """query($org: String!, $repo: String!, $after: String) {
      repository(owner: $org, name: $repo) {
        issues(first: 100, after: $after, states: OPEN) {
          nodes { id url projectItems(first: 20) { nodes { project { number owner { ... on Organization { login } } } } } }
          pageInfo { hasNextPage endCursor }
        }
      }
    }"""
    issues, after = [], None
    while True:
        page = graphql(query, org=ORG, repo=repo, **({"after": after} if after else {}))["repository"]["issues"]
        for issue in page["nodes"]:
            boards = issue["projectItems"]["nodes"]
            on_board = any(b["project"]["number"] == PROJECT and b["project"]["owner"].get("login") == ORG for b in boards)
            issues.append({"id": issue["id"], "url": issue["url"], "on_board": on_board})
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
    repos = repositories()
    if not repos:
        sys.exit(f"the token reaches no repository of {ORG}")
    for repo in repos:
        issues = open_issues(repo)
        off = [issue for issue in issues if not issue["on_board"]]
        print(f"{ORG}/{repo}: {len(issues)} open, {len(off)} off the board")
        for issue in off:
            print(f"  add {issue['url']}")
            if not dry_run:
                graphql(
                    "mutation($p: ID!, $c: ID!) { addProjectV2ItemById(input: {projectId: $p, contentId: $c}) { item { id } } }",
                    p=project,
                    c=issue["id"],
                )


if __name__ == "__main__":
    main()
