---
name: job-search
description: Searches job offers that match the user's profile (data/profile.md), helps apply (always with the user's confirmation), discards offers by the user's own criteria (mode `discard`) and produces the report of what was applied to. Use when the user says /job-search, "search jobs", "apply to offers", "discard offers" or "applications report".
---

# Job search

On-demand skill: it only acts when the user invokes it. There is no automatic execution.

The user's data lives in `data/` (ignored by git). Nothing about a specific person, city, language or role is hard-coded here: everything comes from `data/profile.md`.

## Absolute rule about files in the project folder
**Never, under any circumstances, use any image or document that is inside the project folder to apply to a job** (anything in `data/CV/` and any other JPG, PNG, PDF, DOC or other file the user leaves here). Do not upload them, attach them, copy them to another folder to upload them, convert them or send them through any channel. They are read-only material: you may open them to read what they say and use that written information (for example to write messages or suggest CV improvements) only when needed. When a form asks for the CV, use the file the user indicates elsewhere (the "CV to upload" path in `data/profile.md`, which lives outside the project, or let the user upload it by hand). If you cannot attach it without using a file from this folder, stop and ask the user.

## First run
If `data/profile.md` does not exist, tell the user to run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\setup.ps1` (it creates `data/` from the templates), fill in the profile, and invoke the skill again. If the profile still has placeholders like `<...>` or empty fields, ask the user for them before searching.

## Project files
- `data/profile.md`: location, radius, role families, exclusions, languages, sources, application data, CV files, experience, writing rules and base message. **Always read it first.**
- `data/job-log.md`: every offer seen, in sections by status: 🟢 To apply, 🟡 Unsure, ⚪ Unverified, ✅ Applied, 💬 Company replies, ❌ Discarded, 📝 User notes. Each offer lives in one section only and keeps its number (#). Read it to avoid repeating offers. After every action, move the row to the right section and update the counts at the top. An offer only goes to 🟢 if you read it completely on the web ("verified"); if you only saw a search-engine summary, it goes to ⚪.
- `data/job-log.html`: a nice view of `job-log.md` (cards, sections, search box). **Never edit it by hand**: it is generated with `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-log.ps1` (from the project folder). It runs in the "Closing every run" step (below), which also saves a version with date and time in `data/history/` and `data/history.md`. `job-log.md` is the only source of data; keep its format (`##` sections and tables with headers) so the script can read it. Section names and column headers are matched by the scripts: do not rename them.
- `templates/`: the empty versions of the data files. Never put personal data there.

## Modes (by argument)
- `search` (default): searches and presents new offers.
- `apply <n|url>`: helps apply to one specific offer.
- `report`: summary of the day.
- `discard <n [n ...]> [reason]`: discards offers by the user's own criteria, whatever section they are in (see "discard" below).

