require "rails_helper"

RSpec.describe TagChipComponent, type: :component do
  it "renders the small borderless chip for list rows", :aggregate_failures do
    chip = render_inline(described_class.new(name: "bees")).at_css("span")

    expect(chip.text.strip).to eq("bees")
    expect(chip["class"].split).to include("bg-mint", "text-mint-ink", "text-[13px]")
    expect(chip["class"].split).not_to include("border-mint-2")
  end

  it "renders the larger outlined chip for the Article page with its description", :aggregate_failures do
    chip = render_inline(described_class.new(name: "bees", size: :article, description: "About bees")).at_css("span")

    expect(chip.text).to include("bees")
    expect(chip["class"].split).to include("border-mint-2", "text-sm")
    expect(chip["title"]).to eq("About bees")
  end
end
