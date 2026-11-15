---
paths:
  - "app/jobs/**/*.rb"
  - "app/workers/**/*.rb"
  - "app/sidekiq/**/*.rb"
  - "spec/jobs/**/*.rb"
  - "spec/workers/**/*.rb"
  - "spec/sidekiq/**/*.rb"
  - "config/sidekiq.yml"
---

# Background Job Conventions (Sidekiq)

- Match the project's existing style: Active Job (`ApplicationJob` + `queue_adapter = :sidekiq`) or native `include Sidekiq::Job` — don't mix both in new code
- Jobs must be idempotent — Sidekiq retries failures and delivers at least once. Guard on state (`return if order.paid?`)
- Pass IDs, not records. Handle deleted records: Active Job `discard_on ActiveRecord::RecordNotFound`; native: `find_by` and return early
- Retries: Active Job `retry_on SpecificError, attempts: n`; native `sidekiq_options retry: n`. Never retry blindly on `StandardError`. Pick one retry layer: with Active Job `retry_on`, set `sidekiq_options retry: false` on the job
- Set the queue explicitly (`queue_as :default` / `sidekiq_options queue: "default"`) and keep queue names in sync with `config/sidekiq.yml`
- `pool` in `config/database.yml` must be ≥ Sidekiq `concurrency`, or job threads time out waiting for a connection
- Business logic lives in a service the job calls
