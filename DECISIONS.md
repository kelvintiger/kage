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
- Every KAGE process starts in a clean room: none of the user's personal plugins, hooks, settings,
  output style, instruction files, custom agents, skills or memories, and nothing a competitor
  left in its folder, with both sides on the same footing. A project's own conventions reach the
  competitors through the task file, which names the repository's instruction files.
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
   inherit the captain's sandbox (verified, decision 14). The sandbox flag alone turned out not to
   be enough: a user's Codex configuration and approved-command rules reach past it (decisions 19
   and 22).
   Reverse: change the `--sandbox` values in the two Codex launch shapes ("Launching a call").

3. **Candidate worktrees inside the repo, under `.kage/<run>/blind/candidates/`.**
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
    Claude call would fail, so step 1 makes a one-word call first and stops with the reason, the
    binary and its version. A user's personal instruction file was also loaded by every headless
    process; decision 22 closed that on the Claude side.
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
    would run pinned workers at its default level. (Checked since: claude 2.1.212 applies both
    `model` and `effort` from the definition, and a worker started with only the `model`
    parameter runs at the captain's effort. Check it the same way: the `effort` recorded on each
    turn of the worker's session transcript.)
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
    Trigger (observed, see below): a refused auto mode is not an error. The call runs in `default`
    mode, every write is denied, and the model may still reply DONE. Start-up reports the downgrade
    either in the `init` event or in a `status` event next to an `init` that still says `auto`, so
    the step 1 check collects the mode from every system event and requires exactly `auto`. The
    refusal belongs to the model that runs the session, so the trigger is the captain's model only:
    a `haiku` worker under an auto-mode `opus` captain wrote files, both as a captain's-choice
    worker and as a pinned one (second round below). A pinned worker model still gets the step 1
    call, to catch a name or level that does not exist, but its mode line is ignored.
    What the fallback does not do: the allowed test command runs code the competitor just wrote,
    unsandboxed. The user's own permission rules and hooks are no longer loaded (decision 22).
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
    The second is only a wrong line. The first was more than that: the orchestrator starts another
    check-in while any call is listed, so a stale record could keep it checking in for ever. Each
    launch now removes its own record when the call ends, and the orchestrator removes the record
    of any call whose completion notice has arrived, which covers a call stopped from outside (the
    2-hour ceiling) that never reached its own clean-up. What is left is a wrong line for at most
    one check-in.
    Reverse: delete the paragraph and the script; calls still notify when they finish.

17. **The line-up lives in `~/.claude/kage/lineup.json`; flags override it for one run.**
    Standard: per-user tool settings in the tool's own dot-directory, with command-line flags
    overriding the file for a single invocation (`git -c`, `codex -c`). It is the standard because
    the choice is about the user's accounts, not about a project.
    Rejected: the skill folder (a git checkout, overwritten on update); the project's `.kage/`
    (asked again in every repository); Claude Code's own settings file (not KAGE's to write).
    What is written: the answers to the first-run questions, and afterwards only a field the user
    changes at the card. A value given with `--claude` or `--codex` applies to that run and is
    never written, also when another field is changed at the card in the same run.
    Breaks next quarter: a saved model name is retired. Step 1 makes a one-word call on each side
    before the card (and one per pinned worker model), so the run stops there with the reason, on
    either side, before any contest call is spent. The user names another model, and it is saved
    only if the one that failed came from the file: a replacement for a value from `--claude`,
    `--codex` or the `--yes` defaults is for that run, like the value it replaces. Before the
    second round only the Claude side had this check, and a retired Codex model would have failed
    N competitors at once.
    Reverse: delete the file and the questions are asked again.

18. **Claude logs are JSON event streams.** With plain text output a Claude log stays empty until
    the call ends, so a check-in could not tell working from stuck. `--output-format stream-json`
    grows as the call works, and `jq` takes the final message from the last event, unless that
    event is marked as an error: an API error must not be saved as an attack or a verdict. Breaks next
    quarter: the event shape changes and the extracted file is `null`, which the skill treats as a
    missing output (one retry, then dropped). Reverse: use text output redirected to the output file.

