# Contributing to ide4cj

ide4cj is the Cangjie developer experience: [cjls](https://github.com/ide4cj/cjls), the language
server, and its editor clients — [cangjie.nvim](https://github.com/ide4cj/cangjie.nvim),
[cangjie-vscode](https://github.com/ide4cj/cangjie-vscode), [cangjie-zed](https://github.com/ide4cj/cangjie-zed).
Why the process is what it is: cjls's [D32](https://github.com/ide4cj/cjls/blob/master/docs/adr/0032-one-process-for-server-and-clients.md).
How to build and test one repository: its own README (cjls: `CLAUDE.md` and `CONTRIBUTING.md`).

## Commits and pull requests

[Conventional Commits](https://www.conventionalcommits.org), checked by [cocogitto](https://docs.cocogitto.io)
on every commit and on the PR's title, which becomes the commit: PRs are squash-merged.

## A change across the server and a client

The server does what LSP can; a client finds the binary, passes settings, and gives the server's
extensions their UI. A feature a client needs from the server is therefore two changes:

1. **One branch name in both repositories**, say `feat/expand-macro`. A client's CI takes cjls's
   build of that branch (`actions/cjls` here), so the pair is checked there; cjls's CI runs no
   client, it holds the server to the protocol by its `tests/e2e`, and a client's failure that is the
   server's becomes a case there. Both PRs are green before either merges.
2. **The server merges first**, its extension behind an `experimental` capability and described in
   [`lsp-extensions.md`](https://github.com/ide4cj/cjls/blob/master/docs/lsp-extensions.md) (a
   test holds the file to the code). The client gates on that capability, never on a version, and
   merges once cjls's `nightly` has it.
3. The client's stable release follows the next cjls release, when its pin moves.

Track it as a parent issue in cjls (type Task) with a sub-issue in each client.

## Channels

| | stable | follows master |
|---|---|---|
| cjls | a release every Monday from a green master (`vX.Y.Z`) | `nightly`, every night, master's newest green commit |
| cangjie-vscode | even minor, the pinned cjls inside | pre-release, odd minor, the nightly inside |
| cangjie.nvim | the pinned cjls, downloaded | `vim.g.cjls_version = 'nightly'` |
| cangjie-zed | the newest cjls within its minor | `"lsp": { "cjls": { "settings": { "version": "nightly" } } }` |

A client's pin is bumped by Renovate on Mondays, after the release; the client releases once that PR
is merged. A client supports the server's current minor and the one before; a deprecated extension
or setting stays two releases.

## Issues and labels

Every open issue of the organization is on [one board](https://github.com/orgs/ide4cj/projects/1)
(`.github/workflows/project.yml` adds those an issue form did not), and its priority is the board's
**Priority**, not a label, as where it stands is its **Status** (Backlog, Ready, In progress,
Blocked — on another issue, upstream, or whoever opened it —, In review, Done):

| | |
|---|---|
| **P0** | broken for a user now: a crash, a lost answer, no install. Taken before anything else |
| **P1** | on the way to the current goal |
| **P2** | some day |
| none | not triaged yet |

The current goal: **name resolution** — the analysis below it first (cjls#119), then go to
definition. A new goal is a change of this line.

An issue's kind is its type (Bug, Feature, Task), set for the whole organization. [`labels.yml`](labels.yml) is every repository's labels, synced by `.github/workflows/labels.yml`:

| prefix | what | |
|---|---|---|
| — | kind | the issue's **type**: Bug, Feature, Task; `question` labels an open design question |
| `E-` | effort | `E-easy`, `E-hard`, `E-help-wanted` |
| `A-` | part of the server | `A-analysis`, `A-syntax`, `A-protocol`, `A-highlighting`, `A-performance`, `A-install`, `A-infra` |
| `client:` | editor client | `client:nvim`, `client:vscode`, `client:zed`; `needs-server`: waits on cjls |

On Mondays: the red daily runs first (each client opens an issue when its run against `nightly` and
the editor's own nightly fails), then triage (every issue without a priority gets one, and its `A-`
or `client:`), then the release train, the pin PRs merged and the clients released.

## Shared actions

| | |
|---|---|
| `ide4cj/.github/actions/paired-branch@master` | the branch of another repository named like this run's, or its default |
| `ide4cj/.github/actions/cjls@master` | the cjls binary for a client's tests: the paired branch's build, else a release (the pin or `nightly`) |
