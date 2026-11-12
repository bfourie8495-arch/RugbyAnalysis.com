# RugbyAnalysis house rules

`tokens.json` lists the brand colours and fonts. Nothing reads it yet; it is the one place to check a value.
The name is **RugbyAnalysis**, one word, everywhere.

## Charts and cards

1. **One accent.** Gold (`#C9A24B`) marks the point: the pick, the leader. Everything else is grey
   (`#B9BDC7` on light, `#66748A` on navy). Team colours appear on flags only.
   **Exception, the website:** each team's page keeps that team's colour as its one accent (already one
   accent plus grey). Do not recolour the site's team pages gold. Posts, reels and the app follow rule 1.
2. **Green and red only mean right and wrong**, and always with a tick or a cross, never colour alone.
3. **Titles state the finding** ("New Zealand have won 94%"), never the topic ("Head to head").
4. **Bars start at zero.** A bar's length is the number. For values that sit close together (ranking
   points), use dots on a labelled scale instead of a cut bar.
5. **Label values directly.** No legends, no background gridlines.
6. **Small samples.** Under five games, show no averages.
7. **Gold text on light backgrounds** uses `#85601B`, never the fill gold.

Fonts: Poppins for headings and numbers, Figtree for body text, on the website, app and posts alike.

## Rankings

Lead with World Rugby's official rankings in posts, reels and on the site. RugbyAnalysis's own ratings
(the replay behind the model's chances) appear only to explain a pick, and are always labelled as ours.
Decided 11 Nov 2026.

## Readable by everyone (checked 11 Nov 2026)

- Every colour pair we rely on (gold v grey, gold v blue, win v loss) stays distinguishable under protanopia,
  deuteranopia and tritanopia (simulated). Win and loss also carry a letter, a tick or a word, never colour alone.
- Text needs 4.5:1 against its background (3:1 for large text and chart marks). The site's small grey text,
  gold words on cream and grey bars on navy were darkened or lightened to pass.
- Charts on the site have a text label (`role="img"` + `aria-label`); app charts have `Semantics` labels.
- Posts: give every image Instagram alt text (Advanced settings > Accessibility), one plain sentence of the
  finding, e.g. "Bar chart: New Zealand have won 267 Tests since 2000, England 200, South Africa 199."
