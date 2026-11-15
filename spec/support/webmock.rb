require "webmock/rspec"

# Specs never make real network calls — stub them (see stub_in_specs in CLAUDE.md).
WebMock.disable_net_connect!(allow_localhost: true)
