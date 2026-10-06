# KAGE: decisions

Each entry: decision / choice / standard it follows / rejected alternative / what breaks next
quarter / how to reverse.

## Product choices (the user's)

- Runs only when `/kage` or `/arena` is typed (`disable-model-invocation: true`); it never fires on its own.
- Output is one synthesized final first, then every candidate ranked, with identities revealed only
  there. If a raw candidate or the baseline outscored the synthesis, the output says so.
- Code tasks run for real: one git worktree per candidate, tests executed by the orchestrator.
- Judges of visual work see real screenshots (desktop and mobile), not only source.
- Teams by default: each competitor is a team captain that owns its candidate and may start its own
  workers. `--no-team` gives the earlier behaviour, one agent per competitor that may not delegate.
  Attackers, judges, the synthesizer and the final check are always single agents.
- Captains get a playbook (`skills/kage/captain.md`) on when a worker is worth it, which tier to use,
  how to brief and how to check. It is copied into the run folder and the brief points at it.
- The line-up (each side's captain model and reasoning level, and whether workers are the captain's
  choice or one pinned model) is asked once, remembered, shown before every run and confirmed with
  "go". Lenses, rubric, judge setup and time limits are never asked.
- Attackers and judges run on their own side's captain model and reasoning level.
- Claude processes run in auto permission mode: KAGE assumes approval instead of prompting. It never
  uses the bypass-permissions mode and never changes the user's own settings.
- No time limit below the platform's 2-hour ceiling for a background command. Instead, a check-in
  about every 10 minutes says what is still running, and only the user stops a call.
- The name is KAGE (Kelvin's Agent Gauntlet Engine), runnable as `/kage` or `/arena`.
- The repository is public under the MIT licence.
- Credits: the rubric weights and anchors, the attack labels and format, the fatal-flaw rule and
  the standalone task-file rules are adapted from Jake Schincariol's arena-skill (MIT, reproduced in
  `THIRD_PARTY_NOTICES.md`). Ivan Rocha's arena-mode inspired the separate judge ranking anonymised
  candidates, and zhjai's agent-arena inspired pitting Codex against Claude Code.

## Technical decisions

1. **Blind two-model judge panel, no bracket.**
   Choice: one Claude judge and one Codex judge score every candidate; rank by the mean.
   Standard: panel of LLM evaluators (Verga et al. 2024, "Replacing Judges with Juries"). Judges
   from different model families reduce a single model's preference for its own output.
   Rejected: single elimination, where one noisy verdict can knock out the best answer.
   Breaks next quarter: the two judges disagree sharply and the mean hides it. `ranking.md` keeps
   both totals side by side so the disagreement is visible.
   Reverse: add a third judge or drop to one by editing step 7; nothing else depends on the count.

2. **Codex sandboxing by role.**
   Choice: competitors run `--sandbox workspace-write` rooted (`-C`) at their own candidate folder;
   attackers, judges and the final check run `--sandbox read-only` with `-o` capturing the answer.
   Standard: least privilege (OWASP ASVS access-control principle): each role gets only the access
   its job needs.
   Rejected: read-only competitors with their answer captured as one text blob, which cannot
   produce multi-file work (a site, a code change).
   Breaks next quarter: Codex's workspace-write always includes `/tmp` and `$TMPDIR`, so a run
   folder under those lets a competitor write into its neighbours. Verified here; the skill adds
   the two `exclude_*` flags in that case. Claude processes are not sandboxed at all: their scope
   is the brief's instruction, under the permission mode of decision 15. A Codex captain's workers
   inherit the captain's sandbox (verified, decision 14).
   Reverse: change the `--sandbox` values in steps 5 and 6.

3. **Candidate worktrees inside the repo, under `.kage/<run>/candidates/`.**
   Standard: Claude Code's own nested dot-directory convention (`.claude/worktrees/`).
   Rejected: worktrees outside the repo (the file pane cannot open them, edits prompt for
   permission).
   Breaks next quarter: stale runs left in the repo get crawled by jest or tsc. The skill prints the
   cleanup command and keeps `.kage/` in `.git/info/exclude`.
   Reverse: change the paths in step 4; patches are plain `git diff` output and apply anywhere.

