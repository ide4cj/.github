# ide4cj/.github

What every ide4cj repository shares: the issue forms (`.github/ISSUE_TEMPLATE`, GitHub's default
for a repository without its own), [CONTRIBUTING.md](CONTRIBUTING.md), [`labels.yml`](labels.yml)
and its sync, the actions under [`actions/`](actions), and the organization's profile.

Labels by hand, before the organization's app is installed (a token that administers the repositories):

```sh
uv run scripts/sync_labels.py --dry-run   # what it would change
uv run scripts/sync_labels.py             # every repository, or name some: ide4cj/cjls
```

The app: `RELEASE_APP_ID` (a variable) and `RELEASE_APP_KEY` (a secret) of the organization, the app
installed on every repository with contents, issues and administration write, and in the bypass
list of each `master`/`main` ruleset. cjls's release train pushes with it too.
