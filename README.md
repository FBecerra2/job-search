# Job search assistant (Claude Code skill)

A Claude Code skill that searches job offers for you, keeps a log of everything it finds, and helps you apply. **It never sends an application without your explicit "yes" for that offer.**

Everything personal (your profile, CVs, job log and history) lives in `data/`, which git ignores. The repository only contains the skill, the scripts and empty templates, so anyone can clone it and use it with their own data.

Requirements: Windows, PowerShell 5.1+, [Claude Code](https://claude.com/claude-code). For LinkedIn/Glassdoor/Indeed pages that block fetching, the Chrome extension or the built-in browser of Claude.

## Quick start
1. Clone the repository and open the folder in Claude Code.
2. Run the setup (creates `data/` from the templates, never overwrites):
   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\setup.ps1
   ```
3. Fill in `data/profile.md` (every field is explained in the file).
4. Put your CV as an image (JPG/PNG) in `data/CV/`. Claude only reads it to suggest improvements; it is never attached to an application.
5. In Claude Code type `/job-search`.

## Commands
- `/job-search` searches new offers.
- `/job-search apply 10` prepares the application to offer #10 (never sends without your "yes").
- `/job-search discard 11 19 too far` discards offers by your own criteria.
- `/job-search report` summarizes what you applied to.

When a run finishes, the log opens at http://localhost:8765/.

## Folder layout
| Path | What it is |
|---|---|
| `.claude/skills/job-search/SKILL.md` | The skill: all its rules. |
| `scripts/` | `setup.ps1`, `build-log.ps1` (builds the page and saves versions), `log-server.ps1` (local server), `stop-server.ps1`. |
| `templates/` | Empty versions of the data files (`profile`, `job-log`, `history`). |
| `data/profile.md` | **Yours.** Your data, filters, CV paths and base message. |
| `data/job-log.md` | **Yours.** Every offer by status. It is the source of data. |
| `data/job-log.html` | The log as a web page. Generated; do not edit by hand. |
| `data/history.md`, `data/history/` | One version, with date and time, per `/job-search` run. |
| `data/CV/` | Your CV images, for Claude to read only. |

`data/` is created by `scripts\setup.ps1` (or on the first run) and is in `.gitignore`.

## In the log page
- **Applied** moves the offer to Applied and saves it in `job-log.md`.
- **Discard** asks for an optional reason and moves it to Discarded. Check **Discarded** again to restore it.
- **Note** opens a side panel; what you write is saved in `job-log.md`.
- These web actions do not create a history version. Only `/job-search` does.
- **Applied offers and your notes are never deleted**, even if the log is rebuilt: they are restored automatically. To remove an applied offer, uncheck its box.
- If an offer looks like one you already applied to, its card shows "Similar to applied #N" and Claude tells you in the chat.
- If you open `job-log.html` as a plain file it is read-only: use http://localhost:8765/.

## Important rules
- Never sends an application without your "yes" for that offer.
- Never solves captchas: it tells you and waits.
- Never uses files from this folder to apply (CV images are for reading only).
- Never reuses an offer number and never suggests again an offer you discarded.

## Troubleshooting
- Stop the server: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\stop-server.ps1`
- Rebuild the page and start the server: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-log.ps1 -Open`
- Server errors: `data\server.log`

## Customizing
- Add your local staffing agencies to `$agencies` in `scripts\build-log.ps1` (it stops the "same company" warning for companies that post unrelated jobs).
- The scripts must stay plain ASCII (PowerShell 5.1 reads them as ANSI).
