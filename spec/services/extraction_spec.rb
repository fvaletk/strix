require "rails_helper"
# Behavior-level service spec: examples assert outcome + side effects together.
# rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength, RSpec/MultipleMemoizedHelpers

RSpec.describe Extraction do
  subject(:result) { described_class.call(article, resolver:) }

  let(:article) { create(:article, url: "https://example.com/post") }
  let(:public_ip) { "93.184.216.34" }
  let(:resolver) { ->(_host) { [ public_ip ] } }
  let(:article_html) { file_fixture("extraction/article.html").read }
  let(:html_headers) { { "Content-Type" => "text/html; charset=utf-8" } }

  def stub_page(url, body: article_html, status: 200, headers: html_headers)
    stub_request(:get, url).to_return(status:, body:, headers:)
  end

  context "with a normal article page" do
    before { stub_page("https://example.com/post") }

    it "succeeds and saves title, text and word_count without touching status" do
      expect(result).to be_success
      article.reload
      expect(article.title).to eq("A Normal Article")
      expect(article.text).to include("Paragraph 1")
      expect(article.word_count).to eq(article.text.split.size)
      expect(article.word_count).to be >= 200
      expect(article).to be_processing
    end
  end

  context "with compact markup that has no whitespace between blocks" do
    let(:compact_html) do
      paragraphs = Array.new(25) { |i| "<p>Paragraph #{i} has some words to fill the page okay.</p>" }.join
      "<html><head><title>Compact</title></head><body><article>#{paragraphs}</article></body></html>"
    end

    before { stub_page("https://example.com/post", body: compact_html) }

    it "keeps words from adjacent blocks separate and counts them correctly" do
      expect(result).to be_success
      article.reload
      expect(article.word_count).to eq(250)
      expect(article.text).to include("okay. Paragraph 1")
      expect(article.text).not_to include("okay.Paragraph")
    end
  end

  context "with a near-empty JavaScript shell" do
    before { stub_page("https://example.com/post", body: file_fixture("extraction/js_shell.html").read) }

    it "fails with needs JavaScript and leaves the article untouched" do
      expect(result).to be_failure
      expect(result.error).to eq("needs JavaScript")
      expect(article.reload.text).to be_nil
    end
  end

  context "with a non-HTML response" do
    before { stub_page("https://example.com/post", body: "%PDF-1.4", headers: { "Content-Type" => "application/pdf" }) }

    it "fails with unsupported content type" do
      expect(result.error).to eq("unsupported content type")
    end
  end

  context "with HTTP errors" do
    it "reports 404" do
      stub_page("https://example.com/post", status: 404, body: "nope")
      expect(result.error).to eq("HTTP 404")
    end

    it "reports 500" do
      stub_page("https://example.com/post", status: 500, body: "boom")
      expect(result.error).to eq("HTTP 500")
    end
  end

  context "when the request times out" do
    before { stub_request(:get, "https://example.com/post").to_timeout }

    it "fails with timed out" do
      expect(result.error).to eq("timed out")
    end
  end

  context "when DNS does not resolve" do
    let(:resolver) { ->(_host) { [] } }

    it "fails with a DNS reason" do
      expect(result.error).to eq("DNS lookup failed")
    end
  end

  context "with redirects" do
    it "follows a chain to the final page" do
      stub_request(:get, "https://example.com/post").to_return(status: 301, headers: { "Location" => "/a" })
      stub_request(:get, "https://example.com/a").to_return(status: 302, headers: { "Location" => "https://other.example.org/b" })
      stub_page("https://other.example.org/b")

      expect(result).to be_success
      expect(article.reload.title).to eq("A Normal Article")
    end

    it "fails on the 6th redirect" do
      (0..5).each do |i|
        path = i.zero? ? "post" : "r#{i}"
        stub_request(:get, "https://example.com/#{path}").to_return(status: 307, headers: { "Location" => "/r#{i + 1}" })
      end

      expect(result.error).to eq("too many redirects")
    end

    it "follows exactly 5 redirects" do
      stub_request(:get, "https://example.com/post").to_return(status: 308, headers: { "Location" => "/r1" })
      (1..4).each { |i| stub_request(:get, "https://example.com/r#{i}").to_return(status: 303, headers: { "Location" => "/r#{i + 1}" }) }
      stub_page("https://example.com/r5")

      expect(result).to be_success
    end

    it "refuses a redirect to a private host without fetching it" do
      resolver = ->(host) { host == "internal.example.org" ? [ "10.0.0.5" ] : [ public_ip ] }
      stub_request(:get, "https://example.com/post").to_return(status: 302, headers: { "Location" => "http://internal.example.org/secret" })
      private_stub = stub_request(:get, "http://internal.example.org/secret")

      result = described_class.call(article, resolver:)

      expect(result.error).to eq("blocked address")
      expect(private_stub).not_to have_been_requested
    end

    it "fails when a redirect has no Location" do
      stub_request(:get, "https://example.com/post").to_return(status: 302)
      expect(result).to be_failure
    end
  end

  describe "address rules" do
    {
      "localhost" => "127.0.0.1",
      "a 10.x address" => "10.1.2.3",
      "the metadata address" => "169.254.169.254",
      "IPv6 loopback" => "::1",
      "IPv6 unique-local" => "fd00::1",
      "unspecified" => "0.0.0.0",
      "a private address among public ones" => "192.168.1.1"
    }.each do |label, ip|
      it "blocks #{label}" do
        resolver = ->(_host) { [ public_ip, ip ] }
        request = stub_request(:get, "https://example.com/post")

        result = described_class.call(article, resolver:)

        expect(result.error).to eq("blocked address")
        expect(request).not_to have_been_requested
      end
    end

    it "only fetches http and https URLs" do
      article.update_column(:url, "ftp://example.com/file")
      expect(result).to be_failure
      expect(result.error).to eq("unsupported URL")
    end
  end

  context "with several strategies" do
    let(:first) { instance_double(Extraction::StaticFetch) }
    let(:second) { instance_double(Extraction::StaticFetch) }
    let(:strategies) { [ class_double(Extraction::StaticFetch, new: first), class_double(Extraction::StaticFetch, new: second) ] }

    it "stops at the first success" do
      allow(first).to receive(:call).and_return(Result.success({ title: "T", text: "words here", word_count: 2 }))

      result = described_class.call(article, strategies:)

      expect(result).to be_success
      expect(article.reload.title).to eq("T")
    end

    it "falls through and carries the last strategy's reason" do
      allow(first).to receive(:call).and_return(Result.failure("needs JavaScript"))
      allow(second).to receive(:call).and_return(Result.failure("timed out"))

      expect(described_class.call(article, strategies:).error).to eq("timed out")
    end
  end
end
# rubocop:enable RSpec/MultipleExpectations, RSpec/ExampleLength, RSpec/MultipleMemoizedHelpers