4. **Headless Chrome CLI for screenshots.**
   Standard: platform-native and already installed; it writes PNGs to disk without putting images
   in the orchestrator's context.
   Rejected: browser-pane screenshots (they land in the orchestrator's context and do not exist in
   terminal sessions).
   Breaks next quarter: a Chrome update changes headless flags. A missing or empty PNG falls back to
   source-only judging, which the result states.
   Reverse: replace the two commands in step 5.

5. **Plain files as state, no state machine.**
   Choice: at most 16 top-level calls, each leaving one artifact; `ls -R` shows progress and resume is "first
   missing file". Rejected: a `bracket.py`-style tracker.
   Breaks next quarter: nothing validates a half-written artifact; a truncated verdict is caught
   only because `jq` fails on it, which triggers the one rerun.
   Reverse: add a tracker later; the file layout would not change.

6. **Two commands through a thin alias skill.**
   Choice: `skills/kage/` holds the skill; `skills/arena/` is a few lines that read the main
   `SKILL.md` and follow it with the arguments the user typed.
   Standard: one source of truth with a thin alias (the shell-alias and symlink convention): the
   behaviour is written once and every other name points at it.
   Rejected: two full copies, which would drift apart; and omitting `name` and symlinking one folder
   twice, which relies on undocumented name-from-directory behaviour.
   Breaks next quarter: the alias cannot find the main file because only `skills/arena` was
   installed. The alias says to look for the `kage` folder beside it, and the README installs both.
   Reverse: delete `skills/arena/`.

## Found during verification (2026-10-05, Chrome 154, codex-cli 0.159.1)

7. **Mobile screenshots go through an iframe wrapper.** `--window-size=390,844` alone produced a
   390px-wide PNG of a 500px layout: Chrome's minimum window width is 500, so the page was cropped
   and its mobile breakpoint never fired. A one-line wrapper page holding a 390x844 iframe gives a
   true 390px viewport. Rejected: a 500px "mobile" size (misses 480px breakpoints). Reverse: delete
   the wrapper if a later Chrome honours narrow windows.

8. **Extra Chrome flags.** `--virtual-time-budget=5000` so content revealed by scripts or entry
   animations is in the shot (without it, a 1.5s reveal was missing); `--hide-scrollbars`. No
   `--user-data-dir`: with a fresh profile Chrome wrote the PNG but stayed alive for 100+ seconds.
   Chrome exits 0 even when it writes nothing, so success is checked on the file.

9. **Briefs point at `task.md` instead of embedding it.** With no script to fill templates, an
   orchestrator retyping the task into up to 16 briefs would drift. One shared file is
   byte-identical by construction. Breaks next quarter: an agent skips the read; every template
   opens with it. Reverse: paste the task into the template.

10. **Codex image input.** `-i` is variadic: `-i shot.png "prompt"` swallowed the prompt and exited 1.
   Working form: one `-i` per image, then `-o <file>`, prompt on stdin via `-`.

11. **No positional `$N` in the skill's shell snippets.** Claude Code substitutes `$0`, `$1`, ... in
    skill text with the user's arguments, so an `awk '{print $0}'` would be corrupted. The roster
    command uses `paste` instead.

12. **The final-check shuffle is one explicit command.** In the first end-to-end run the orchestrator
    improvised the X/Y mapping with `set -- $ORDER`; zsh does not split an unquoted variable, so one
    folder was left empty and the judge scored a missing solution 0. The skill now gives the exact
    `paste ... | tee -a roster.md` line and says to confirm every `finalcheck/` folder is non-empty.
    Reverse: none needed.

## End-to-end run (2026-10-05)

A 2-competitor code task (fix a `slugify` function against 3 tests) in a throwaway git repo: both
candidates passed the tests, both attackers reported no attacks, both judges returned valid JSON and
ranked the Codex candidate first (100 vs 97), and the blind final check scored the raw winner above
the synthesis (100 vs 96), which the result reported in its WARNING line. Not covered by that run:
the screenshot path, 4 or 6 competitors, a standing attack, a rejected-answer baseline, the retry and
drop paths.
That run used the earlier design, in which each Claude role was an Agent-tool sub-agent and Codex
ran on its configured model. Nothing below has been through a full contest yet.

## Teams, line-up and headless Claude (2026-10-06)

