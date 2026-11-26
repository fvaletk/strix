require "rails_helper"

RSpec.describe StatusBadgeComponent, type: :component do
  {
    "processing" => %w[bg-mint text-accent],
    "ready" => %w[bg-neutral-chip text-ink-2],
    "failed" => %w[bg-warn-soft text-warn]
  }.each do |status, classes|
    it "renders the #{status} badge with a dot and a text label", :aggregate_failures do
      badge = render_inline(described_class.new(status:)).at_css("span")

      expect(badge.text.strip).to eq(status)
      expect(badge["class"].split).to include(*classes)
      expect(badge.at_css("span[aria-hidden='true']")).to be_present
    end
  end
end
