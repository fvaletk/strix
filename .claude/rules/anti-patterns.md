---
paths:
  - "app/**/*.rb"
---

# Anti-Patterns to Avoid

Size limits, the extraction threshold, and the callback rule live here only.

- **Premature Abstraction**: Duplicate code is cheaper than the wrong abstraction — extract on the third concrete use with the same shape, not before.
- **God Model**: If a model exceeds ~200 lines, extract business logic to services and complex queries to query objects. The model keeps only persistence, validations, associations, and simple scopes.
- **Fat Controller Action**: If an action has more than ~10 lines of business logic, extract it to a service. The action keeps params, authorization, the service call, and the response.
- **Service Graveyard**: Don't create services for trivial CRUD. `user.update!(name: params[:name])` is fine inline. The bar for extraction is real complexity.
- **Callback Spaghetti**: Callbacks are for the record's own data — normalization (`before_validation`), and `after_commit` for Turbo broadcasts and cache invalidation of that record. Emails, jobs, API calls, and creating or updating other records are contextual side effects: call them explicitly from a service.
- **Kitchen Sink Concern**: A concern is a *property* of the model (`SoftDeletable`, `Sluggable`); an *operation* on it (`CancelOrder`, `ImportCsv`) is a service. If a concern exceeds ~30 lines or has multiple responsibilities, it's a service object in disguise.
