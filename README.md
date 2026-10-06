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
Mode: teams; Claude <resolved model> @ high, auto mode; Codex <model> @ high, sandboxed
Teams:
  A  claude  worked alone
  B  codex   no worker in its log
  C  codex   workers used: 2 waits logged, number and models not recorded
  D  claude  2 workers started; models in its log: <captain model>, <worker model>
```

If a raw candidate or your earlier answer outscores the synthesis in the final check, the result
says so in a WARNING line.

Every model call is its own command-line process (`claude -p` or `codex exec`), so each side runs on
the model and reasoning level you chose, and each is started in a clean room: without your own
settings, plugins, hooks, skills, MCP servers and memories (the two exceptions are under Known
limits). The project's own conventions reach the competitors through the task file instead, which
names the repository's `CLAUDE.md`, `AGENTS.md` and contributing docs for both sides to read.
Nothing stops a slow call. About every 10 minutes KAGE
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

One measured example, a single small run and not a forecast: a 2-competitor code task in team mode
on 2026-10-06, in which neither captain delegated. The Claude side came to about $1.59 at API list
prices across its four calls (competitor $0.47, attacker $0.34, judge $0.39, synthesizer $0.39).
The Codex side used about 113k tokens across its five calls. Wall-clock time was about 12.5
minutes.

## Requirements

- Claude Code, with its `claude` command-line tool on your PATH and logged in (`claude auth status`).
  That login is separate from the desktop app's, and that copy of `claude` must be recent enough for
  the model you pick (`claude update`). The clean room was checked on 2.1.291.
- The Codex CLI, installed and logged in (`codex login status`). KAGE starts Codex without your
  `~/.codex/config.toml` (see Known limits), so a set-up that only works through that file, such as
  a custom model provider, will not start. The start-up check stops the run and says so.
- KAGE runs whichever `claude` and `codex` come first on your PATH. A stale second copy earlier on
  the PATH (an old npm or Homebrew install beside the current one) is a common cause of "model not
  supported", and of a name like `opus` quietly resolving to an older model. The start-up check and
  the line-up card print the binary, its version and the resolved model, so you can see it. The
  cheapest fix is to name the right binary: set `KAGE_CLAUDE` or `KAGE_CODEX` to its full path in
  your shell profile, or tell KAGE the path when the check stops.
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
| `--yes` | Skip the line-up card and its questions: with no saved line-up it uses the defaults, and a code task with no test command it can find runs without tests and says so. One line with each side's model, version and the Claude permission mode is still printed, and a failed start-up check still stops the run. |

| Environment variable | Meaning |
| -------------------- | ------- |
| `KAGE_CLAUDE` | Full path of the `claude` binary to run, instead of the first one on your PATH. |
| `KAGE_CODEX` | The same for `codex`. |

With no task, it takes your last request and treats the last answer as the one to beat. It never
starts on its own: it runs only when you type `/kage` or `/arena`.

### The line-up

The first time, KAGE asks three questions: the Claude captain's model and reasoning level, the Codex
captain's, and whether each captain picks cheaper tiers for its own workers (the default) or every
worker on a side runs on one model you name. The answers are saved in `~/.claude/kage/lineup.json`.
Every run then shows the line-up and waits for `go` or a change. A change you make there is saved,
and only the field you changed. A model given with `--claude` or `--codex`, or taken from the
`--yes` defaults, is never saved, and neither is the model you name in its place when it fails the
start-up check.

```text
KAGE line-up
  Claude team   captain: opus (<resolved model>) @ high   workers: captain's choice
  Codex team    captain: <model> @ high   workers: <model> @ medium
  Format        teams, 4 competitors (2 per side), 12 top-level calls, text task
  Single agents attackers and judges on each side's captain model; synthesis on Claude's, final check on Codex's
  Binaries      claude: <path> (<version>)   codex: <path> (<version>)
