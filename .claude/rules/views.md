---
paths:
  - "app/views/**/*.erb"
  - "app/components/**/*.rb"
  - "app/components/**/*.erb"
  - "spec/components/**/*.rb"
  - "app/presenters/**/*.rb"
  - "spec/presenters/**/*.rb"
---

# View & Component Conventions

- Views hold markup only; display formatting goes in presenters (`app/presenters/`, `SimpleDelegator`)
- If ViewComponent is used: components (`app/components/`) over partials for reusable UI with logic
- Regions that Turbo Streams update with status text (flash, counters, "saved") get `role="status"` / `aria-live="polite"` so screen readers announce the change
