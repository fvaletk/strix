---
paths:
  - "app/mailers/**/*.rb"
  - "app/views/**/*_mailer/**/*.erb"
  - "spec/mailers/**/*.rb"
---

# Mailer Conventions

- Always provide both HTML and text templates
- Mailer previews live in `spec/mailers/previews/` — this needs `config.action_mailer.preview_paths << Rails.root.join("spec/mailers/previews")` in `config/environments/development.rb`
