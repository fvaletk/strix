---
paths:
  - "app/services/**/*.rb"
  - "spec/services/**/*.rb"
---

# Service Object Conventions

- **Match the project first.** If `app/services/` already has a pattern (call style, return value), follow it. The rest of this file is the default for projects without one.
- Plain Ruby classes. Arguments and dependencies go in the constructor; one public instance method, `#call`
- Class-level shortcut, one line per service: `def self.call(...) = new(...).call`
- Return a `Result` (`app/services/result.rb`) — create it the first time a service needs it:
  ```ruby
  Result = Data.define(:success, :data, :error, :code) do
    def self.success(data = nil) = new(success: true, data:, error: nil, code: nil)
    def self.failure(error, code: nil, data: nil) = new(success: false, data:, error:, code:)
    def success? = success
    def failure? = !success
  end
  ```
- Business-rule failures — outcomes the caller branches on — return `Result.failure("message", code: :symbol)`; don't raise. Failures of an external dependency (malformed API response, timeout) raise a namespaced error class (`<Client>::InvalidResponseError`) so the calling job can retry or mark the record failed. Rescue specific exceptions, never bare `StandardError`
- Namespace by domain: `Orders::CancelService`, `Reports::GenerateService`
- Wrap multi-model writes in `ActiveRecord::Base.transaction`; enqueue jobs and send mail after it commits — a job enqueued inside the transaction can run before the rows are visible
- Mail: `deliver_later`; `deliver_now` only inside a job
- Test both success and failure paths with `subject(:result) { described_class.call(...) }`
