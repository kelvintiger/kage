# KAGE: decisions

Each entry: decision / choice / standard it follows / rejected alternative / what breaks next
quarter / how to reverse.

## Product choices (the user's)

- Runs only when `/kage` or `/arena` is typed (`disable-model-invocation: true`); it never fires on its own.
- Output is one synthesized final first, then every candidate ranked, with identities revealed only
  there. If a raw candidate or the baseline outscored the synthesis, the output says so.
- Code tasks run for real: one git worktree per candidate, tests executed by the orchestrator.
- Judges of visual work see real screenshots (desktop and mobile), not only source.
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
   the two `exclude_*` flags in that case. Claude sub-agents are not sandboxed at all: their scope
   is the brief's instruction only.
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
   Choice: at most 16 calls, each leaving one artifact; `ls -R` shows progress and resume is "first
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
