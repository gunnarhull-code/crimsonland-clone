# Rubric page

The phone and desktop page that shows the upgrade rubric (upgrades, timeline, pillars and roster tabs).

- `template.html` is the page source. It has two placeholders, `__CSV__` and `__ROSTER__`.
- `build.ps1` fills them from `../upgrade-rubric.csv` and `../roster-100.csv` and writes `rubric.html` (not committed).
- Edits made on the page are saved in the browser only. Use the page's Copy CSV button and paste the result over `../upgrade-rubric.csv` to keep them.
- The page parses CSV by splitting on commas, so cells in the CSV must not contain commas.
