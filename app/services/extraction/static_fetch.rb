require "ipaddr"
require "readability"

class Extraction
  # Plain HTTP GET + readability-style main-text extraction. No JavaScript.
  class StaticFetch
    MAX_REDIRECTS = 5
    REDIRECT_STATUSES = [ 301, 302, 303, 307, 308 ].freeze
    HTML_TYPES = %w[text/html application/xhtml+xml].freeze
    BLOCKED_RANGES = %w[0.0.0.0/8 ::/128].map { |range| IPAddr.new(range) }.freeze

    class Failure < StandardError
      attr_reader :code

      def initialize(message, code)
        super(message)
        @code = code
      end
    end

    def initialize(resolver:, config:)
      @resolver = resolver
      @min_words = config.fetch(:min_words)
      @timeout = config.fetch(:timeout_seconds)
    end

    def call(url)
      html = fetch(url)
      extract(html)
    rescue Failure => e
      Result.failure(e.message, code: e.code)
    rescue Faraday::TimeoutError
      Result.failure("timed out", code: :timeout)
    rescue Faraday::Error => e
      # Connect timeouts surface as ConnectionFailed wrapping a Timeout::Error.
      return Result.failure("timed out", code: :timeout) if e.cause.is_a?(Timeout::Error)

      Result.failure("connection failed", code: :connection_failed)
    end

    private

    def fetch(url)
      current = parse(url)
      (MAX_REDIRECTS + 1).times do |hop|
        assert_public!(current)
        response = get(current)
        return body_of(response) unless REDIRECT_STATUSES.include?(response.status)

        raise Failure.new("too many redirects", :too_many_redirects) if hop == MAX_REDIRECTS

        current = parse(next_location(current, response))
      end
    end

    def parse(url)
      uri = URI.parse(url.to_s)
      raise Failure.new("unsupported URL", :unsupported_url) unless uri.is_a?(URI::HTTP) && uri.host.present?

      uri
    rescue URI::InvalidURIError
      raise Failure.new("unsupported URL", :unsupported_url)
    end

    def next_location(current, response)
      location = response.headers["Location"]
      raise Failure.new("invalid redirect", :invalid_redirect) if location.blank?

      URI.join(current.to_s, location).to_s
    rescue URI::Error
      raise Failure.new("invalid redirect", :invalid_redirect)
    end

    # NOTE: DNS rebinding (the address changing between this check and the
    # request) is out of scope for the MVP.
    def assert_public!(uri)
      addresses = @resolver.call(uri.hostname)
      raise Failure.new("DNS lookup failed", :dns_error) if addresses.blank?
      raise Failure.new("blocked address", :blocked_address) if addresses.any? { |address| blocked?(address) }
    end

    def blocked?(address)
      ip = IPAddr.new(address)
      ip = ip.native if ip.ipv4_mapped?
      ip.private? || ip.loopback? || ip.link_local? || BLOCKED_RANGES.any? { |range| range.include?(ip) }
    rescue IPAddr::Error
      true
    end

    def get(uri)
      Faraday.new(request: { timeout: @timeout, open_timeout: @timeout }).get(uri.to_s)
    end

    def body_of(response)
      raise Failure.new("HTTP #{response.status}", :http_error) unless response.success?

      type = response.headers["Content-Type"].to_s.split(";").first.to_s.strip.downcase
      raise Failure.new("unsupported content type", :unsupported_content_type) unless HTML_TYPES.include?(type)

      response.body.to_s.dup.force_encoding(Encoding::UTF_8).scrub
    end

    def extract(html)
      document = Readability::Document.new(html)
      # Join text nodes with spaces: block elements in compact markup
      # (<p>a</p><p>b</p>) would otherwise fuse words together.
      text = Nokogiri::HTML(document.content).xpath("//text()").map(&:text).join(" ").gsub(/\s+/, " ").strip
      word_count = text.split.size
      return Result.failure("needs JavaScript", code: :needs_javascript) if word_count < @min_words

      Result.success({ title: title_for(html, document), text:, word_count: })
    end

    # Best title on the page: og:title (swapped for the full <h1> when it was
    # cut short with an ellipsis), then the single main-content <h1>, then <title>.
    def title_for(html, document)
      og_title = clean(Nokogiri::HTML(html).at_css('meta[property="og:title"]')&.[]("content"))
      return full_og_title(og_title, Nokogiri::HTML(html).css("h1")) if og_title

      # Readability's default output strips <h1> tags, so re-run it keeping them.
      content_h1s = Nokogiri::HTML(Readability::Document.new(html, tags: %w[div p h1]).content).css("h1")
      return clean(content_h1s.first.text) if content_h1s.size == 1 && clean(content_h1s.first.text)

      clean(document.title)
    end

    def full_og_title(og_title, h1s)
      return og_title unless og_title.end_with?("…", "...")

      prefix = og_title.sub(/(…|\.\.\.)\z/, "").strip
      h1s.map { |h1| clean(h1.text) }.compact.find { |text| text.start_with?(prefix) } || og_title
    end

    def clean(value)
      value.to_s.gsub(/\s+/, " ").strip.presence
    end
  end
end