## Applications marked by hand in job-log.html
`job-log.html` is opened from a local server (`scripts/log-server.ps1`, http://localhost:8765/, localhost only), which `build-log.ps1 -Open` starts by itself in the background if it is not running. With it, the user can in the page:
- Check **"Applied"** on an offer: the server moves the row to ✅ Applied in `job-log.md` (date and time, CV "(manual, by the user)", no message, and it keeps the original row in an `<!--orig:...-->` comment so it can be undone), updates the counts and regenerates the page, which reloads itself. Unchecking it moves the row back.
- Check **"Discard"** on an offer in 🟢, 🟡 or ⚪: the page asks for a reason (optional), the server moves the row to ❌ Discarded with the reason "Discarded by the user: .... Origin: <section>" and keeps the original row in an `<!--orig:...-->` comment, updates the counts (including the ❌ line) and regenerates the page. In ❌, offers discarded from the web have the **"Discarded"** box checked: unchecking it (with confirmation) moves the offer back to its section. Offers discarded by the skill or by a filter have no checkbox; to bring them back, ask in the chat ("put offer 11 back").
- Press the **"Note"** button of any offer: a side panel opens; when saved, the note goes to the `User notes` section of `job-log.md` (table `# | Offer | Date and time | Note`, line breaks as `<br>`) and the page is regenerated.

Rules for you:
- **Read the `User notes` section of `job-log.md` at the start of every run** and take it into account (for example, if a note says to discard something or to call someone). Do not delete or rewrite those notes.
- If an offer is already in ✅ Applied, do not propose it again or apply to it again.
- When you apply with the skill, move the row to ✅ Applied with the real data (date and time, CV used, message sent) and regenerate the page: the server detects the change and the open page reloads itself.
- Rows discarded from the web start with "Discarded by the user", like those from the `discard` mode: **never suggest them again** (see "discard"). If, when restoring a discarded row, you see the `<!--orig:...-->` comment, use that original row (it is base64 UTF-8 encoded) and the section it names.
- **These web saves (mark applied, discard or restore, notes) do NOT create a history version.** Only this skill creates versions, in its closing step. The scripts `log-server.ps1` and `build-log.ps1` without `-Note` never create them.
- If the page is opened as a file (`file://`) it is read-only. To stop the server: `scripts\stop-server.ps1`. If something fails, look at `data/server.log`.

## Applied offers are permanent
- The ✅ Applied and 💬 Company replies sections and the `User notes` section **are never deleted, renumbered or rewritten**, neither when the log is rebuilt nor when old offers are cleaned up. The other sections (🟢, 🟡, ⚪, ❌) can be regenerated or cleaned. If you rewrite `job-log.md`, copy those sections as they are.
- Automatic safeguard: `build-log.ps1` keeps a copy in `data/job-log-applied.bak` and, if any Applied or Notes row is missing, restores it and prints `RESTORED: ...`. If you see that in the output, tell the user. To remove an applied offer use the checkbox on the web page, and to delete a note use the "Delete note" button; do not edit them by hand.
- **Numbering**: never reuse a number. New offers continue from the highest `#` in the whole log (including applied and discarded).
- **Offers similar to an applied one**: when searching, compare every new offer with the applied ones (same company or similar position, even from another source or with another title). If it matches, **tell the user in the chat** with "⚠ Similar to applied #N (company, position)", do not present it as new without that warning, and add "⚠ Similar to applied #N" to its row in `job-log.md`, in the `Notes` column. The page also shows it by itself with an orange notice and a link to the number.

## Closing every run (mandatory, in any mode, even with no changes)
Every time this skill is invoked, when it finishes:
1. Update the "Last updated" line of `job-log.md` with date and time (`yyyy-MM-dd HH:mm`) and what was done.
2. Run, from the project folder: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-log.ps1 -Run <search|apply|report|discard> -Note "<short summary of what changed: new offers, moved between sections, applied, discarded>" -Open`. This does four things: regenerates `job-log.html`, saves a copy of `job-log.md` in `data/history/job-log_<date>_<time>.md`, adds a row (version, date and time, mode, changes) to `data/history.md` and opens `job-log.html` in the browser. If nothing changed, put "No changes" in `-Note`: the version is still saved.
3. Tell the user in one line the version and time (for example "Saved v5, 2026-11-04 10:15; the log is open").
Do not move on to anything else without this closing. If the script fails, tell the user the error. **This closing is the only thing that creates a history version**: do not use `-Note` outside a run of this skill (not for manual adjustments or for changes made from the web page).

## search
**Rule: on every run, check ALL the pages the user gives you** (in the message or in the invocation), in addition to all the sources in the profile's "Job sources". Do not stop at one source or consider the search done after the first site. If a site cannot be checked (block, captcha, domain not allowed), say so in the final summary, naming which one and why.

1. Sources, in the order listed in the profile. Use WebSearch/WebFetch with the city and the keywords from the profile. If a page blocks fetching (common with Indeed and InfoJobs), use the browser (skill `anthropic-skills:chrome-browser` or `built-in-browser`; read it before using its tools). Always use the search variants below, not just one word.
   - **Job titles to search** (in every language the profile lists, because offers come in several). Search by families, not by a single word: take the "Role families", "Seniority / job titles" and "Keywords to add" from the profile and combine each family with each title and each language. Example for customer service: "customer care / customer service / customer support / customer experience / client service" with "agent, advisor, specialist, representative, associate, coordinator, analyst", and the same in the other languages (for example in Spanish: "atención al cliente", "servicio al cliente", "soporte al cliente", with agente, asesor/a, especialista, gestor/a, coordinador/a).
   - **Language filter**: add or combine words like "bilingual" or the languages the user speaks. When reading each offer, confirm the required languages are only those under "Languages an offer may require" in the profile (discard if it demands any other).
   - **Wildcards and operators**: not every site accepts `*`, so do not assume it. Order of preference:
     1. On **Indeed, LinkedIn and Glassdoor** try first a combined search with quotes, parentheses and OR, for example `("customer care" OR "customer service" OR "customer support" OR "operations support")`, and add `AND (english OR bilingual)` to narrow by language. Indeed and LinkedIn accept these operators; on Glassdoor it is not guaranteed.
     2. For word stems use `*` only if the site supports it (for example `agent*`). If the wildcard returns 0 or strange results, do not insist: expand by hand ("asesor", "asesora", "asesores").
     3. On **InfoJobs** the keyword goes in the URL: do one search per variant.
     4. If a combined search fails or the site ignores it, search by family and merge the results, removing duplicates against `job-log.md`.
   - Known site notes (they have worked before; sites change, so verify):
     - **InfoJobs**: `https://www.infojobs.net/ofertas-trabajo/<city>/<keyword-with-hyphens>`. The list loads in chunks: scroll to the bottom before reading the page text. You can filter by remote work, date and working hours with the checkboxes on the left.
     - **Indeed**: `https://<country-domain>.indeed.com/jobs?q=<words+with+plus>&l=<City>&fromage=14` (`fromage=14` = last 14 days). When it loads, `get_page_text` returns the list plus the full text of the first offer. To read another, open it from the list. It may show the Cloudflare check; if it does, follow the human-verification rule below.
     - **Glassdoor**: do not build search URLs with city codes (`IL.0,9_IC...`): an invented code leads to another city. Do not use `/Empleo/` as an entry page (404). Enter through the site's job index page, click the "Find your ideal job" box and type the role, click the "City, state or remote" box and type the city, choose the first suggestion that matches your city and country from the dropdown and press Enter. Check that the page title says the right city before reading results.
     - **LinkedIn**: read-only in the user's browser with their session already open, or reading their alerts through Gmail if the connector is authorized. `https://www.linkedin.com/jobs/` shows "Jobs based on your preferences"; read them with `get_page_text`. To search, use the page's search box, one search type at a time, without paging massively. Never log in for the user and do not run mass searches: their terms forbid automation and can get the account blocked. If Chrome answers "Navigation to this domain is not allowed", the domain is not allowed in the extension: tell the user and wait, do not work around it.
   - **Human verification (captcha, Cloudflare, "I am not a robot") on any site**: never solve it yourself. Stop, tell the user in the chat which page asks for it and ask them to complete it in the Chrome tab. Wait for their answer (for example "done"), take a screenshot or read the page to confirm the offer loaded, and then continue where you left off. If the page stays blocked after the check, say so and move to another source instead of retrying.
2. Filter according to `data/profile.md` (location, language, exclusions, "Always discard") and drop what is already in `job-log.md`.
3. Present a short numbered list: position, company, **what the company does (1 sentence)**, location, salary if shown, source and link. For verified offers (those that go to 🟢 or 🟡) also add **CV improvements** (0 to 5 changes already written to paste, based on their real CV; see "Suggested CV adjustments" below). Add the new ones to `job-log.md` in the right section (🟢, 🟡 or ⚪) and the discarded ones with their reason to ❌.
   - **What the company does**: take it from the offer text, the "About the company" section or the company page. Do not invent: if there is no data, write "No data; check when verifying the offer". If you write it from memory or from the name, say "(confirm when verifying)".
   - **Columns in `job-log.md`**: the 🟢 and 🟡 tables end with the columns `What the company does` and `CV improvements`; the ⚪ table has `What the company does`; ❌ has neither. An offer that moves from ⚪ to 🟢/🟡 when verified must also get its `CV improvements`. `build-log.ps1` shows those two columns as highlighted blocks in `job-log.html`.
4. Ask which ones to apply to. Never apply to anything on your own initiative.

## apply
1. Open the offer in the browser and fill in what you can with the data from `data/profile.md`.
2. **Before sending, show the user a summary (position, company, what will be sent, cover message) and wait for an explicit "yes" for that offer.** A "yes" is not valid for the next ones.
3. If there is a login, a question the profile does not cover or any doubt, stop and ask the user. If there is a captcha or human verification, stop, ask the user to complete it in Chrome, wait for them to confirm and continue with the form from that point. Never solve the verification yourself.
4. Write the message from "Base cover message" in `data/profile.md`, following "Writing rules for messages", and run it through the **humanizer filter** (below).
5. Next to the summary, include **Suggested CV adjustments** (below): written to paste, based on reading the real CV and with the humanizer filter. If the offer already has `CV improvements` in `job-log.md`, check them against the real CV and refine them with what you see in the form.
   - **Form rules**:
     - Use references (`find`/`read_page` + `form_input`) instead of clicks by coordinates, and take a new screenshot before every click by coordinates: if the page scrolled, the click lands on another field. After filling, verify with a screenshot or text that every field has its value.
     - **Do not fill optional diversity fields** (gender, ethnicity, etc.) or "contact me for future offers" boxes. Leave them blank. If any is checked by mistake, fix it and tell the user.
     - Accepting a privacy policy or terms is a confirmation: check that box only after the user has said "yes" to the final summary.
     - Cookie banners: reject the non-essential ones.
     - Questions the profile does not cover (shift, remote work, salary package, availability, etc.): do not answer them yourself; ask the user with the exact text of the question.
     - CV upload: `file_upload` only accepts folders authorized for the session. If the "CV to upload" path from the profile is not authorized, ask the user to authorize that folder with `/add-dir` or to upload the CV by hand in that field. **Do not copy the CV into the project folder** and do not use the files in `data/CV/` (see the absolute rule above).
     - Phone: if the field asks for a prefix, put the "Phone country prefix" from the profile before the number.
6. After sending, move the row to ✅ Applied in `job-log.md` with date and time, CV used and message sent.

## Humanizer filter (mandatory on every message)
Before showing the message, review it and fix:
- Remove AI filler: "passionate about", "dynamic", "proactive" without proof, "I am delighted", "synergies", "I have no doubt", "excellent opportunity", lists of three adjectives.
- Use at least one concrete fact from the offer (tool, language, type of customer, sector) and one real fact from the profile (company, tool, years). Do not invent experience or achievements that are not in `data/profile.md` or in the CV.
- Short, varied sentences, natural voice, polite but without flourishes. Follow the "Writing rules for messages" of the profile (register, phone number, language).
- Vary the greeting and the closing between applications so they are not identical.
- Respect the maximum words from the profile. If the offer asks for a long letter or specific questions, answer those instead of the base text.

## Suggested CV adjustments (in every application)
**Rule: the improvements are based on the user's real CV, come already curated and written so they can copy them into the CV, and go through the humanizer filter.** Comments like "move this point up" about sentences that are already in the CV are useless.

They are written **twice**: in `job-log.md` (column `CV improvements`) as soon as a verified offer enters 🟢 or 🟡, and again in the summary before each application (starting from what was written, refined with what is seen in the form).

**Step 1: read the real CV, always, before writing anything.** Open the "CV to read" image from `data/profile.md` (the language that matches the offer) with the image-reading tool, **only to read it, never to attach or copy it** (see the absolute rule above). Do not write improvements from memory or from the summary in `data/profile.md`: that summary is not the CV. If the image is missing, tell the user and do not write improvements until you have it. If the CV changes, the user updates the image.

**Step 2: compare the offer with the CV, sentence by sentence.** Note what the offer asks for (tools, channels, type of customer, sector, languages, keywords) and what the CV already says. **Do not propose anything the CV already says in the same words or with an equivalent meaning.** Do not "raise", "highlight" or "reorder" a sentence that is already well placed. Only these changes are valid:
- A **new or rewritten** sentence that rephrases something already true using the offer's keywords (for example the CV says "Processed customer returns and refunds" and the offer talks about e-commerce returns).
- A tool or skill that today only appears in Skills and should be moved to a specific job, **only if the user confirms where they used it**.
- Something the CV does not say and is probably true (for example chat support): do not assume it; **ask them** and leave the change pending their confirmation.
- A change of order between jobs, only if it really changes the effect (not if the job is already on top).

**Step 3: write it ready to paste.** Each improvement says **where it goes** (Summary, a specific job or Skills), **which sentence it replaces or is added** (quote the current CV sentence if it replaces one) and **the new text, complete and ready to copy**, in the language of the CV that matches the offer. Use the CV's style (bullets with a past-tense verb in English, short sentences). Format in the log: a single cell, numbered "1) ... 2) ...", without the `|` character. Example: `1) Klarna, 2nd bullet. Replace "Processed customer returns and refunds with accuracy" with "Processed customer returns and refunds for online purchases with accuracy" (only if they were purchases in online shops).`

**Step 4: run it through the humanizer filter** (the one above, adapted to a CV): no AI filler ("proactive", "dynamic", "passionate", "results-driven", "synergies", repeated "ensuring"), no lists of three adjectives, concrete verbs, one real fact per bullet (tool, volume, type of customer, market), short and varied sentences, nothing inflated and not the same structure in every bullet. Do not invent figures, tools or achievements that are not in the CV or that the user has not confirmed.

**Quantity and no-change cases.** Between 0 and 5 improvements: those that really add something. If the CV already fits the offer, write "The CV already fits the offer; no changes needed" (and, if relevant, which CV to use). Do not pad up to 3. Never propose adding something the user has not done. If an improvement depends on something you do not know, write it anyway marked "(confirm: ...)" and ask in the chat with the exact text of the question.

## discard
Lets the user remove offers by **their own criteria**, even if they are in 🟢 To apply (or in 🟡 or ⚪), to keep the "To apply" section clean. Invoked, for example, with `/job-search discard 11`, `/job-search discard 11 19 28 I don't like the shift` or in natural language ("discard 20, the salary is low"). The offer does not need to fail any filter rule: what the user decides rules, not the profile.
1. **Read `job-log.md`** (and the user notes) and locate each given number. If a number does not exist, say so and carry on with the others.
2. **Reason**: use the one they give, in their words (summarized, without inventing). If they give none, write "Discarded by the user" and do not ask (do not slow them down). If the user notes include a note about that offer that explains why, you may add it to the reason quoting it as "(user note)", without copying it whole.
3. **Move the row** to the ❌ Discarded section using that table's format (`# | Position | Company | Location | Reason`): keep the number (#), the position, the company and the location (remove the markdown link only if it gets in the way; if you keep it, leave it in the position) and write the reason preceded by "Discarded by the user:". **Do not lose the useful data** of the original row (salary, contract, catch): summarize it at the end of the reason, in case they want to recover it later.
4. **Remove the row from its original section** (🟢, 🟡 or ⚪) and update the counts at the top. An offer lives in one section only.
5. **Limits**: if the offer is in ✅ Applied or in 💬 Company replies, **do not move it** (those sections are permanent): tell the user and leave the row where it is. Do not touch the `User notes` section.
6. **Undo**: if they ask to recover a discarded one ("put 11 back"), move the row to the section it was in (according to what you wrote in the reason; if unknown, to ⚪, or to 🟢 if it was verified and the CV improvements are still in the row) and rebuild the columns of that table. Tell them what could not be recovered.
7. **Never suggest again an offer the user discarded, not the next day and not in any later search** (same company and similar position, even from another source, with another title or republished). Before presenting new offers in `search`, compare each one with the ❌ Discarded section, like you do with the applied ones. If it matches, do not include it in the list or in ⚪/🟢/🟡 or count it as new (at most one line in the summary: "N offers already discarded by you, skipped"). Only exception: if it reappears with an important change (other salary, other shift, other required language), mention it in one line and let them decide; do not present it as new. This applies only to those **the user** discarded (the ones that start with "Discarded by the user"); the ones you discarded by filter can be re-evaluated if the profile changes.
8. **Confirmation**: no need to ask permission, it is reversible and the user asked for it. But **show at the end what you moved**: number, position, company, reason and the section it left. If they listed many offers at once (more than 5), show the list before applying the change.
9. **Mandatory closing** as in any run: update "Last updated" and run `build-log.ps1 -Run discard -Note "<summary: offers discarded and reason>" -Open`, and tell them the version and time.

## report
1. Read `job-log.md` and summarize: applied today, pending (sections 🟢, 🟡 and ⚪), discarded and replies received.
2. Show it in the chat.
3. If the user wants the report by email and the Gmail connector is authorized, prepare it as a **draft** or send it only to the "Email for reports" from the profile after confirming. If the connector is not authorized, tell them they must authorize it from the connector settings in claude.ai.
4. If they see replies from companies (in Gmail or in the browser), move that row to the 💬 Company replies section and tell them.
