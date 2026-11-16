# Job search profile

Fill in every field before your first search. Keep the `- Field: value` format: Claude reads this file first on every run and asks you about anything that is empty.
Lines starting with `>` are help text; you can delete them.

## Location
- Country: <e.g. Spain>
- City / province: <e.g. Barcelona>
- Max distance for on-site work (km): <e.g. 10>
- Remote work: <yes | no | only remote>

## What I am looking for
> Role families are searched in every language listed under "Languages offers may be written in".
- Role families: <e.g. customer service / customer care / customer support; operations support; localization>
- Seniority / job titles: <e.g. agent, advisor, specialist, representative, coordinator, analyst>
- Keywords to add: <e.g. bilingual, English speaking>
- Words to exclude: <e.g. door-to-door sales, commission only>
- Employment type: <full-time | part-time | any>
- Minimum gross yearly salary (optional): <e.g. 20000>
- Always discard: <e.g. call centers, senior or manager roles, part-time>

## Languages
- Languages I speak (with level): <e.g. Spanish native; English C1>
- Languages an offer may require: <e.g. Spanish, English. Any other required language = discard>
- Languages offers may be written in: <e.g. English, Spanish>

## Job sources
- Sites to search, in order: <e.g. InfoJobs, Indeed, LinkedIn, Glassdoor>
- Extra pages Claude should always check (optional): <URLs>

## Application data
- Full name: <your name>
- Phone (national format): <number>
- Phone country prefix: <e.g. +34>
- Contact email: <email>
- Email for reports (optional): <email>
- LinkedIn: <url>
- Work authorization / status: <e.g. EU citizen, no permit needed. Open to work>
- Availability to start: <e.g. immediate>

## CV files
> "To read" = an image (JPG/PNG) inside data/CV/ that Claude opens ONLY to read it and suggest improvements.
> "To upload" = the real file (usually PDF) that is attached to applications. It must live OUTSIDE this project folder.
> Claude never attaches, copies or uploads anything from this project folder.
- CV to read, language 1: <e.g. data/CV/cv_en.jpg>
- CV to upload, language 1: <e.g. C:\Users\you\Documents\CVs\CV_English.pdf>
- CV to read, language 2 (optional): <e.g. data/CV/cv_es.jpg>
- CV to upload, language 2 (optional): <e.g. C:\Users\you\Documents\CVs\CV_Spanish.pdf>
- Which CV for which offer: <e.g. English CV for offers in English, Spanish CV for offers in Spanish>

## Experience (summary of your CV, used to adapt messages)
> One line per job: company, city, dates, role, and the concrete things you did. Do not invent anything: Claude only uses what is written here and in your CV.
- <Company, City (mon yyyy - mon yyyy): Role. What you did, tools you used.>
- <Company, City (mon yyyy - mon yyyy): Role. What you did, tools you used.>
- Tools: <e.g. Jira, Freshdesk, Zendesk>

## Writing rules for messages
- Language of the message: <same as the offer | always English | always Spanish>
- Register: <e.g. polite and neutral; avoid regional forms such as "vosotros" in Spanish>
- Do not include the phone number in the message: <yes | no>
- Maximum words: <e.g. 100>

## Base cover message
> Claude adapts this text for each offer. Keep [company], [position] and the bracketed sentence: Claude fills them in.
> One block per language if you apply in more than one.

Hello [company] team,

I am writing about the [position] role. <One or two sentences with your real experience.> [One concrete sentence about what in the offer fits that experience.] <Languages and city.>

I attach my CV and I am happy to give more details. Thank you for your time.

Kind regards,
<Your name>
