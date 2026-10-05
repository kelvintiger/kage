# KAGE

Kelvin's Agent Gauntlet Engine.

KAGE is a Claude Code skill in which Claude and Codex compete on one task. Each solution is attacked
by the other model, a blind two-model judge panel scores them all, and you get one synthesized final
plus every candidate ranked.

## How it works

1. **Size.** It picks 2, 4 or 6 competitors, half Claude and half Codex, each with a different
   angle on the task.
2. **Solve.** Every competitor works on the same task file, independently and in its own folder.
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

## Cost

| Competitors | Model calls |
| ----------- | ----------- |
| 2           | 8           |
| 4 (default) | 12          |
| 6           | 16          |

Roughly half of the calls use your Codex quota and half use your Claude quota.

## Requirements

- Claude Code.
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
/kage --n 2 <task>
/arena <task>
```

With no task, it takes your last request and treats the last answer as the one to beat. It never
starts on its own: it runs only when you type `/kage` or `/arena`.

## What it never does

It applies nothing to your project. Code candidates live in git worktrees under `.kage/<run>/`, and
it asks before applying a patch.

## Known limits

- Judge blindness is by instruction, not enforced.
- Screenshots are the first screen only, at 1440x900 and 390x844.
- Claude sub-agents are not sandboxed. Codex competitors are, each to its own folder.
- A Codex call that runs past 10 minutes stops the run and asks you what to do.
- The two judges are still LLMs, so the ranking is evidence, not proof.
- Tested end to end on a 2-competitor code task. The screenshot path, 4 and 6 competitors, and the
  earlier-answer comparison are tested piece by piece, not yet in a full run.

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
