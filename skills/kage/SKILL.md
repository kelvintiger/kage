---
name: kage
description: >-
  KAGE (Kelvin's Agent Gauntlet Engine). Claude and Codex compete on one task: 2, 4 or 6 competitors
  (half Claude, half Codex, each a team captain unless --no-team) solve it through different lenses,
  each solution is attacked once by the other model, a blind Claude + Codex judge panel scores them
  all, and the user gets one synthesized final plus every candidate ranked. Visual work is judged
  from screenshots; code runs in worktrees with real tests. /kage or /arena only.
disable-model-invocation: true
argument-hint: "[--n 2|4|6] [--no-team] [--claude <model>[:<effort>]] [--codex <model>[:<effort>]] [--yes] <task>"
---

# kage

You are the orchestrator: you set the contest up, move files, run tests and screenshots, and do the
arithmetic. You never compete, attack or judge, because the result is only worth something if
whoever ran the contest had no hand in the entries or the scores. What the user typed after
`/kage` (`/arena` is an alias for it): `$ARGUMENTS`. If that shows the unreplaced placeholder (a
dollar sign and the word ARGUMENTS) instead of their text, you were reached through the `/arena`
alias, which states the arguments itself. Leading `--` flags are covered in step 1 and the rest is
the task. With no task, it is their most recent request and your last answer to it is the baseline
to beat. `RUN` below is the absolute path of the run folder; write it out literally in every
command and brief, since shell variables do not survive between Bash calls.

## 1. Size it and confirm the line-up

Use 2 competitors when the task has one right answer (bug fix, factual question), 4 by default, 6
for open-ended design or writing. `--n` overrides; half are Claude and half Codex, so an odd number
rounds up, and 6 is the cap. Each competitor is a **team captain**: one agent that owns its
candidate and may hand pieces of the work to workers of its own. `--no-team` makes each a single
agent that may not delegate. Attackers, judges, the synthesizer and the final check are always
single agents. Without `codex` and `claude` on the PATH there is no arena: stop and say so. Tell the
user one line: "KAGE: 4 competitors (2 Claude, 2 Codex), teams, 12 top-level calls, code task."
Top-level calls = N solve + N attack + 2 judges + 1 synthesis + 1 final check = 8, 12 or 16.

The line-up is each side's captain model and reasoning level, and what its workers run on. It is
remembered in `~/.claude/kage/lineup.json` (`mkdir -p` the folder), so the user is asked once:
`{"claude": {"captain": {"model": "opus", "effort": "high"}, "workers": "captain"}, "codex":
{"captain": {"model": "<model>", "effort": "high"}, "workers": {"model": "<model>", "effort":
"medium"}}}`. `workers` is `"captain"` (the captain picks a cheaper tier for each piece) or one
pinned model and effort. Every single agent (attacker, judge, synthesizer, final check) runs on its
own side's captain model and effort.

**No file yet:** ask three questions in one go (AskUserQuestion if you have it, plain text if not)
and save the answers. Claude captain model and reasoning level (default: this session's model at
high). Codex captain model and reasoning level (default: `model` and `model_reasoning_effort` in
`~/.codex/config.toml`). Workers: captain's choice of cheaper tiers (default), or one pinned model
and level per side. Never ask about lenses, the rubric, the judges or time limits.

**Every run:** `--claude <model>[:<effort>]` and `--codex <model>[:<effort>]` replace that captain
for this run only and are never written to the file. Then check that each side can start, with a
one-word call on its captain's settings, and one more for a pinned worker model. Claude:
```bash
case '<effort>' in low|medium|high|xhigh|max)
  claude -p --model <model> --effort <effort> --permission-mode auto --strict-mcp-config --disable-slash-commands \
    --output-format stream-json --verbose 'Reply with the single word OK.' \
  | jq -rs '([.[]|select(.subtype=="init").model][0] // "none"), ([.[]|select(.type=="system")|.permissionMode|values]|unique|join(",")), ([.[]|select(.type=="result")][0]|if . == null then "ERROR: no result" elif .is_error then "ERROR: " + (.result|tostring) else "OK" end)' ;;
  *) echo 'ERROR: effort must be low, medium, high, xhigh or max' ;; esac
```
It prints the resolved model, the start-up permission modes, then `OK`, taken from the call's error
flag and not its wording. A last line starting `ERROR`: the `claude` command cannot run that
line-up (an effort it would silently ignore; logged out, see `claude auth status`, a login separate
from this session's; or too old for the model, and the error names the version). Stop and tell the
user in plain words; a model or level they give in reply is a change at the card, so check again.
A middle line other than exactly `auto` (`default`, `auto,default`) for a captain means auto mode
was refused and every write would be denied: use the fallback in "Launching a call". For a pinned
worker ignore the middle line: a worker runs under its captain's mode. Codex:
```bash
OUT="$(codex exec -m <model> -c model_reasoning_effort=<effort> --sandbox read-only <contain> --skip-git-repo-check --ephemeral \
  'Reply with the single word OK.' < /dev/null 2>&1)" && echo OK || printf '%s\n' "$OUT" | tail -n 3
```
It prints `OK`, or the end of Codex's error: stop and tell the user (logged out, see `codex login
status`; a model or level this account cannot use; or a set-up that needs `~/.codex/config.toml`,
such as a custom model provider, which KAGE does not load). `<contain>` stands for these flags,
pasted in full into every Codex call in this skill:
```text
--ignore-user-config --ignore-rules --disable plugins --disable apps --disable browser_use --disable computer_use --disable memories -c 'sandbox_workspace_write.writable_roots=[]' -c sandbox_workspace_write.network_access=false
```
Then, card or no card, print one line with what the checks found: `KAGE: Claude <model>
(<resolved>) @ <effort>, <auto mode | accept-edits fallback>; Codex <model> @ <effort>, sandboxed.`
An alias like `opus` resolves per `claude` version, maybe not to this session's model. Print the
card and wait for "go" or a change. Only the field changed at the card is written to `lineup.json`,
never a value that came from `--claude` or `--codex`. `--yes` skips the card, and with no saved
file the questions too (defaults, nothing saved).
```text
KAGE line-up
  Claude team   captain: <model> (<resolved>) @ <effort>   workers: <captain's choice | model @ effort>
  Codex team    captain: <model> @ <effort>      workers: <...>
  Format        <teams | solo>, <N> competitors (<N/2> per side), <8|12|16> top-level calls
  Single agents attackers and judges on each side's captain model; synthesis on Claude's, final check on Codex's
Not in that count: the one-word start-up checks, one retry of any call that fails, and the workers captains start (at most 3 at a time each), so the true number of model calls is not fixed.
Claude processes run in <auto permission mode | the accept-edits fallback, because auto mode was refused>. Codex processes are sandboxed and start without your Codex config. For a run without prompts, switch this session to auto mode yourself: KAGE never changes your settings.
Run it?  (go / change <what>)
```
Solo shows `workers: none` and drops "and the workers captains start (at most 3 at a time each)".

## 2. Run folder and task file

`RUN` = `<cwd>/.kage/<run>` (`<run>` from `date +%Y%m%d-%H%M%S`), with subfolders `briefs candidates
attacks verdicts logs tests shots`. In every command quote each path, since a folder name may hold
a space, and redirect output with `>|` as the snippets do, so a retry can overwrite the first try's
file even in a shell set to refuse that. In a git repo, hide the run folder without editing the
user's `.gitignore`:
```bash
X="$(git rev-parse --git-path info/exclude)"; grep -qxF '.kage/' "$X" 2>/dev/null || echo '.kage/' | tee -a "$X" >/dev/null
```
In team mode, copy the captain playbook `captain.md`, which sits beside this file, to `RUN/captain.md`.
The other processes cannot see this conversation, so `RUN/task.md` must stand alone: the request in
the user's own words, every constraint they stated, absolute paths of the files that matter, pasted
data, what done looks like if they said, and what they disliked about a rejected earlier answer.
Add no requirement they never gave and no opinion of yours about the right answer: that pushes every
competitor the same way. Save a rejected earlier answer verbatim to `RUN/baseline.md` and the step 7
rubric to `RUN/rubric.md`. Briefs point at these files instead of quoting them, so the task is
byte-identical for everyone by construction.

## 3. Roster

- **minimal**: The simplest thing that fully works. Cut whatever the task does not need.
- **rigorous**: Edge cases and correctness first. Check every claim before you make it.
- **user-first**: Optimise for the person who will use the result: what they see, do and need first.
- **contrarian**: Question the obvious approach. If a better framing exists, take it and justify it.
- **premortem**: Assume it shipped and failed within a month. Build what would have prevented that.
- **first-principles**: Derive it from the goal itself, not from how this is usually done.

One lens per competitor: n=2 uses the first two, n=4 the first four. Deal models and lenses with a
real shuffle (n rows per list), because a letter that predicts the model would unblind the judges.
`roster.md` is the only place identities live; no later brief mentions it, and nothing that names a
model or a side is ever put under `RUN/candidates` or `RUN/finalcheck`, where the blind roles start.
```bash
paste <(printf 'claude\ncodex\nclaude\ncodex\n') <(printf 'minimal\nrigorous\nuser-first\ncontrarian\n' | sort -R) \
  | sort -R | paste <(printf 'A\nB\nC\nD\n') - >| "RUN/roster.md"
```

## 4. Workspace, by task type

Classify the task and create one folder per competitor, `RUN/candidates/<L>/`.
- **text** (writing, plans, answers, and code outside a git repo): it writes `solution.md` there.
- **visual** (landing page, UI, design): a self-contained result, opened from disk at `index.html`.
- **code** (a change in a git repo) runs for real. If `git status --porcelain` is not empty, warn
  once that worktrees start from HEAD, so uncommitted changes are not what competitors see. Make one
  worktree per candidate plus a pristine `RUN/base`, and symlink dependency folders to save installs:
  ```bash
  git worktree add --detach "RUN/candidates/<L>" HEAD
  ln -s "$PWD/node_modules" "RUN/candidates/<L>/node_modules"   # likewise .venv, where one exists
  ```
  Find the test command in CLAUDE.md / AGENTS.md, `package.json` scripts, `pyproject.toml` or the
  Makefile; if there is none, ask the user once.

## Launching a call

Every model call is its own command-line process, started by Bash with `run_in_background: true`
and `timeout: 7200000` (2 hours, the most Bash allows), so each side runs on its line-up model and
a captain can start workers. `<name>` is `solve-<L>`, `attack-<L>`, `judge-claude`, `judge-codex`,
`synth` or `final-check`; `<model>` and `<effort>` are that side's captain's; `<contain>` is step
1's flag list. `<start>` is where a read-only role begins: `RUN/candidates` (the final check:
`RUN/finalcheck`), which holds only the work, so a role that lists its folder sees no logs, briefs
or roster. The leading `echo` records the process for the check-ins below, and the trailing `rm`
clears the record when the call ends. Four shapes:
```bash
# Codex, may write (competitor): the sandbox confines it, and its workers, to <dir>
echo $$ >| "RUN/logs/<name>.pid"; codex exec -m <model> -c model_reasoning_effort=<effort> --sandbox workspace-write <contain> \
  --skip-git-repo-check --ephemeral -C "<dir>" -o "RUN/logs/<name>.last.md" - < "RUN/briefs/<name>.md" >| "RUN/logs/<name>.log" 2>&1; rm -f "RUN/logs/<name>.pid"
# Codex, read-only (attacker, judge, final check): -o saves its final message as the output file
echo $$ >| "RUN/logs/<name>.pid"; codex exec -m <model> -c model_reasoning_effort=<effort> --sandbox read-only <contain> \
  --skip-git-repo-check --ephemeral -C "<start>" [-i "<png>" -i "<png>" ...] -o "<output file>" - < "RUN/briefs/<name>.md" >| "RUN/logs/<name>.log" 2>&1; rm -f "RUN/logs/<name>.pid"
# Claude, may write (competitor, synthesizer): the log is a stream of JSON events, so it grows while the call works
echo $$ >| "RUN/logs/<name>.pid"; ( cd "<dir>" && claude -p --model <model> --effort <effort> --permission-mode auto \
  --tools "Read,Write,Edit,Glob,Grep,Bash,Agent,WebSearch,WebFetch" --strict-mcp-config --disable-slash-commands --output-format stream-json --verbose < "RUN/briefs/<name>.md" >| "RUN/logs/<name>.log" 2>| "RUN/logs/<name>.err" ); rm -f "RUN/logs/<name>.pid"
# Claude, read-only (attacker, judge): it has no tool that writes; jq saves its final message, or nothing if the call failed
echo $$ >| "RUN/logs/<name>.pid"; ( cd "<start>" && claude -p --model <model> --effort <effort> --permission-mode dontAsk \
  --tools "Read,Glob,Grep" --allowedTools "Read,Glob,Grep" --strict-mcp-config --disable-slash-commands --output-format stream-json --verbose \
  < "RUN/briefs/<name>.md" >| "RUN/logs/<name>.log" 2>| "RUN/logs/<name>.err" ); \
  jq -r 'select(.type=="result" and (.is_error|not)) | .result' "RUN/logs/<name>.log" >| "<output file>"; rm -f "RUN/logs/<name>.pid"
```
- **Codex containment.** Never launch a Codex call without `<contain>`: a user's Codex set-up
  reaches past the sandbox (MCP servers, apps and plugins such as mail and GitHub, browser and
  computer control, and approved-command rules that let a matching command such as `npm test` skip
  even `read-only`). The flags start the call without `~/.codex/config.toml` and those rules,
  switch off what is on by default, and close extra writable folders and the network whatever
  another config layer says. A captain's workers inherit all of it.
- **Codex sandbox.** `workspace-write` writes only in its own folder, plus `/tmp` and `$TMPDIR`. If
  `RUN` itself is under one of those (or `/private/tmp`), that would reach its neighbours, so add
  `-c sandbox_workspace_write.exclude_slash_tmp=true -c sandbox_workspace_write.exclude_tmpdir_env_var=true`.
- **Claude permissions.** Auto mode is the user's choice: KAGE assumes approval rather than prompt,
  with a classifier still between the model and risky actions. Nothing sandboxes these processes:
  rule 3 of the brief is their only fence. `--strict-mcp-config` keeps the user's MCP servers and
  connected accounts out of every Claude call, and `--disable-slash-commands` their skills.
  `--tools` is the whole tool set of a call and of the workers it starts: files, shell, the worker
  tool and web search and fetch, and nothing else, so Claude Code's built-in tools that publish,
  schedule or notify through the user's account do not exist there. Never widen that list. If step
  1 found auto refused, use `--permission-mode acceptEdits --allowedTools
  "Read,Glob,Grep,Agent,Bash(<test command>)"` instead, with `--tools` unchanged (no `Bash` entry
  without a test command, no `Agent` entry for a single agent):
  edits and simple file commands (such as `touch`) are accepted inside `<dir>` only, the test
  command runs unsandboxed, and what would otherwise prompt is denied unless the user's own
  settings allow it. Never use `bypassPermissions` or `--dangerously-skip-permissions`: they switch
  every check off in a process nobody is watching.
- **Pinned workers.** `<worker_model>` and `<worker_effort>` are that side's pinned worker
  settings, not the captain's. Codex adds `-c 'agents.default_subagent_model="<worker_model>"' -c
  'agents.default_subagent_reasoning_effort="<worker_effort>"'`. Claude adds `--agents
  '{"kage-worker": {"description": "Does one bounded piece of a larger task.", "prompt": "Do the
  one piece you are briefed on, inside the folder you are given, then report what you changed and
  how you checked it.", "model": "<worker_model>", "effort": "<worker_effort>"}}'`. Captain's
  choice needs no flag.
- **Worker limit.** A Codex team competitor adds `-c agents.max_concurrent_threads_per_session=3`:
  a fourth worker at the same time is refused, and a finished worker frees its place. Claude has no
  such switch, so there the playbook's limit is an instruction. Nothing caps the total.
- **Single agents.** A solo Claude competitor and the synthesizer leave `Agent` out of `--tools`
  (`"Read,Write,Edit,Glob,Grep,Bash,WebSearch,WebFetch"`), so they have no worker tool; neither
  has the read-only Claude shape. No Codex switch we tried removes its worker tool,
  so there the brief is the only rule. A Codex log gets a line starting `collab:` when the call
  waits on a worker, so after a solo solve count them (counting is not reading): `grep -c
  '^collab:' "RUN/logs/solve-<L>.log"`. Above 0, it delegated anyway: say so in the result. 0 is
  not proof that it did not.
- Do not read the logs. An output file that is empty or just `null` counts as missing.

**Check-ins, not time limits.** Nothing below the 2-hour ceiling stops a call. After launching a
batch, unless a check-in is already waiting, start one in the background with `timeout: 900000`:
`sh "<this skill's folder>/heartbeat.sh" "RUN/logs"`. It returns after 10 minutes, or as soon as no
call is running, with one line per call still running: its name, minutes elapsed, and `log growing`
or `no new output for N min`. Show the user those lines as they are and, if any call is still
running, start it again. A call whose completion notification has arrived is finished whatever a
check-in says (a call stopped from outside leaves its `.pid` file behind, and the number in it can
later belong to another program): `rm -f` that file and do not start another check-in for it.
Never stop a call yourself because it is slow or quiet; the user can say stop at any check-in.
Between check-ins wait for the completion notifications and do not poll. If a call is stopped at
the 2-hour ceiling, say so plainly (which call, and that it ran 2 hours without finishing) and ask
the user whether to rerun it, go on without it, or stop.

## 5. Solve, then collect evidence

Write `RUN/briefs/solve-<L>.md` per competitor from the competitor template; only the lens line and
the team or solo paragraph differ. Launch all of them in one message so they run concurrently, each
with `<dir>` = `RUN/candidates/<L>`. A competitor with no `solution.md`, no `index.html` or an empty
diff gets one retry, then is dropped and reported. Under 2 left: stop, say so.

The evidence is yours to collect, not the competitors'. **Code:** write each patch, then run the
tests in `base` (to `base.txt`) and in every candidate, one at a time as suites share ports. This
runs code the competitors wrote, with your own permissions and no sandbox:
```bash
git -C "RUN/candidates/<L>" add -A -N -- . ':(exclude)node_modules' ':(exclude).venv'
git -C "RUN/candidates/<L>" diff HEAD -- . ':(exclude)node_modules' ':(exclude).venv' >| "RUN/candidates/<L>.patch"
( cd "RUN/candidates/<L>" && <test command> ) >| "RUN/tests/<L>.txt" 2>&1; echo "exit=$?" >> "RUN/tests/<L>.txt"
```
If a patch touches a lockfile, swap that worktree's symlink for a real install first. Write
`RUN/tests/summary.md`: pass or fail per candidate, and each test that fails there but passes in
`base`. Such a regression is a verified fatal flaw, and the judges are told so.

**Visual:** render each candidate at both sizes (Bash timeout 60 seconds). Chrome will not lay out a
window narrower than 500px and crops that layout to 390, so the mobile shot goes through a wrapper,
written once as `RUN/shots/mobile.html`:
```html
<!doctype html><meta charset="utf-8"><style>html,body{margin:0;overflow:hidden}iframe{border:0;display:block;width:390px;height:844px}</style>
<iframe></iframe><script>document.querySelector('iframe').src=location.search.slice(1)</script>
```
```bash
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$CHROME" --headless --hide-scrollbars --virtual-time-budget=5000 --window-size=1440,900 \
  --screenshot="RUN/shots/<L>-desktop.png" "file://RUN/candidates/<L>/index.html" >/dev/null 2>&1
"$CHROME" --headless --hide-scrollbars --virtual-time-budget=5000 --window-size=390,844 \
  --screenshot="RUN/shots/<L>-mobile.png" "file://RUN/shots/mobile.html?file://RUN/candidates/<L>/index.html" >/dev/null 2>&1
```
The time budget lets scripts settle. Percent-encode spaces in the URLs. Chrome exits 0 even when it
writes nothing, so success is `test -s` on the PNG. Do not add `--user-data-dir`: a fresh profile
keeps Chrome alive after the shot. Never open the PNGs yourself; they are for the judges. If Chrome
is missing or a render fails, judge every candidate from source only and say so in the result.

## 6. Cross-model attack

Each candidate is attacked exactly once, by the other model, since a model is worst at seeing its
own kind of mistake: Claude attacks what Codex made, Codex attacks what Claude made. Briefs are
`RUN/briefs/attack-<L>.md`, attacks land in `RUN/attacks/<L>.md`, and all launch in one message.
Attackers, like the judges and the final check, are launched in the read-only shape. There is no
defend or revise round: the judges decide which attacks hold. A missing attack gets one retry, then
counts as no attacks.

## 7. Judge panel

Two judges score every candidate, one Claude and one Codex, launched together: different model
families cancel each other's taste for their own output. Each gets the task, the rubric, every
candidate by letter only, every attack and the evidence, and its final message is saved as
`RUN/verdicts/judge-claude.json` or `judge-codex.json`. The Claude judge Reads the PNGs. The Codex
judge gets them attached in the order its brief lists: `-i` swallows every following argument that
is not a flag, so each image needs its own `-i`, with `-o` after them and the prompt on stdin. The
rubric (`RUN/rubric.md`):
```text
Score each criterion 0-10 and use the whole scale: a 7 is not a polite default. Weighted total (0-100) = correctness x3 + completeness x2.5 + robustness x2 + specificity x1.5 + clarity x1.
Correctness (30): is it right? 10 nothing wrong after checking it yourself / 7 slips that do not change the outcome / 4 one real error the person would trip on / 0-2 wrong at the core.
Completeness (25): does it meet every requirement the task states, judged against the task text and not your own wishes? 10 all fully met / 7 all touched, one thin / 4 one missing / 0-2 answers a different question.
Robustness (20): how does it hold up against the attacks? 10 none stands / 7 one MINOR stands / 4 a MAJOR stands / 0-2 a FATAL stands.
Specificity and usability (15): could the person use it right now without guessing? 10 usable as it is / 7 one or two guesses / 4 a lot of "consider" and "it depends" / 0-2 generic.
Clarity (10): easy to read and use, at a length that fits the task? 10 the shape makes it obvious, no padding / 7 some padding or one confusing part / 4 you have to dig / 0-2 hard to follow.
Visual work: correctness = it renders and works at both sizes with nothing broken, clipped or overlapping. Completeness = every requested section and element is there. Specificity = real content and visual quality (typography, spacing, colour, polish), not a template. Clarity = visual hierarchy: the eye lands on the right thing first, on desktop and on mobile.
Fatal: only a flaw you verified that makes it wrong or unusable for the task (cannot work, false central claim, hard constraint broken, wrong question answered). For code, the test results anchor correctness, and a change that fails a test the untouched code passes is fatal. Not rewarded: length, confidence, claims about its own quality, or agreement with your taste where the task does not ask for it.
```
If a verdict is wrapped in a code fence, strip the fence lines and change nothing else. One that is
missing or not valid JSON gets one rerun; after that, rank on the judge you have and say so. This
prints letter, total, fatal flag and standing-attack count without arithmetic slips:
```bash
jq -r '.candidates|to_entries[]|[.key,(.value.scores|.correctness*3+.completeness*2.5+.robustness*2+.specificity*1.5+.clarity),.value.fatal,([.value.attacks[]|select(.verdict=="STANDING")]|length)]|@tsv' "RUN/verdicts/judge-claude.json"
```
Score = mean of the two judges' totals. A candidate either judge marks fatal ranks below every
non-fatal one. Ties go to fewer standing attacks, then higher correctness. Write `RUN/ranking.md`
with both judges' totals side by side. This is bookkeeping: never adjust a score, drop a fatal flag
or reorder because you disagree with a judge.

## 8. Synthesis and final check

Prepare `RUN/final/` from the top-ranked candidate without reading it. Text and visual: `cp -R
"RUN/candidates/<top>/." "RUN/final/"`. Code: `git worktree add --detach "RUN/final" HEAD`, then
`git -C "RUN/final" apply "RUN/candidates/<top>.patch"`, plus the symlinks. One Claude single
agent, launched in the may-write shape with `<dir>` = `RUN/final`, gets `RUN/briefs/synth.md`. Then
`test -s "RUN/final/SYNTHESIS.md"`: if that fails the synthesis did not happen, so rerun it once,
and if it fails again skip the final check and report the raw top candidate as the final, saying
so. For code, then run the tests in `final` (to `RUN/tests/final.txt`) and write `RUN/final.patch`
with the step 5 commands, adding `':(exclude)SYNTHESIS.md'`.

Then one Codex judge, read-only, scores the synthesis against the raw top-ranked candidate, and the
baseline if there is one, without knowing which is which. The path `final/` would give it away, so
copy each into `RUN/finalcheck/X/`, `Y/` (and `Z/`), leave `SYNTHESIS.md` out, and take the mapping
from this line (drop `Z` and `baseline` when there is none), which also records it in `roster.md`.
Read it with `while read LBL WHAT`, not `set --`: zsh does not split an unquoted variable.
```bash
paste <(printf 'X\nY\nZ\n') <(printf 'synthesis\ntop\nbaseline\n' | sort -R) | sed 's/^/finalcheck /' | tee -a "RUN/roster.md"
```
Confirm every `finalcheck/` folder is non-empty before launching the judge, whose `<start>` is
`RUN/finalcheck`. A code copy is the patch plus its test output. Visual copies are rendered as in
step 5 to `RUN/finalcheck/X-desktop.png` and so on, and attached with `-i`. Brief
`RUN/briefs/final-check.md`, verdict `RUN/verdicts/final.json`.

## 9. Result

Print this and save it as `RUN/RESULT.md`. Identities are revealed here and nowhere earlier.
```text
FINAL: synthesis
  path: <RUN/final/solution.md | RUN/final/index.html | RUN/final.patch (tests: pass|fail)>
  built from: base <L> (<model>, <lens>) + keepers from <L> (<what>), <L> (<what>)
  final check: <score>/100   (raw <L>: <score>, baseline: <score>)
  WARNING: <raw candidate L | the baseline> outscored the synthesis (<score> vs <score>).

RANKED
  <rank>. <L>  <model>  <lens>  <score>  <a judge's one-line reason>  <path>  [tests: pass|fail]

Judging: <screenshots, desktop 1440x900 and mobile 390x844 | source only: why>
Dropped: <none | L (model, lens): why>
Mode: <teams | solo>; Claude <resolved model> @ <effort>, <auto mode | accept-edits fallback>; Codex <model> @ <effort>, sandboxed
Solo rule: <kept, as far as the logs show | L (codex) started a worker anyway>
```
The synthesis always comes first. The WARNING line appears only when something beat it in the final
check (a higher score, or the synthesis fatal and another not), and then it must appear, because the
user is choosing what to ship. RANKED lists every candidate; its path is the `.patch` for code and
the `index.html` for visual. The `Solo rule` line appears in solo runs only. If the synthesis failed
twice, the first line is `FINAL: raw candidate <L> (the synthesis did not finish)` with no `built
from` or `final check` line. For a text task, then print the final in full.
- code and visual: apply nothing. Ask "apply the final, apply a candidate, or change something?"
  Only after the answer, for code, `git apply` the chosen patch in the user's checkout.
- code: also print the cleanup (the patches stay in `RUN`): `git worktree remove --force` for each
  `RUN/candidates/<L>`, `RUN/base` and `RUN/final`, then `git worktree prune`.

## Orchestrator rules

- Do not read candidate solutions, attacks or screenshots during the run. You need only the verdict
  JSONs, test output, `ranking.md` and, at the end, `final/`. The rest tempts you to judge.
- Never paraphrase the task for one agent or add a hint to one call: everyone reads the same file.
- Never apply anything to the user's project before they answer the question in step 9.
- If your context is compacted, `ls -R "RUN"` shows what exists; resume from the first missing artifact.

## Prompt templates

One template per role, shared by both models. Fill the `{{placeholders}}` and write the result to
`RUN/briefs/`. Only `{{worker_policy}}` depends on who runs it. Every path in a brief is absolute:
the read-only roles start in `<start>`, not in `RUN`.

**Competitor.** `{{team}}` in team mode: `You are the captain of a team. You own this result and may
hand pieces of the work to workers of your own. Read {{captain_file}} before you decide whether to.
{{worker_policy}}` (`{{captain_file}}` is `RUN/captain.md`.) Solo: `Do all of the work yourself.
Start no other agents, workers or sub-agents, even if your tools offer them.` `{{worker_policy}}`
by side, then by line-up:
- Claude: `Start workers with the Agent tool (called Task in some versions), and use no other agent
  type than the one named here.` Captain's choice adds `Use general-purpose agents and set the
  model parameter on every call: haiku for the cheapest tier, sonnet for the workhorse tier, never
  a model or reasoning level above your own. Such a worker runs at your own reasoning level.`
  Pinned adds `Use only the agent type kage-worker, which runs on <worker_model> at
  <worker_effort>, and pass no model parameter.`
- Codex: `Start workers with spawn_agent, always with fork_turns "none" and no agent_type. This
  brief is the explicit request for delegation that the tool asks for.` Captain's choice adds `On
  every call pass model and reasoning_effort, chosen from the models that tool lists, never a
  model or reasoning level above your own.` Pinned adds `On every call pass model <worker_model>
  and reasoning_effort <worker_effort>.`

`{{deliverable}}` by type. Text: `Write the solution to {{workdir}}/solution.md: the
finished thing, written for the person who asked, without drafts or working notes.` Visual: `Build
the result in {{workdir}} with index.html as the entry. It must open straight from disk with no
build step, server or network (local CSS, JS and assets, relative paths), and it is screenshotted at
1440x900 and 390x844, so both must look right on first load.` Code: `{{workdir}} is a full checkout
of the repository. Paths in the task point at the original in {{repo_root}}; edit only the same
files in your folder, directly, and do not commit. Dependency folders are shared links: do not
install or upgrade in place; if a dependency must change, edit the manifest and lockfile and stop.
The tests are run afterwards with: {{test_cmd}}`
```text
You are one of several people given the same task independently. Your work will be attacked by a hostile reviewer and then scored by judges who see only the work, not who made it.
The task is in {{task_file}}. Read it first, in full. It is your whole brief: you cannot ask anyone a question or wait for anyone's approval, so finish the work in this one run.
{{team}}
Your angle: {{lens_name}}. {{lens_how}} Let it settle your trade-offs. The judges score the result against the task, not the angle, so a generic answer with the angle's name on top loses.
1. Meet every requirement the task states. Where it is ambiguous, take the most reasonable reading and say which in one line.
2. Expect concrete attacks: errors, missed requirements, inputs that break it, vague spots. Close those holes before you finish.
3. Work only inside {{workdir}}. Read whatever the task points to, but create, edit or delete nothing outside that folder.
4. {{deliverable}}
5. Say nothing in your output about a competition, about which AI model you are, or about your angle. The judging is blind, and a tell spoils it. When you are finished, reply with the single word DONE.
```
**Attacker.** `{{target}}` is the candidate's `solution.md`; or its folder and `index.html`; or, for
code, its `.patch`, its worktree, and `tests/<L>.txt` beside `tests/base.txt`.
```text
You are a hostile expert reviewer. Someone was given a task and produced the work below. Find what is actually wrong with it.
The task is in {{task_file}}. Read it first, in full. The work to attack: {{target}}. Look for:
- WRONG: factual errors, logic errors, bugs, false claims.
- MISSING: a requirement the task states that is skipped or only half met. Quote the requirement.
- BREAKS: a concrete input, scenario or edge case where it fails. Give the exact counterexample.
- VAGUE: a place where the person could not act on it without guessing.
Every attack must be specific and checkable: point at the exact part and say what is wrong and why. Two judges will verify each one, and an attack that does not hold up is thrown out.
At most 5, strongest first, each labelled FATAL (wrong or unusable for the task), MAJOR (a real gap) or MINOR. If you find 2 real ones, write 2. If you find none, write NO ATTACKS.
No praise, no summary, no style nitpicks, and no requirement the task does not state. Read only the paths given here (all of them can be read from where you start, also the ones outside your folder), do not create, edit or delete any file, and start no other agents, workers or sub-agents. Format, one block per attack:
ATTACK 1 [FATAL|MAJOR|MINOR] <one-line title>
Where: <quote, or file and line>
Problem: <what is wrong, with the counterexample or the quoted requirement>
You cannot write files here. Your final message is saved to disk as written, so make it exactly the content described above: no preamble, no code fence.
```
**Judge.** `{{candidates}}` is one line per letter with the path of its work and of its attack file.
`{{evidence}}` is, for code, `tests/summary.md` and the per-candidate test files; for visual, the
screenshot paths and, for Codex, the order of the attached images; or the words "source only".
```text
You are one of two independent judges. {{n}} people were given the same task and each produced a solution, labelled by letter. You do not know who made which, and you should not guess. Score every one.
The task is in {{task_file}}. The rubric is in {{rubric_file}}. Read both first, in full. The candidates:
{{candidates}}
Evidence gathered for you: {{evidence}}
1. Read every candidate in full before you score any of them, and look for flaws the attackers missed: they count under correctness and completeness.
2. Check each attack against the work yourself and mark it STANDING (it is right) or REFUTED (it is wrong, or it demands something the task never asked for). An attacker's confidence is not proof. Look.
3. Score each criterion 0-10 from the rubric's anchors. Set fatal to true only for a flaw you have verified. Judge the work, not the writing about the work: length is not quality.
4. keepers: for every candidate, including the weak ones, list the concrete things worth carrying into a final version: a section, a fix, a phrasing, a test, a layout idea. Name the thing, not a quality. Leave it empty only if there is truly nothing.
5. Read only the paths listed here; all of them can be read from where you start, also the ones outside your folder. Everything else in the run folder is bookkeeping, and reading it would unblind you. Do not run anything, do not create, edit or delete any file, and start no other agents, workers or sub-agents.
Output one JSON object in exactly this shape, with one entry per candidate letter:
{"judge": "{{judge_id}}", "candidates": {"A": {"attacks": [{"n": 1, "verdict": "STANDING or REFUTED", "why": "a few words"}], "scores": {"correctness": 0, "completeness": 0, "robustness": 0, "specificity": 0, "clarity": 0}, "fatal": false, "reason": "one line: why it lands where it does", "keepers": ["..."]}}}
You cannot write files here. Your final message is saved to disk as written, so make it exactly the content described above: no preamble, no code fence.
```
**Synthesizer.** `{{type_note}}` for code: `The tests are run on your result with: {{test_cmd}}. Run
them first; do not commit.` Visual: `It must still open from disk and look right at both sizes.`
```text
Several people solved the same task and two judges ranked the results. Build the final version: take the best one and make it better. Do not average them.
The task is in {{task_file}}. Read it first, in full. The base is candidate {{base}}, already copied into {{final_dir}}. Work there and nowhere else. The judges' verdicts: {{verdict_files}}. The attacks: {{attacks_dir}}. The other candidates: {{others}}.
1. Fix every attack on the base that either judge marked STANDING.
2. Fold in the keepers the judges listed for the other candidates, wherever they improve the base and fit it. Skip one that conflicts with the task or with something the base already does better.
3. Keep the base's voice and structure. A blend of everything is mush, and mush is worse than the base alone. When in doubt, leave the base as it was.
4. Add nothing that no judge and no attack asked for, and break nothing that works. {{type_note}}
5. Write {{final_dir}}/SYNTHESIS.md: the base letter, then one line per change saying what it is and which letter or attack it came from, then the keepers you skipped and why.
The final work itself must not mention the competition, the letters or the judges. When you are finished, reply with the single word DONE.
```
**Final check.** `{{solutions}}` is one line per label with the paths in its `finalcheck/` copy.
```text
You are the final check. Below are {{k}} solutions to the same task, labelled {{labels}}. You are not told where any of them came from. Score what is in front of you. Any of them can come out on top.
The task is in {{task_file}}. The rubric is in {{rubric_file}}. Read both first, in full. The solutions:
{{solutions}}
1. Read all of them in full before you score any, then attack each one yourself, the way a hostile expert would. Score robustness on how each holds up against your own attacks.
2. Score each criterion 0-10 from the rubric's anchors. Set fatal to true only for a flaw you have verified. Judge the work, not the writing about the work: length is not quality.
3. Read only the paths listed here; all of them can be read from where you start, also the ones outside your folder. Do not run anything, do not create, edit or delete any file, and start no other agents, workers or sub-agents.
Output one JSON object in exactly this shape, with one entry per label:
{"solutions": {"X": {"scores": {"correctness": 0, "completeness": 0, "robustness": 0, "specificity": 0, "clarity": 0}, "fatal": false, "reason": "one line"}}, "best": "X", "why": "one sentence: the decisive difference"}
You cannot write files here. Your final message is saved to disk as written, so make it exactly the content described above: no preamble, no code fence.
```
