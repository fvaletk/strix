require "rails_helper"

RSpec.describe NoticeComponent, type: :component do
  {
    info: %w[bg-mint text-accent-hover],
    failure: %w[bg-warn-soft text-warn-ink],
    partial: %w[bg-partial-bg text-partial-ink border-dashed border-latte-deep]
  }.each do |variant, classes|
    it "renders the #{variant} variant with its content", :aggregate_failures do
      notice = render_inline(described_class.new(variant:)) { "Hello there" }.at_css("div")

      expect(notice.text.strip).to eq("Hello there")
      expect(notice["class"].split).to include(*classes)
      expect(notice["role"]).to eq("status")
    end
  end

  it "uses role alert for failures only when asked" do
    notice = render_inline(described_class.new(variant: :failure, role: "alert")) { "Nope" }.at_css("div")
    expect(notice["role"]).to eq("alert")
  end
end
