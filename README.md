# KAGE

Kelvin's Agent Gauntlet Engine.

KAGE is a Claude Code skill in which Claude and Codex compete on one task. Each competitor is a team
captain that may hand parts of the work to its own workers. Each solution is attacked by the other
model, a blind two-model judge panel scores them all, and you get one synthesized final plus every
candidate ranked.

## How it works

1. **Size and line-up.** It picks 2, 4 or 6 competitors, half Claude and half Codex, each with a
   different angle on the task, and shows you which model and reasoning level each side runs on.
2. **Solve.** Every competitor works on the same task file, independently and in its own folder.
   By default each one is a team captain: it owns its candidate and may start workers of its own,
   following a short playbook ([captain.md](skills/kage/captain.md)) on when a worker is worth it.
   With `--no-team` each competitor is a single agent.
3. **Cross-model attack.** Each solution is attacked once by the other model: Claude attacks what
   Codex made, and Codex attacks what Claude made.
4. **Evidence.** For code, the tests are run on every candidate. For visual work, every candidate is
   screenshotted.
5. **Blind judge panel.** One Claude judge and one Codex judge score every candidate by letter,
   without being told who made which.
6. **Synthesis and blind final check.** The top candidate is improved with the best parts of the
   others, then scored once more against the raw top candidate without labels.

A result looks like this:

```text
FINAL: synthesis
  path: .kage/20261005-141502/final/solution.md
  built from: base C (codex, rigorous) + keepers from A (the rollback steps), D (the summary table)
  final check: 88/100   (raw C: 84)

RANKED
  1. C  codex   rigorous    84.5  Correct throughout; one MINOR attack stands  .kage/20261005-141502/candidates/C/solution.md
  2. A  claude  minimal     79.0  Right but thin on the failure cases          .kage/20261005-141502/candidates/A/solution.md
  3. D  claude  user-first  73.5  Clear, but skips one stated requirement      .kage/20261005-141502/candidates/D/solution.md
  4. B  codex   contrarian  61.0  Reframes the task and answers a different question  .kage/20261005-141502/candidates/B/solution.md

Judging: source only: a text task
Dropped: none
```

If a raw candidate or your earlier answer outscores the synthesis in the final check, the result
says so in a WARNING line.

Every model call is its own command-line process (`claude -p` or `codex exec`), so each side runs on
the model and reasoning level you chose. Nothing stops a slow call. About every 10 minutes KAGE
prints one line per call still running, with how long it has run and whether its log is still
growing, and you can say stop at any of those check-ins.

## Cost

| Competitors | Top-level calls |
| ----------- | --------------- |
| 2           | 8               |
| 4 (default) | 12              |
| 6           | 16              |

Roughly half of the calls use your Codex quota and half use your Claude quota. One extra one-word
Claude call at the start checks that the Claude side can run.

Team mode costs more than solo for the same task. A captain's workers are extra model calls on top
of the table, and how many is the captain's decision, so the true number is not fixed. The gap is
largest on small tasks, where a worker spends more re-reading the task than it saves, and roughly
even on long ones, where cheaper workers do the bulk of the work. Use `--no-team` for small tasks.

The Codex side's cost depends on the captain model you choose: every Codex competitor, attacker and
judge runs on it. The same holds for the Claude side.

## Requirements

- Claude Code, with its `claude` command-line tool on your PATH and logged in (`claude auth status`).
  That login is separate from the desktop app's.
- The Codex CLI, installed and logged in.
- git.
- jq.
- Google Chrome, for screenshots. The path in the skill is the macOS one, so edit it on Linux or
  Windows. Without Chrome, KAGE judges visual work from source.

## Install

```bash
git clone https://github.com/kelvintiger/kage.git
```

Then copy or symlink both `skills/kage` and `skills/arena` into `~/.claude/skills/`. Install both:
`/arena` is a thin alias that reads the `kage` skill.

## Use

```text
/kage <task>
/kage --n 2 --no-team <task>
/kage --claude opus:xhigh --codex <model>:high <task>
/arena <task>
```

