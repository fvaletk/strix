# Strix design — MVP

Source of truth for the visual design: the **Strix MVP UI** canvas (claude.ai artifact `Hi2joxjqJ8Av8JvB2QzmJ7`, private to the owner). This file is the repo copy agents build from.

Mood: soft, cozy, natural — a calm reading page, not a dashboard. Palette: Mint Latte Neutrals.

## Tokens

Put these in the Tailwind theme (`app/assets/tailwind/application.css`, `@theme`) and use the utilities — never hard-code hexes in views.

```css
@theme {
  --color-paper: #F3EFE6;        /* page background (latte) */
  --color-surface: #FFFCF7;      /* cards, header */
  --color-field: #FAF7F1;        /* input backgrounds */
  --color-border: #E3D9CC;       /* card borders */
  --color-divider: #E8E0D3;      /* rules inside cards, skeleton bars */
  --color-control: #C4B39F;      /* input and secondary-button borders */
  --color-latte-deep: #D8C8B6;   /* dashed partial-failure outline */

  --color-ink: #1F2723;          /* primary text */
  --color-ink-2: #46524C;        /* secondary text */
  --color-ink-3: #5E6B64;        /* meta text (min. for 4.5:1 on paper) */
  --color-reading: #2C3530;      /* key points body */
  --color-sage: #6B7B73;         /* decorative icons only — not for text */

  --color-accent: #2F6B55;       /* primary buttons, links, processing text */
  --color-accent-hover: #24543F;
  --color-mint: #C9F7E3;         /* Tags, citations, processing badge, info notice */
  --color-mint-ink: #24493B;     /* text on mint */
  --color-mint-2: #A8E1CC;       /* Tag outline on the Article page */

  --color-neutral-chip: #EAE2D6; /* Ready badge, active nav item */

  --color-warn: #8A4A1F;         /* failure text, failed badge */
  --color-warn-soft: #F6E3D3;    /* failure notice / failed badge background */
  --color-warn-ink: #6E3A17;     /* text inside the failure notice */
  --color-partial-bg: #FAF5EC;   /* tagging-failed notice background */
  --color-partial-ink: #5A4636;

  --font-serif: "Newsreader", Georgia, serif;   /* titles, Summaries, Answers, Questions */
  --font-sans: "Inter", system-ui, sans-serif;  /* interface */
}
```

Fonts: Google Fonts — Inter 400/500/600, Newsreader (opsz 6..72) 400/500/600.

Every text colour above passes 4.5:1 on the background it's used on. `sage` and `mint-2` are decorative only.

## Shared rules

- Layout: header full width (surface, bottom border), content centred. Lists: `max-width: 1040px`. Reading pages (Article, Ask, Question): `max-width: 760px`. Side padding 24px; works at phone width (nav wraps, rows stack).
- Radii: cards 14–16px, inputs and buttons 10px, Tag chips 6px, badges fully rounded.
- Buttons are 48px tall; every link or button is at least 44px tall.
- One primary (accent) action per screen.
- Status colours: **processing** = mint; **ready** = neutral chip; **failed** = warn. Each badge has a dot and a text label, never colour alone.

## Components (ViewComponent candidates)

| Component | Look |
|---|---|
| Status badge | pill, 13px/600, 7px dot in the text colour. processing `mint`/`accent`, ready `neutral-chip`/`ink-2`, failed `warn-soft`/`warn` |
| Tag chip | `mint` bg, `mint-ink` text; 14px with a `mint-2` border on the Article page, 13px without border in list rows |
| Article row | surface card, serif 21px/600 title (or the URL in sans 16px `ink-2` when there's no title yet), meta line, TL;DR in serif 17px, Tag chips; failure reason in `warn`; "Tagging failed" note in `warn` 13px |
| Citation marker | inline 22px square-ish chip, `mint` bg, `accent` text, links to `#source-n` |
| Source card | surface card, 32px numbered square in `mint`, serif title, meta line (domain · Tags) |
| Notice | info: `mint` / `accent-hover` text. failure: `warn-soft` / `warn-ink`. partial: dashed `latte-deep` border, `partial-bg` / `partial-ink` |
| Empty state | centred: `sage` icon, serif 22–26px line, one helper sentence, actions |

## Screens

1. **Articles list** (`/articles`, root) — serif "Articles" h1 + count; save form card (label "Save an Article", URL input, primary "Save", helper line); Article rows newest first in every status.
2. **Article page, ready** — back link "Articles"; serif 42px title; meta row (domain link ↗ · saved date · word count · Ready badge); Summary card (eyebrow "Summary", TL;DR serif 22px, divider, "Key points" list serif 18px with accent dots); Tags; actions "Open original ↗" (secondary) and "Ask your Articles" (quiet).
3. **Article page, processing** — URL as title, Processing badge, info notice "Strix is reading this page…", three skeleton bars where the Summary goes.
4. **Article page, failed** — URL as title, Failed badge, failure notice "Couldn't extract this page" with "Reason: <failure_reason>", "Open original ↗".
5. **Article page, tagging failed** — normal ready page, but the Tags section shows the partial notice "Tagging failed. The Summary and search still work." with a "Retry tagging" secondary button.
6. **Ask** (`/questions/new`) — serif "Ask your Articles" h1, one-line promise, form card (label "Your Question", serif textarea, "Searches all N Articles", primary "Ask"); "Recent Questions" (3, with "See all").
7. **Question, answered** (`/questions/:id`) — back link "Questions"; eyebrow "Question", serif 36px Question, meta "Asked <date> · searched all Articles"; Answer card (eyebrow "Answer", serif 20px paragraphs with citation markers); "Cited Articles" source cards; primary "Ask another Question".
8. **Question, nothing found** — same header; Answer card is the empty state: "Nothing in your Articles covers this." + helper + "Save an Article" (primary) and "Ask something else" (secondary).
9. **Questions list** (`/questions`) — serif h1 + count, primary "Ask a Question"; rows: serif Question, date, result pill ("N Articles cited" in mint, "Nothing found" in neutral chip, "No answer" in warn-soft/warn).
10. **Question, no answer** (`/questions/:id` when answering failed) — same header as 7; in place of the Answer card, a failure notice: first line "Couldn't answer this Question. Try again." (only right after the failed ask, from the flash), then "No answer yet."; primary "Ask another Question". No retry button.

Header on every page: owl mark + serif "Strix" wordmark linking home; nav Articles · Ask · Questions, current item in `neutral-chip` bold.
