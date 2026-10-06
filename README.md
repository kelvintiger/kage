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

Roughly half of the calls use your Codex quota and half use your Claude quota. Not in the table:
before the contest, a one-word call per model in the line-up checks that each side can start (one
per side, two with a pinned worker model), and a call that fails or returns nothing is retried once.

Team mode costs more than solo for the same task. A captain's workers are extra model calls on top
of the table, and how many is the captain's decision, so the true number is not fixed. The gap is
largest on small tasks, where a worker spends more re-reading the task than it saves, and roughly
even on long ones, where cheaper workers do the bulk of the work. Use `--no-team` for small tasks.

The Codex side's cost depends on the captain model you choose: every Codex competitor, attacker and
judge runs on it, and so does the final check. The same holds for the Claude side, whose captain
model also runs the synthesis.

## Requirements

- Claude Code, with its `claude` command-line tool on your PATH and logged in (`claude auth status`).
  That login is separate from the desktop app's, and that copy of `claude` must be recent enough for
  the model you pick (`claude update`). The line-up card shows which model a name like `opus`
  resolved to on that copy.
- The Codex CLI, installed and logged in (`codex login status`). KAGE starts Codex without your
  `~/.codex/config.toml` (see Known limits), so a set-up that only works through that file, such as
  a custom model provider, will not start. The start-up check stops the run and says so.
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
| `--claude <model>[:<effort>]` | Claude captain for this run only. Never saved. |
| `--codex <model>[:<effort>]` | Codex captain for this run only. Never saved. |
| `--yes` | Skip the line-up card. One line with each side's model and the Claude permission mode is still printed. |

With no task, it takes your last request and treats the last answer as the one to beat. It never
starts on its own: it runs only when you type `/kage` or `/arena`.

### The line-up

The first time, KAGE asks three questions: the Claude captain's model and reasoning level, the Codex
captain's, and whether each captain picks cheaper tiers for its own workers (the default) or every
worker on a side runs on one model you name. The answers are saved in `~/.claude/kage/lineup.json`.
Every run then shows the line-up and waits for `go` or a change. A change you make there is saved,
and only the field you changed; a model given with `--claude` or `--codex` is never saved.

```text
KAGE line-up
  Claude team   captain: opus (<resolved model>) @ high   workers: captain's choice
  Codex team    captain: <model> @ high   workers: <model> @ medium
  Format        teams, 4 competitors (2 per side), 12 top-level calls
  Single agents attackers and judges on each side's captain model; synthesis on Claude's, final check on Codex's
Not in that count: the one-word start-up checks, one retry of any call that fails, and the workers captains start (at most 3 at a time each), so the true number of model calls is not fixed.
Claude processes run in auto permission mode. Codex processes are sandboxed and start without your Codex config. For a run without prompts, switch this session to auto mode yourself: KAGE never changes your settings.
Run it?  (go / change <what>)
```

Attackers and judges are single agents on their side's captain model; the synthesis runs on the
Claude captain's model and the final check on the Codex captain's. KAGE does not ask about the
angles, the rubric, the judges or time limits. The result ends with a `Mode` line naming the models
and the Claude permission mode the run actually used.

How workers get their model: a Codex captain names the model and reasoning level each time it
starts a worker. A Claude captain choosing for itself can name a worker's model but not its
reasoning level, so that worker runs at the captain's level. A pinned Claude worker gets both from
an agent definition KAGE passes in.

## What it never does

It applies nothing to your project. Code candidates live in git worktrees under `.kage/<run>/`, and
it asks before applying a patch.

## Known limits

- Judge blindness is by instruction, not enforced. Attackers, judges and the final check start in a
  folder that holds only the work they are given, so listing where they are shows no logs, briefs
  or roster, but nothing stops one from looking elsewhere in the run folder.
- Screenshots are the first screen only, at 1440x900 and 390x844.
- Claude processes run in auto permission mode and are not sandboxed: they are told to stay in
  their own folder, and a classifier reviews risky actions, but nothing confines them. Claude
  attackers and judges are started with three tools only (read a file, list files, search files),
  so they cannot write or run commands. KAGE never uses the bypass-permissions mode.
- Codex competitors and their workers are sandboxed with no network. Each team can write in its
  own folder and in the system temp folders; when the run folder is itself inside a temp folder,
  KAGE closes those too. Codex attackers, judges and the final check are sandboxed read-only. In
  both cases the sandbox limits writing and the network, not reading: a Codex process can read any
  file your account can.
- What each side is started without. Claude processes: your MCP servers (which is where connected
  accounts live) and your skills. Codex processes: your `~/.codex/config.toml`, so none of the MCP
  servers, plugins or extra writable folders set there, and your approved-command rules, which
  would otherwise let a matching command run outside the sandbox even in read-only mode; apps,
  plugins, browser control, computer use and memories are switched off as well. In testing, a
  Codex call started this way, and a worker started by a captain, listed no MCP, app,
  browser-control or computer-use tool, and a command that an approved rule had let out of the
  read-only sandbox stayed inside it.