| Flag | Meaning |
| ---- | ------- |
| `--n 2\|4\|6` | Number of competitors. Default 4. |
| `--no-team` | Each competitor is a single agent that may not delegate. |
| `--claude <model>[:<effort>]` | Claude captain for this run only. |
| `--codex <model>[:<effort>]` | Codex captain for this run only. |
| `--yes` | Skip the line-up card. |

With no task, it takes your last request and treats the last answer as the one to beat. It never
starts on its own: it runs only when you type `/kage` or `/arena`.

### The line-up

The first time, KAGE asks three questions: the Claude captain's model and reasoning level, the Codex
captain's, and whether each captain picks cheaper tiers for its own workers (the default) or every
worker on a side runs on one model you name. The answers are saved in `~/.claude/kage/lineup.json`.
Every run then shows the line-up and waits for `go` or a change, and a change is saved:

```text
KAGE line-up
  Claude team   captain: opus @ high      workers: captain's choice
  Codex team    captain: <model> @ high   workers: <model> @ medium
  Format        teams, 4 competitors (2 per side), 12 top-level calls
  Judges        one per side, on each captain's model
Captains may start their own workers, so the true number of model calls is not fixed.
Claude processes run in auto permission mode. For a run without prompts, switch this session to auto mode yourself: KAGE never changes your settings.
Run it?  (go / change <what>)
```

Attackers and judges are single agents on their side's captain model. KAGE does not ask about the
angles, the rubric, the judges or time limits.

How workers get their model: a Codex captain names the model and reasoning level each time it
starts a worker. A Claude captain choosing for itself can name a worker's model but not its
reasoning level. A pinned Claude worker gets both from an agent definition KAGE passes in.

## What it never does

It applies nothing to your project. Code candidates live in git worktrees under `.kage/<run>/`, and
it asks before applying a patch.

## Known limits

- Judge blindness is by instruction, not enforced.
- Screenshots are the first screen only, at 1440x900 and 390x844.
- Claude processes run in auto permission mode and are not sandboxed: they are told to stay in
  their own folder, and a classifier reviews risky actions, but nothing confines them. Codex
  competitors and their workers are sandboxed, each team to its own folder. Claude attackers and
  judges are started without any tool that writes or runs commands. KAGE never uses the
  bypass-permissions mode.
- If auto mode is not available on your account, Claude competitors fall back to accepting edits
  inside their own folder and being refused everything else except reading, starting workers and
  the project's test command.
- A call may run for up to 2 hours, the longest a background command can run in Claude Code. KAGE
  never stops one earlier on its own. It checks in about every 10 minutes, and if a call does reach
  the 2-hour ceiling it says so and asks you what to do.
- `--no-team` is enforced on the Claude side (the worker tool is removed) and by instruction only on
  the Codex side, where a competitor that delegates anyway is flagged in the result.
- The two judges are still LLMs, so the ranking is evidence, not proof.
- Tested status. Tested: a Codex captain starting a worker on a named model and reasoning level,
  that worker being unable to write outside the candidate folder, and the check-ins. Checked from
  the command line only, without a live model: that the headless Claude commands are accepted and
  report the requested permission mode at start-up, that Claude attackers and judges have no
  writing tool, that single agents have no worker tool, and that the pinned worker agent is
  registered. Not yet run: a headless Claude competitor, a Claude captain
  starting a worker (including whether a pinned worker's reasoning level takes effect), the
  auto-mode fallback, and a full contest since teams were added. The last full run, a
  2-competitor code task, used the earlier design in which each competitor was one sub-agent.

## Credits

KAGE builds on three MIT-licensed projects.

- Jake Schincariol, [arena-skill](https://github.com/Jakeschincariol/arena-skill): the scoring
  rubric weights and anchors, the attack labels and format (FATAL/MAJOR/MINOR;
  WRONG/MISSING/BREAKS/VAGUE), the fatal-flaw rule and the standalone task-file rules are adapted
  from it. Its licence is reproduced in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- Ivan Rocha, [arena-mode](https://github.com/irr/arena-mode): inspiration for a separate judge
  ranking anonymised candidates.
- zhjai, [agent-arena](https://github.com/zhjai/agent-arena): inspiration for pitting Codex against
  Claude Code.

## License

MIT. See [LICENSE](LICENSE).