19. **Every call, on both sides, starts without the user's own tool set-up.**
    This entry is the tool side of it: what a process can call and reach. It has since grown into
    a clean room on both sides (decision 22: settings, hooks, plugins, instruction files, skills,
    memories), held in one wrapper script per tool (decision 23) instead of a flag string in
    every launch.
    Choice: Claude calls start with `--strict-mcp-config` (no MCP servers, which is where
    connected accounts live) and `--disable-slash-commands` (no skills), and every Claude call has
    a fixed `--tools` list: Read, Glob and Grep for attackers and judges (decision 15); Read,
    Write, Edit, Glob, Grep, Bash, WebSearch and WebFetch for competitors and the synthesizer,
    plus the worker tool in team mode. Codex calls start with
    `--ignore-user-config` and `--ignore-rules` (no `~/.codex/config.toml`, no approved-command
    rules), `--disable` for plugins, apps, browser use, computer use and memories, and two `-c`
    values that empty the extra writable folders and close the network.
    Standard: least privilege (OWASP ASVS access control), applied the way unattended tools are
    normally run: from a clean configuration instead of the operator's own (`git` with
    `GIT_CONFIG_GLOBAL=/dev/null`, `curl -q`, `bash --norc`). It is the standard because an
    allow-list of what a job may use stays correct when the user adds something, and a deny-list
    does not.
    Rejected: switching the user's Codex MCP servers off one by one (`-c
    mcp_servers.<name>.enabled=false` for each name `codex mcp list` reports). It worked for the
    servers defined in the config file, but it fails outright for a server that a plugin provides
    ("invalid transport"), it has to be regenerated per machine, and it leaves the rest of the
    file in force: other permission settings, a `notify` program, and above all the rules.
    Also rejected: inheriting the user's set-up. On the Claude side that gave an unattended
    auto-mode competitor over a hundred extra tools, including sending mail. On the Codex side a
    `read-only` call had the app tools of every connected account and MCP servers that run code,
    and a command covered by an approved-command rule ran outside the sandbox.
    Breaks next quarter: (a) a user whose Codex only works through `config.toml` (a custom model
    provider) cannot run the Codex side; the step 1 call fails and says so, and the README lists
    it. (b) A Codex release adds another on-by-default feature that reaches outside the sandbox;
    the check is the one used here: ask a contained call to list its tools. (c) A task depends on
    data only reachable through a connected account; step 2 already requires that data to be
    pasted into `task.md`.
    Also rejected, for the Claude tool list: leaving the built-in set in place, or removing the
    account-tied tools by name with `--disallowedTools`. The built-in set held tools that publish,
    schedule or notify through the user's Claude account (`Artifact`, `CronCreate`,
    `RemoteTrigger`, `PushNotification` among 27 at start-up), and a deny-list goes stale with the
    next tool a release adds. Breaks next quarter for the list itself: a task needs a built-in
    tool that is not on it (notebook editing, say) and the Claude side has to do it through the
    shell; or a release renames a tool and the name in `--tools` silently matches nothing. The
    check is the start-up event, which lists the tools the call really has.
    Not covered: both sides keep built-in web access, Codex keeps image generation, and a Claude
    process that may write keeps a shell, which nothing sandboxes (decision 15). Web access next
    to reading any file is a way out for data if a later role follows instructions hidden in a
    competitor's output; nothing technical stops that, and the README says so. When this entry
    was written both sides also still loaded the user's personal instruction files, and the
    Claude side the user's hooks and agent definitions: see decision 22 for what is left of that.
    Reverse: remove the flags from the wrappers; nothing else depends on them. For the tool
    list alone, drop `--tools` from the may-write shape and give single agents `--disallowedTools
    Agent` again.

20. **Blind roles start in one folder that holds everything they are given.**
    Choice: `RUN/blind` holds the task, the rubric, the candidates, the attacks, the test output
    and the screenshots, and nothing that names a model or a side. Attackers and judges start
    there. The final check starts in `RUN/finalcheck`, with its own copy of the task and rubric
    (`cp`, so byte-identical) beside the labelled solutions, whose file names are the same
    whatever they came from (`solution.md`, `solution.patch`, `tests.txt`). The roster, briefs,
    logs and verdicts stay outside both.
    Standard: least privilege, applied to what a role sees by default: it is shown what its job
    needs and has to go looking for anything else.
    Rejected: starting in `RUN`, where listing the folder shows `roster.md`, the briefs that name
    each side's worker tool, and log files whose names differ by side. Also rejected, after it
    failed: starting in `RUN/candidates` with the task, rubric, attacks and evidence one level
    up, reached by absolute path. A Codex role treated those as off limits in one run out of
    three and scored without the task or rubric, and a line in the brief saying the paths were
    readable was a patch on the layout, not a fix. With one folder the same check read every
    file in three runs out of three on each side.
    Breaks next quarter: a file that names a side is dropped into `RUN/blind` by a later change
    (a log, a brief) and the judges are unblinded without anyone noticing. The rule is in step 2
    of the skill. Blindness is still by instruction: nothing stops a role from reading `../`.
    Reverse: move the files back up and set `<start>` to `RUN`.

21. **The Codex worker limit is a configuration value; the Claude one is an instruction.**
    Choice: a Codex team competitor is started with `agents.max_concurrent_threads_per_session=3`.
    Standard: enforce a limit in the tool that grants the resource rather than in a prompt (the
    same reason rate limits live in the server, not in client documentation).
    Rejected: leaving it to the playbook on both sides; and a hard cap on the total number of
    workers, which is the owner's decision and has not been made.
    Breaks next quarter: the key is renamed and the limit silently stops applying; rerun the check
    (a captain asked to start five workers at once: three start, two are refused).
    Reverse: drop the flag.

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
  effect; a read-only role's answer landing in its output file. All run since; see the next section.

## Found during verification (2026-10-06, live Claude calls, claude 2.1.212)

Each with the skill's own launch command, in scratch folders. Most ran before `--strict-mcp-config`
was added to the may-write shape; the start-up check, the solo run and the pinned worker were
repeated with the final commands.
- **Start-up check.** `opus` at high: `claude-opus-4-8`, `auto`, `OK`. `haiku` with `auto`: the
  call succeeds (exit 0, no warning) but runs in `default` mode. With the prompt as an argument
  `init` said `default`; with a longer brief on stdin, a `status` event said `default` and the
  following `init` still said `auto`. The old check read only `init` and would have missed the
  second case, so it now collects every reported mode. A full model id newer than the installed
  `claude` ended in `ERROR: API Error: 400 ... version 2.1.280 or newer is required`, caught by the
  last line. The `opus` alias resolved to an older Opus than the model running the session, so the
  card now shows the resolved model.
- **Refused auto mode, write role.** Under `haiku` the competitor's Write was denied ("you haven't
  granted it yet", listed in `permission_denials`), nothing was written, and it still replied DONE.
  The missing-output rule in step 5 catches that; the step 1 check prevents it.
- **Fallback scope.** `acceptEdits` with `--allowedTools "Read,Glob,Grep,Agent"`: a Write inside the
  folder succeeded, a Write one level up was denied, and `touch` inside the folder through Bash
  succeeded although Bash was not listed: this mode also accepts simple file commands in its folder.
- **Claude competitor, auto mode.** `opus` at high wrote its file in the candidate folder, exit 0,
  `permissionMode` `auto` at start-up, no denials.
- **Claude captain, pinned worker.** Captain `opus` at high with `kage-worker` defined as `sonnet`
  at `medium`: the worker's turns ran on `claude-sonnet-5` (stream events with its
  `parent_tool_use_id`, and `modelUsage` listing both models) and its session transcript recorded
  `effort` `medium` on every turn, the captain's `high`. Redefined at `xhigh`, it recorded `xhigh`.
  In the same run a `general-purpose` worker given only `model` `sonnet` ran on `claude-sonnet-5`
  at `high`, the captain's level. The worker policy now says so instead of "cannot be set".
- **Read-only role.** In the attacker shape, a Write attempt returned "No such tool available:
  Write"; start-up listed only Glob, Grep and Read and no MCP servers; the `jq` capture wrote
  exactly the one-line answer to the output file.
- **Solo.** `--disallowedTools Agent` left no `Task` or `Agent` tool in the start-up list, and the
  competitor wrote its `solution.md` with Read and Write only.
- **Personal setup is loaded.** A headless call quoted a heading from the personal
  `~/.claude/CLAUDE.md` on request, and start-up listed the user's hooks, skills, agents and, without
  `--strict-mcp-config`, five connected accounts (decision 19). With a personal instruction asking
  for a plan and approval before non-trivial changes, two team-mode competitors built from the
  competitor template, on a small code task (input validation plus tests in a Python module), both
  edited the module and its tests, did not stop at a plan, and passed the tests (11 and 9). The
  template's "you cannot ask anyone a question or wait for anyone's approval" line is unchanged.
- **Not verified:** a full contest; a Claude captain under the `acceptEdits` fallback starting a
  worker; auto mode refused on an account rather than a model; the Claude synthesizer and judge
  shapes (the judge and attacker share the read-only shape that was run).

## Review fixes, second round (2026-10-06, claude 2.1.212, codex-cli 0.159.1)

An independent review of team mode said not to merge. What was changed, and what each change rests
on. Every check was a single live call or a local command in a scratch folder; a full contest has
still not been run.

- **Codex inherited the user's set-up (decision 19).** With the launch flags as they were, a
  `read-only` call listed about three hundred app tools for connected accounts (sending mail among
  them) and MCP servers that run code, and was given saved memories. It also wrote a file: with an
  approved-command rule for `npm test` in place, that command ran outside the sandbox.
  With the new flags the same two calls listed no MCP, app, browser-control or computer-use tool
  and no memories, and `npm test` failed with "Operation not permitted". `--ignore-user-config`
  without `--ignore-rules` still let the command out, so both are needed.
- **Workers inherit it.** A captain started with the new flags spawned one worker. The worker
  listed the same reduced tool set; its `npm test`, a direct write to the parent folder and a
  `curl` all failed; a write inside the folder succeeded. Its session record showed the captain's
  sandbox policy and no approved-command rules.
- **`writable_roots=[]` replaces.** With a throwaway configuration that named an extra writable
  folder and switched the network on, the rendered sandbox listed the extra folder; adding the two
  `-c` values removed it and reported the network as restricted. No model call was needed for this.
- **A project's own Codex config is not loaded either.** In a scratch repository whose
  `.codex/config.toml` defined an MCP server, a call with the new flags did not start that server
  and listed no tool from it.
- **Still present under the new flags:** web search and image generation, the worker tool, and the
  personal `AGENTS.md` and skills. `--disable multi_agent --disable multi_agent_v2` still left a
  call able to start a worker, and `agents.max_concurrent_threads_per_session=0` is rejected ("must
  be at least 1"), so solo on Codex remains an instruction.
- **Codex start-up check (decision 17).** Good model: `OK`, exit 0. Unknown model and unknown
  reasoning level: exit 1 with the API's reason on the last lines, which the check prints.
- **Claude start-up check.** `opus` at high: resolved model, `auto`, `OK`. `haiku`: `default`,
  `OK`. An unknown reasoning level is now stopped before the call, because `claude` would only
  warn and carry on. An unknown model: `ERROR:` with the reason. Success is read from the result's
  error flag, so a reply of `OK.` no longer stops a run.
- **Auto mode and workers (decision 15).** Under an auto-mode `opus` captain, a `haiku` worker
  created a file with Write and another with `touch`, with no denial recorded, as a
  captain's-choice worker and as a pinned `kage-worker`.
- **`--disable-slash-commands`.** The start-up event listed the user's skills and commands without
  it and none with it. A captain started with it still ran its worker. Agent definitions and hooks
  are still loaded.
- **Worker limit (decision 21).** With the value 3, a captain asked for five workers at once got
  three, and two refusals ("agent thread limit reached"). Asked for three, then two more after the
  first three had finished, it got all five.
- **Start folder (decision 20).** In a run folder whose path contains a space, in a shell set to
  refuse overwriting files, a Claude read-only call started in `candidates` read the task, rubric,
  candidate, attack and evidence files and its answer landed in the verdict file, replacing a stale
  one. The Codex call did the same in two runs out of three; in the third it read only the file
  inside its folder and reported the others as unreadable without trying, although the sandbox
  allows the read.
- **Failed read-only call.** A Claude call on an unknown model ended with an error result. The old
  capture would have saved the error text as the attack; the new one left the file empty, which
  the skill treats as missing.
- **Check-ins (decision 16).** With a 20-second interval: both test calls listed, then only the
  one still running, then "no calls running". Each call's record was gone once it ended, and a
  record holding a dead process id was ignored.
- **Not verified:** a full contest; the synthesizer, judge and final-check briefs end to end; a
  Claude captain starting a worker under the `acceptEdits` fallback; whether a user's own
  permission rules widen that fallback (taken from the reviewer's reading, not tested); the
  Claude three-worker limit; whether a Claude competitor in auto mode can use the built-in tools
  that act on the user's Claude account (settled since by removing them, next section); a `.pid`
  record whose process id really is reused.

## Found during verification (2026-10-06, fixed Claude tool list, claude 2.1.291)

The `claude` command was updated from 2.1.212 to 2.1.291 between the sections above and this one.
Each check was one live call with the skill's own launch command, in a scratch run folder whose
path contains a space.
- **Start-up check.** `opus` at high: `claude-opus-5-5`, `auto`, `OK`. The alias resolves per
  installed version: the same line read `claude-opus-4-8` on 2.1.212, above.
- **Built-in set without `--tools`.** Start-up listed 27 tools, among them `Artifact`,
  `ArtifactData`, `CronCreate`, `RemoteTrigger`, `PushNotification`, `ScheduleWakeup` and
  `Workflow`.
- **Team list.** With `--tools "Read,Write,Edit,Glob,Grep,Bash,Agent,WebSearch,WebFetch"`
  start-up listed exactly `Task`, `Bash`, `Edit`, `Glob`, `Grep`, `Read`, `WebFetch`, `WebSearch`
  and `Write`. `Agent` and `Task` in `--tools` gave the same list; start-up names the worker tool
  `Task` and the model calls it as `Agent`.
- **Captain and pinned worker under the list.** Captain `opus` at high, `kage-worker` defined as
  `sonnet` at `medium`: the captain wrote its file, started `kage-worker`, and the worker's turns
  ran on `claude-sonnet-5-5` and wrote a second file in the same folder. Exit 0, mode `auto`, no
  denials.
- **Solo list.** The same list without `Agent`: no `Task` or `Agent` at start-up, the competitor
  wrote `solution.md` and reported no tool for starting workers. This replaces `--disallowedTools
  Agent`, which did the same thing to the built-in set.
- **Account tools are gone, not just refused.** A team-list call told to call `Artifact` and
  `CronCreate` got, for each: "No such tool available: Artifact. Artifact is disabled for this
  session, in subagents as well as here." (and the same for `CronCreate`).
- **Fallback with the list.** `acceptEdits` with `--allowedTools "Read,Glob,Grep,Agent"` and the
  team `--tools` list: same nine tools at start-up, mode `acceptEdits`, the file written, no
  denials.
- **Not verified:** a worker's own tool list (taken from the refusal text above, not listed by a
  worker); the synthesizer shape end to end (it uses the solo list that was run); web search or
  fetch actually used, in either mode; what a Claude process can do to the user's account through
  its shell.

## Clean room and wrappers (2026-10-06)

A second review and a full contest run agreed that the pipeline works and that three things around
it did not: what each process loads, how the launch flags are kept, and what the result says
happened.

22. **Every process starts in a clean room, on both sides.**
    Choice: Claude calls start with `--setting-sources ""` (no user, project or local settings,
    and with them no `CLAUDE.md` or rules file, plugin, hook, output style or custom agent type),
    `--settings '{"disableAllHooks":true,"autoMemoryEnabled":false}'` (hooks off a second time,
    and no auto-memory), `--strict-mcp-config`, `--disable-slash-commands` and
    `--no-session-persistence`. Codex calls add to decision 19's flags `--disable hooks`,
    `--disable skill_search`, `-c skills.include_instructions=false` (no skill is listed) and `-c
    project_doc_max_bytes=0` (no project `AGENTS.md`). The same flags cover the folder a call
    starts in, which is what keeps a file planted by a competitor from being loaded by the
    synthesizer. A project's conventions reach competitors through the task file, which names the
    repository's instruction files for both sides.
    Standard: hermetic execution, the rule behind reproducible builds (Bazel, the
    reproducible-builds project) and behind how unattended tools are normally run (`git` with
    `GIT_CONFIG_GLOBAL=/dev/null`, `bash --norc --noprofile`, `env -i`): a job sees its declared
    inputs and nothing from the operator's dotfiles. It is the standard because a result that
    depends on one machine's personal files can be neither reproduced nor compared, and here it
    also made the two sides unequal. It is done with each vendor's own documented switches.
    Rejected: `claude --safe-mode`, the vendor's one-flag clean start, which would fail loudly if
    renamed. It also drops agent definitions passed with `--agents`: a pinned-worker captain got
    "Agent type 'kage-worker' not found". Alone it left the user's output style in place.
    Rejected: `claude --bare`, which reads only an API key and ignores a subscription login.
    Rejected, for Codex: renaming or moving the user's files for the length of a run (KAGE never
    changes the user's set-up), and switching personal roles off one by one by name (decision 19
    rejected that pattern for MCP servers).
    Not decided, and left to the owner: a scratch Codex home (`CODEX_HOME`) holding nothing but
    the login. With an empty home the prompt has no personal `AGENTS.md` and `codex login status`
    says "Not logged in", so it would need the login file copied or linked into it, and a token
    refresh there could rewrite or rotate a credential the user's real Codex depends on. Nothing
    of the kind was built.
    What is left: on the Codex side the personal `AGENTS.md` in the Codex home is still loaded and
    the custom agent roles there are still offered by `spawn_agent`; no flag or config key we
    found switches either off (`project_doc_max_bytes=0`, an empty `instructions` and
    `--ignore-user-config` do not). The wrapper passes a developer instruction telling the model
    to leave both alone, and the captain's brief says "no agent_type". That is a mitigation by
    instruction and the README says so. On both sides, managed or system-level configuration is
    not covered and was not tested.
    Breaks next quarter: a `claude` release changes what `--setting-sources ""` covers, for
    instance by loading `CLAUDE.md` independently of settings, and personal instructions come
    back on one side with nothing in the start-up event to show it. The check is the planted-file
    test below: start a call in a folder whose `CLAUDE.md` asks for a marker word and whose
    `.claude/settings.json` has a hook that touches a marker file. An older `claude` is the same
    risk today: 2.1.119 accepted the flags and still listed eight built-in skills.
    Reverse: edit the flag line in the wrapper; nothing else depends on it.

23. **One wrapper script per tool holds the fixed flags.**
    Choice: `skills/kage/claude-call.sh` and `skills/kage/codex-call.sh`, beside `heartbeat.sh`.
    Each `exec`s its tool with that side's fixed flags followed by `"$@"`, so a launch in the
    skill states only what varies: model, effort, sandbox or tool list, folder, brief, outputs.
    Both start-up checks go through them too. Called with the single word `which`, a wrapper
    prints the binary it would run and its version. The binary is the first one on the PATH, or
    the one named in `KAGE_CLAUDE` / `KAGE_CODEX`.
    Standard: the checked-in wrapper script (`./gradlew`, `./mvnw`): the project, not the caller,
    fixes how the tool is invoked, and POSIX `exec "$@"` passes everything else through. The
    binary override follows the `CC` / `EDITOR` / `GIT_SSH` convention: an environment variable
    names the program, the PATH is the default. It is the standard because one line to read and
    one line to change beats sixteen copies.
    Rejected: the flag string retyped by the orchestrator into every call. Decisions 9, 12 and 16
    already record that retyped text drifts, and here one dropped flag reopens the containment for
    one call out of sixteen without any error. Rejected: one launcher that also changes folder,
    records the process and captures the output; the four shapes stay visible in the skill, where
    a reviewer can check them. Rejected: copying the wrappers into the run folder, where an
    unsandboxed Claude competitor could edit a script that later roles run.
    Breaks next quarter: a release renames a fixed flag and every call on that side fails at
    start with "unknown option"; or a second, older copy of the tool sits earlier on the PATH
    (found on the test machine: a stale `claude` 2.1.119 in front of 2.1.291, on which `opus`
    quietly resolved to an older model and a newer model id was refused). Both show in step 1's
    check, which prints the binary, its version and the resolved model before any contest call.
    Reverse: paste the flags back into the launch shapes and delete the two scripts.

24. **Each call's real exit status is saved to a file.**
    Choice: every launch ends with `echo $? >| RUN/logs/<name>.exit` before its clean-up, and a
    call counts as successful only if that file holds 0 and the output it owes is there.
    Standard: the Unix exit status, read from the process that matters and not from the last
    command of the line (the reason `set -o pipefail` exists). It lives in a file because plain
    files are this skill's state (decision 5): it survives a compacted context and shows in `ls`.
    Rejected: ending the line with `exit` of that status. The completion notice would carry it,
    but nothing on disk would, and the notice had been reporting 0 for every call.
    Breaks next quarter: a tool exits 0 on a failed call, which is why the output check stays;
    or exits non-zero after writing a usable answer, which costs one needless retry.
    Reverse: drop the `echo`.

## Found during verification (2026-10-06, clean room and wrappers, claude 2.1.291, codex-cli 0.159.1)

Every call went through the wrapper scripts as shipped, most from a run folder whose path contains
a space, in zsh with overwriting refused. The test machine had two `claude` binaries; these used
2.1.291 except where 2.1.119 is named.

- **What loaded before.** A Claude call with the earlier flags listed an installed plugin and
  ran its session-start and prompt hooks, used the user's output style, offered the user's custom
  agent types and had an auto-memory path. A Codex call with the earlier flags listed the user's
  skills and custom agent roles and had the personal `AGENTS.md`.
- **Claude flags, one at a time.** `--safe-mode` alone: no hooks, no custom agents, no memory
  path, but the output style and the plugin entry remained. `--setting-sources ""` alone: no
  hooks, plugin, custom agent or instruction file, default output style, but the memory path
  remained. `--settings` with `disableAllHooks` and `autoMemoryEnabled` alone: hooks did not run
  and the memory path was gone, with everything else still loaded. Together, without safe mode:
  all of it gone, and `--agents` still registers `kage-worker`.
- **Planted files, synthesizer shape.** A folder with `.claude/settings.json` (four hooks, an
  output style, permission rules, a bypass mode), `.claude/settings.local.json`, `CLAUDE.md`,
  `CLAUDE.local.md`, a rules file, `.mcp.json`, an agent type, a skill and a command. Earlier
  flags: all five hooks ran, the output style and the agent type were loaded, and the model named
  the personal and the three planted instruction files. Wrapper, `opus` in auto mode with the
  solo tool list: no hook ran, default output style, no planted agent, skill or MCP server, the
  model reported no instruction file, and it wrote its `SYNTHESIS.md`.
- **Claude roles through the wrapper.** Start-up check: `claude-opus-5-5`, `auto`, `OK`. A captain
  wrote its file and started `kage-worker`, whose turns ran on `claude-sonnet-5-5` and wrote a
  second file. A read-only role had Glob, Grep and Read, could not write, and its answer landed
  in the output file. The fallback (`haiku`, `acceptEdits`) wrote a file and ran `touch`. All
  started with no plugin beyond three built-in ones, no hook event, no skill, no MCP server, no
  memory path and only built-in agent types. `--no-session-persistence` left no transcript; the
  worker left one small metadata file under the user's Claude projects folder.
- **`--tools` swallows a prompt.** With `--tools` added to the start-up check, a prompt given as
  the last argument was taken as a tool name and the call ended with "Input must be provided".
  The check now sends the prompt on stdin, as the launch shapes always did.
- **Codex flags.** Rendering the prompt without a model (`codex debug prompt-input`) showed the
  skills block gone with `skills.include_instructions=false` and a project `AGENTS.md` gone with
  `project_doc_max_bytes=0`, while the personal `AGENTS.md` stayed under every key tried.
  `--disable skill_search` alone changed nothing visible. Through the wrapper a read-only call
  listed no skill, answered "NO SKILL" when told to use one by name, listed no MCP, app,
  browser-control or computer-use tool, and could not write. A hook defined on the command line
  ran under the earlier flags and did not run through the wrapper. In a folder with a planted
  `AGENTS.md`, `.codex/config.toml` (an MCP server) and `.codex/hooks.json`, a call got no
  instruction, no tool and no hook. A command covered by an approved rule failed inside the
  read-only sandbox.
- **Custom roles.** A scratch role that declared `sandbox_mode = "danger-full-access"` and an MCP
  server was offered to a contained captain and could be started. The worker's write outside the
  folder failed, its network call failed, it described its sandbox as `workspace-write`, it had
  no MCP tool and the server was never started. So a role's sandbox and MCP settings did not take
  effect; the role's model and instructions were not tested. The user's own roles were still on
  the list the captain was offered.
- **The instruction about personal files.** A read-only Codex call asked what it had been given
  named the personal `AGENTS.md` and said it was not following it. A captain given a small split
  task announced its worker's model in the wording of the personal file without the instruction
  and did not with it. One run each.
- **Codex logs and workers.** The plain log and the `--json` event stream both record a captain
  waiting on a worker and nothing about starting one: no count, no model, no role. The `Teams`
  line for a Codex competitor can therefore only say whether a wait was logged.
- **Stale binary.** With `claude` 2.1.119 first on the PATH, the check printed that binary and
  version, `opus` resolved to `claude-opus-4-7` and passed, and a newer model id ended in "does
  not support this model; version 2.1.280 or newer is required". With `KAGE_CLAUDE` naming the
  2.1.291 binary the same check resolved `claude-opus-5-5`. `KAGE_CODEX` was checked the same way,
  with a real path and with one that does not exist.
- **Exit status.** Claude: 0 for a call that answered, 1 for an unknown model, with the output
  file left empty. Codex: 0 and 1 the same way, with no output file written.
- **One start folder (decision 20).** A judge brief built from the shipped template, with every
  path inside `RUN/blind`, three runs per side (Codex on a small model at medium, the setting
  that had failed before): each run returned valid JSON and the check word from all six files.
- **Smaller checks.** A patch holding an untracked binary file failed `git apply` without
  `--binary` and applied byte-identical with it. The roster line gave 2, 4 and 6 rows, half per
  side, in bash and zsh. The line that prepares `final/` rebuilt a half-edited folder to match
  the candidate. The `Teams` counts read 1 worker and two models from a captain's log and 0 from
  a solo one. The check-ins listed two calls, then one, then none, and ignored a dead record.
- **Not verified:** a full contest with these changes; the visual path; a Claude captain starting
  a worker under the fallback; managed or system-level configuration; a custom role's model and
  instructions in a worker; whether a Codex captain picks a personal role unprompted; the
  `xcrun_db` cache warnings, which come from the contest report below.

## End-to-end contest (2026-10-06)

One full contest was run on the commit before this section: 2 competitors, team mode, a code task.
It completed to a `RESULT.md`. Both candidates and the synthesis passed 12 of 12 tests, and
neither captain delegated. Measured: about $1.59 at API list prices on the Claude side across four
calls, about 113k tokens on the Codex side across five, about 12.5 minutes of wall-clock time. It
also showed what the entries above fix: every process had loaded the machine owner's personal
set-up, each launch reported exit 0 whatever happened, and the result did not say what the teams
had done. No full contest has been run since those fixes.
