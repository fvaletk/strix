require "rails_helper"

RSpec.describe Articles::SaveService do
  subject(:result) { described_class.call(user:, url:) }

  let!(:user) { create(:user) }


  context "with a new URL" do
    let(:url) { "https://Example.com/post/?utm_source=x#top" }

    it "creates a processing Article with the normalized URL", :aggregate_failures do
      expect { result }.to change(user.articles, :count).by(1)
      expect(result).to be_success
      expect(result.code).to eq(:created)
      expect(result.data).to have_attributes(url: "https://example.com/post", status: "processing")
    end
  end

  context "when the URL normalizes to an existing Article" do
    let(:url) { "https://EXAMPLE.com/post/?fbclid=1" }
    let!(:existing) { create(:article, user:, url: "https://example.com/post") }

    it "returns the existing Article and creates nothing", :aggregate_failures do
      expect { result }.not_to change(Article, :count)
      expect(result).to be_success
      expect(result.code).to eq(:duplicate)
      expect(result.data).to eq(existing)
    end
  end

  context "when a concurrent request saves the same URL first" do
    let(:url) { "https://example.com/race" }
    let!(:existing) { create(:article, user:, url: "https://example.com/race") }

    before do
      allow(user.articles).to receive(:find_by).and_return(nil, existing)
      allow_any_instance_of(Article).to receive(:save).and_raise(ActiveRecord::RecordNotUnique) # rubocop:disable RSpec/AnyInstance
    end

    it "rescues the unique violation and returns the existing Article", :aggregate_failures do
      expect(result).to be_success
      expect(result.code).to eq(:duplicate)
      expect(result.data).to eq(existing)
    end
  end

  context "with an invalid URL" do
    let(:url) { "ftp://example.com/a" }

    it "fails with the unsaved Article carrying errors", :aggregate_failures do
      expect { result }.not_to change(Article, :count)
      expect(result).to be_failure
      expect(result.code).to eq(:invalid)
      expect(result.data.errors[:url]).to include("must be a valid http or https URL")
    end
  end
end