13. **Every Claude role is a headless `claude -p` process, not an Agent-tool call.**
    Choice: Claude competitors, attackers, judges and the synthesizer are launched from Bash exactly
    like the Codex ones, with `--model`, `--effort` and `--permission-mode`.
    Standard: the vendor's documented non-interactive mode (Claude Code print mode, the interface
    its SDK and CI integrations are built on) and one process per job. It is the standard because
    both vendors expose model, reasoning level and permissions as process flags, so one launch
    shape covers both sides and each call's settings are visible in its command line.
    Rejected: Agent-tool sub-agents. A call cannot be given a reasoning level, shares the
    orchestrator's permission mode, and cannot be stripped down to read-only tools.
    Breaks next quarter: the `claude` command on the PATH is logged out, or older than the app
    running the session, while the session itself works (this happened during verification). Every
    Claude call would fail, so step 1 makes a one-word call first and stops with the reason. A
    user's personal instruction file is also loaded by every headless process and can pull the
    Claude side in a direction the Codex side does not get.
    Reverse: swap the two Claude launch shapes for Agent calls; briefs and files do not change.

14. **Workers are pinned through each tool's own sub-agent interface, per invocation.**
    Choice: a Codex captain passes `model` and `reasoning_effort` to `spawn_agent` with `fork_turns`
    "none"; a pinned line-up also sets `agents.default_subagent_model` and
    `agents.default_subagent_reasoning_effort` with `-c`. A Claude captain choosing for itself sets
    the Agent tool's `model` parameter (it has no reasoning-level parameter); a pinned line-up
    passes one agent definition, `kage-worker`, with `--agents`, carrying model and effort.
    Standard: first-party configuration passed on the command line (the "config by flag, nothing
    installed" half of twelve-factor config). It is the standard for a shared tool because nothing
    persists on the machine and the behaviour does not depend on files only one user has.
    Rejected: agent files in `~/.codex/agents` or `~/.claude/agents` (private to one machine, and
    they outlive the run); captains starting nested `codex exec` or `claude -p` processes through
    their shell (outside the tool's own agent tracking and, on Codex, blocked by the sandbox).
    Breaks next quarter: a Codex release renames the `spawn_agent` arguments or the `agents.*` keys
    and pinned workers silently run on the captain's model while the card says otherwise. Check the
    way it was verified: run one captain without `--ephemeral` and read the model recorded in the
    worker's session file. On the Claude side, a CLI that ignores `effort` in an agent definition
    would run pinned workers at its default level.
    Reverse: set `workers` to `"captain"`; no flag is then added.

15. **Claude permission fallback and read-only roles use allow-lists, not broader modes.**
    Choice: if auto mode is refused, competitors run `acceptEdits` with `--allowedTools` for Read,
    Glob, Grep, the worker tool and the test command. Edit and Write are deliberately not on that
    list: a bare allow would permit writes anywhere, while `acceptEdits` already accepts them
    inside the candidate folder only. Attackers and judges run with `--tools "Read,Glob,Grep"`, so
    they have no tool that writes or runs commands, and their answer is taken from the output
    stream the way `-o` takes Codex's.
    Standard: least privilege with default deny (OWASP ASVS access control), the same rule decision
    2 applies to Codex.
    Rejected: `bypassPermissions` or `--dangerously-skip-permissions` (every check off in an
    unattended process, including for whatever a file it reads talks it into); `plan` mode for
    read-only roles (it is a mode the model works inside, not the absence of write tools, and it
    shapes the answer into a plan).
    Breaks next quarter: under the fallback a Claude competitor needs a command that is not listed
    (a build step, a code generator), is refused, and loses to a Codex competitor that could run
    it. The card says when the fallback is in use, so a lopsided result can be read in that light.
    Reverse: edit the "Claude permissions" paragraph of the skill.

16. **Check-ins are a shipped script that exits to wake the orchestrator.**
    Choice: each background call records its process id in `logs/<name>.pid`. `heartbeat.sh` waits
    up to 10 minutes, or until no recorded process is alive, then prints one line per live call
    with its age and whether its log changed during the interval. The orchestrator restarts it
    while calls remain. It never signals a process.
    Standard: the Unix pid-file and `kill -0` liveness probe (what init scripts and process
    supervisors have used since System V), with file modification time as the activity signal. It
    is the standard because it needs nothing beyond a POSIX shell.
    Rejected: polling from the orchestrator (foreground sleep is not available to it and each poll
    costs a turn); one long-running monitor loop (a background command only notifies when it
    exits, so a loop that never exits never wakes anyone); retyping the script into each run
    folder (decisions 9 and 12: text an orchestrator retypes drifts).
    Breaks next quarter: a process id is reused and a finished call is listed as running, or a
    Claude call thinks for more than 10 minutes without emitting an event and is listed as quiet.
    Both produce a wrong line, never a wrong action, because nothing acts on the lines but the user.
    Reverse: delete the paragraph and the script; calls still notify when they finish.

17. **The line-up lives in `~/.claude/kage/lineup.json`; flags override it for one run.**
    Standard: per-user tool settings in the tool's own dot-directory, with command-line flags
    overriding the file for a single invocation (`git -c`, `codex -c`). It is the standard because
    the choice is about the user's accounts, not about a project.
    Rejected: the skill folder (a git checkout, overwritten on update); the project's `.kage/`
    (asked again in every repository); Claude Code's own settings file (not KAGE's to write).
    Breaks next quarter: a saved model name is retired. The one-word call in step 1 fails for
    Claude, or the first Codex call fails, and the user changes the line-up at the card.
    Reverse: delete the file and the questions are asked again.

18. **Claude logs are JSON event streams.** With plain text output a Claude log stays empty until
    the call ends, so a check-in could not tell working from stuck. `--output-format stream-json`
    grows as the call works, and `jq` takes the final message from the last event. Breaks next
    quarter: the event shape changes and the extracted file is `null`, which the skill treats as a
    missing output (one retry, then dropped). Reverse: use text output redirected to the output file.

## Found during verification (2026-10-06, claude 2.1.212, codex-cli 0.159.1)

- **Codex worker pinning, per call.** A captain on one model at high started a worker with
  `spawn_agent` (`model`, `reasoning_effort`, `fork_turns` "none"). The worker's session file
  recorded the requested model and effort and the captain's thread as its parent, both for the
  machine's default worker model and for a different model at a different effort.
- **Codex worker pinning, by config.** With `-c 'agents.default_subagent_model=...'` and
  `-c 'agents.default_subagent_reasoning_effort=...'` and no arguments from the captain, the worker
  ran on the configured model and effort.
- **`spawn_agent` conditions.** A model or effort override is accepted only with `fork_turns`
  "none" or a number, and the tool asks for an explicit request to delegate, so the brief gives one.
- **The sandbox holds for workers.** The worker's session recorded the captain's policy
  (`workspace-write` with both `exclude_*` flags), and its `echo x > ../escape.txt` failed with
  "operation not permitted" in each of four runs.
- **Solo on Codex is by instruction.** With `--disable multi_agent`, with `--disable
  multi_agent_v2` added, and with `-c agents.max_depth=0`, the model still listed `spawn_agent`.
- **Check-ins.** With a 20-second interval, a silent `sleep 70` and a second process writing a line
  every 5 seconds: the first check-in listed both (one "log growing", one "no new output"), the
  second listed only the one still alive, and the third returned "no calls running" as soon as it
  ended.
- **The `claude` login is separate from the session's.** Here the session was logged in and the
  `claude` command was not, so every headless call ended in an authentication error before
  reaching a model. Hence the one-word call in step 1.
- **Headless Claude, checked without a model.** Because of that login, these come from the start-up
  event of calls that then failed to authenticate. `--tools "Read,Glob,Grep"` left exactly those
  three tools. `--disallowedTools Agent` removed the worker tool, which this version lists as
  `Task`. `--agents` registered `kage-worker`. `auto`, `dontAsk` and `acceptEdits` were each
  reported as the session's permission mode. An unknown `--effort` value is ignored with a warning.
- **Not verified, for the same reason:** a Claude competitor writing a file in auto mode; whether
  auto mode is accepted on a given account and what the start-up event shows when it is not; a
  Claude captain starting a worker on another model; whether `effort` in an agent definition takes
  effect; a read-only role's answer landing in its output file. Run these before relying on the
  Claude side.