- What each side keeps. Codex calls, the read-only ones included, keep Codex's built-in web search
  and image generation. Claude competitors and the synthesizer are started with a fixed tool list:
  reading, writing and searching files, running commands, web search and fetch, and, in team mode,
  starting workers. Claude Code's other built-in tools are not on it, so the ones tied to your
  Claude account (publishing an artifact, scheduling a task, sending a notification) do not exist
  in those processes or in their workers. Running commands is still on the list, and for that
  auto mode's classifier and the brief are the only barrier.
- Both sides load your personal instructions, which can pull a side in another direction: a Claude
  process reads `~/.claude/CLAUDE.md` and runs your hooks, and a Codex process reads
  `~/.codex/AGENTS.md` and sees your Codex skills. In testing, a Claude instruction asking for a
  plan and approval before non-trivial changes did not stop a competitor from finishing.
- If auto mode is refused for a Claude captain's model (it was for `haiku` in testing), that side's
  competitors fall back to a narrower mode. Edits and simple file commands are accepted inside
  their own folder; reading and starting workers are allowed; the project's test command is
  allowed, exactly as written, and it runs test code the competitor has just written, with no
  sandbox. Anything else that would need approval is refused, unless your own Claude Code
  permission rules allow it. Your hooks still run. A worker runs under its captain's mode: in
  testing a `haiku` worker under an auto-mode captain could write.
- For code tasks, KAGE itself runs the tests of every candidate after the solve step, with your
  permissions and no sandbox. That is code the competitors wrote.
- A call may run for up to 2 hours, the longest a background command can run in Claude Code. KAGE
  never stops one earlier on its own. It checks in about every 10 minutes, and if a call does reach
  the 2-hour ceiling it says so and asks you what to do. A check-in knows a call is running from a
  recorded process number, cleared when the call ends. After a call is stopped from outside, that
  number can match another program, and a check-in can list the call as running until KAGE clears
  the record.
- `--no-team`: a Claude competitor is started without the worker tool. A Codex competitor still has
  its worker tool, because no switch we tried removes it, and is only told not to use it. KAGE
  counts the lines Codex logs when a call waits on a worker and names any solo competitor that has
  one in the result; a worker that was started and never waited on would not show up. Attackers,
  judges and the final check are told to start no other agents: the Claude ones have no worker
  tool, the Codex ones do.
- A Codex captain cannot run more than three workers at once: a fourth is refused until one
  finishes. A Claude captain is only told the same limit. Nothing caps how many workers a captain
  starts over a whole run.
- The two judges are still LLMs, so the ranking is evidence, not proof.
- Tested status. A full contest has not been run since teams were added: the last full run, a
  2-competitor code task, used the earlier design in which each competitor was one sub-agent.
  Everything else here was tested with live models one call or one competitor at a time
  (codex-cli 0.159.1; claude 2.1.212, with the start-up check and the fixed-tool-list checks
  repeated on claude 2.1.291).
  Codex: a captain starting a worker on a named model and reasoning level; with the containment
  flags, a call and a captain's worker listing no MCP, app, browser-control or computer-use tool;
  that worker unable to write outside the candidate folder, reach the network, or get a command
  out of the sandbox through an approved rule; the limit of three workers at once, and a finished
  worker freeing its place; the start-up check on a good model, an unknown model and an unknown
  reasoning level; a read-only call reading the task, rubric, attack and evidence files from the
  candidates folder.
  Claude: the start-up check, including a refused auto mode, an unknown model, an unknown
  reasoning level and a `claude` too old for the model; a competitor writing its file in auto
  mode; a captain starting a pinned worker on another model and reasoning level, and a
  captain's-choice worker on another model; a `haiku` worker writing under an auto-mode captain;
  an attacker that cannot write and whose answer lands in its output file; a failed read-only
  call leaving its output file empty; a read-only call reading files outside the folder it
  starts in; a solo competitor with no worker tool; a competitor and a
  captain's pinned worker each writing a file under the fixed tool list, and a call to publish an
  artifact or schedule a task failing there because the tool does not exist; two team-mode competitors finishing a small
  code task with passing tests; the fallback's edit scope, on one model.
  Both: the launch commands in a project path that contains a space, in a shell set to refuse
  overwriting files; the check-ins, including the record being cleared when a call ends.
  Not tested: the synthesizer, judge and final-check briefs end to end; a Claude captain starting a
  worker under the fallback; whether your own permission rules widen the fallback; the Claude
  three-worker limit, which is an instruction; what a Claude process can do to your account
  through the commands it runs.

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