Not in that count: the one-word start-up checks, one retry of any call that fails, and the workers captains start (at most 3 at a time each), so the true number of model calls is not fixed.
Every process starts without your own set-up: no settings, plugins, hooks, skills, MCP servers or memories. Claude processes run in auto permission mode; Codex processes are sandboxed. Codex cannot be started without your personal AGENTS.md and custom agent roles, so it is told to ignore them. For a run without prompts, switch this session to auto mode yourself: KAGE never changes your settings.
Run it?  (go / change <what>)
```

Attackers and judges are single agents on their side's captain model; the synthesis runs on the
Claude captain's model and the final check on the Codex captain's. KAGE does not ask about the
angles, the rubric, the judges or time limits. The result ends with a `Mode` line naming the models
and the Claude permission mode the run actually used, and a `Teams` line per competitor saying
whether it worked alone or used workers. Those are counted from each call's log: exactly for a
Claude captain (how many workers, on which models), and for a Codex captain only whether its log
shows it waiting on a worker.

How workers get their model: a Codex captain names the model and reasoning level each time it
starts a worker. A Claude captain choosing for itself can name a worker's model but not its
reasoning level, so that worker runs at the captain's level. A pinned Claude worker gets both from
an agent definition KAGE passes in.

## What it never does

It applies nothing to your project. Code candidates live in git worktrees under `.kage/<run>/`, and
it asks before applying a patch.

## Known limits

- Judge blindness is by instruction, not enforced. Attackers, judges and the final check start in
  one folder that holds everything they are given (task, rubric, candidates, attacks, test output,
  screenshots) and nothing that names a model or a side: no roster, briefs or logs. Nothing stops
  one from looking elsewhere on the machine.
- Screenshots are the first screen only, at 1440x900 and 390x844.
- The clean room. Every process is started through one wrapper script per tool
  ([claude-call.sh](skills/kage/claude-call.sh), [codex-call.sh](skills/kage/codex-call.sh)),
  which holds that side's fixed flags. Claude processes start without your user, project and local
  settings and what comes with them (plugins and their hooks, your own hooks, output style,
  permission rules, custom agent types), without any `CLAUDE.md` or rules file, auto-memory, MCP
  servers (which is where connected accounts live) and skills. Codex processes start without your
  `~/.codex/config.toml` (MCP servers, plugins, extra writable folders), your approved-command
  rules, apps, plugins, browser control, computer use, memories, hooks, the list of skills and the
  project's `AGENTS.md`. The folder a call starts in is treated the same way. In testing, a hook,
  an instruction file, an MCP server and an agent type planted in the synthesizer's start folder
  did not run, load or appear, and the same folder gave a Codex judge no instruction and no tool.
- What the clean room does not remove on the Codex side: your personal `~/.codex/AGENTS.md` is
  still loaded, and the custom agent roles in your Codex home are still offered to a captain. No
  flag switches either off. KAGE tells every Codex process to leave both alone and tells captains
  to start workers without a role. That is an instruction to the model, not a switch, so your
  personal Codex instructions can still pull that side in a way the Claude side is not pulled. In
  testing, a worker started as a custom role that declared its own sandbox mode and an MCP server
  got neither: it kept its captain's sandbox and had no such tool.
- What the clean room does not cover on either side: configuration installed for the whole machine
  or by an administrator (Claude Code managed settings, system-level or managed Codex
  configuration). Ignoring your user configuration does not touch it, and it was not tested.
  Files are also only not loaded, not hidden: a process that goes looking can read your skills or
  instruction files like any other file. A Claude captain's worker leaves one small metadata file
  under `~/.claude/projects`; otherwise the calls leave no session records.
- Claude processes are not sandboxed. The clean room takes away your set-up, and a fixed tool list
  takes away every built-in tool but these: reading, writing and searching files, running
  commands, web search and fetch, and, in team mode, starting workers. So the tools tied to your
  Claude account (publishing an artifact, scheduling a task, sending a notification) do not exist
  in those processes or in their workers. What is left is a shell with your permissions: auto
  mode's classifier decides command by command, and the brief tells the process to stay in its own
  folder. Nothing confines it. Claude attackers and judges are started with three tools only (read
  a file, list files, search files), so they cannot write or run commands. KAGE never uses the
  bypass-permissions mode.
- Codex competitors and their workers are sandboxed with no network. Each team can write in its
  own folder and in the system temp folders; when the run folder is itself inside a temp folder,
  KAGE closes those too. Codex attackers, judges and the final check are sandboxed read-only. In
  both cases the sandbox limits writing and the network, not reading: a Codex process can read any
  file your account can.
- Reading plus the web is a way out for data. Every process can read any file your account can,
  and both sides keep web access (Claude: web search and fetch; Codex: web search, plus image
  generation). If a competitor's output carries instructions and a later attacker, judge or
  synthesizer follows them, it could read a file and send it out in a web request. Nothing
  technical stops that. Treat a run as you would any agent working on your machine.
- If auto mode is refused for a Claude captain's model (it was for `haiku` in testing), that side's
  competitors fall back to a narrower mode. Edits and simple file commands are accepted inside
  their own folder; reading and starting workers are allowed; the project's test command is
  allowed, exactly as written, and it runs test code the competitor has just written, with no
  sandbox. Anything else that would need approval is refused. A worker runs under its captain's
  mode: in testing a `haiku` worker under an auto-mode captain could write.
- For code tasks, KAGE itself runs the tests of every candidate after the solve step, with your
  permissions and no sandbox. That is code the competitors wrote.
- Applying a patch is your decision, and it can change what your own tools load. For code tasks
  the result lists every tool set-up file a patch adds or changes (`.claude/`, `CLAUDE.md`,
  `.mcp.json`, `AGENTS.md`, `.codex/`). No KAGE process loaded them, but your next session will.
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
- Tested status (codex-cli 0.159.1; claude 2.1.291 unless a line says otherwise).
  One full contest has been run with teams, on 2026-10-06: 2 competitors, team mode, a code task.
  It completed, both candidates and the synthesis passed 12 of 12 tests, and neither captain
  delegated. That run was made before the clean room, the wrapper scripts and the one-folder
  layout for blind roles were added; no full contest has been run since. Everything below was
  tested with live models one call at a time, through the wrapper scripts as shipped, from a run
  folder whose path contains a space, in a shell set to refuse overwriting files.
  Clean room, Claude: a may-write call and a read-only call starting with no plugin, hook, skill,
  MCP server, memory path or custom agent type and the default output style (the built-in agent
  types and three built-in plugins remain listed); the synthesizer shape started in a folder with
  a planted `.claude/settings.json` (hooks), `CLAUDE.md`, rules file, `.mcp.json` and agent type,
  none of which ran, loaded or appeared, where the same planted files under the earlier flags
  ran the hooks and loaded the instruction files and the agent type; a captain writing its file
  and starting a pinned worker on another model; the fallback writing a file; a read-only role
  unable to write.
  Clean room, Codex: a call listing no skill and unable to use one by name; a hook that ran
  under the earlier flags not running; a planted project `AGENTS.md` and `.codex/` folder giving
  no instruction, tool or hook; no MCP, app, browser-control or computer-use tool; a command that
  an approved rule would let out of the read-only sandbox staying inside it; a captain unable to
  write outside its folder; a worker started as a custom role keeping the captain's sandbox and
  network block. Still loaded: the personal `AGENTS.md`, and the custom roles are still offered.
  With the instruction to ignore them, one captain run did not use the wording of the personal
  file and one without the instruction did; that is two runs, not a measurement.
  Both: the start-up checks on a good model, an unknown model and an unknown reasoning level,
  each naming the binary and version; `KAGE_CLAUDE` and `KAGE_CODEX` pointing at a binary; on a
  machine with an older `claude` (2.1.119) first on the PATH, the check showing that binary, a
  name like `opus` resolving to an older model, and a newer model refused with the version it
  needs; the real exit status saved for a call that succeeded and one that failed; a blind role
  reading task, rubric, candidates and attacks from its one start folder and returning a valid
  verdict, three runs out of three on each side; a patch with a binary file applying; the roster
  for 2, 4 and 6; the final folder re-created before a rerun; the team counts against a log with
  a worker and one without; the check-ins, with each record cleared when its call ends and a dead
  record ignored.
  Carried over from earlier rounds and not repeated on this version: a Codex captain's worker on
  a named model and reasoning level, and the limit of three at once (codex-cli 0.159.1); a
  refused auto mode and its fallback scope, a captain's-choice worker on another model, a `haiku`
  worker writing under an auto-mode captain (claude 2.1.212); a solo competitor with no worker
  tool, and a call to publish an artifact or schedule a task failing because the tool does not
  exist (claude 2.1.291, before the clean room).
  Not tested: a full contest on this version; the visual path and 4 or 6 competitors in a
  contest; a Claude captain starting a worker under the fallback; the Claude three-worker limit,
  which is an instruction; managed or system-level configuration on either side; what model and
  instructions a Codex custom role gives a worker; web search or fetch actually used; what a
  Claude process can do to your account through the commands it runs. The `xcrun_db` cache
  warnings mentioned in the skill were seen in the contest run and not reproduced here.

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
