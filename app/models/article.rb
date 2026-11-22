class Article < ApplicationRecord
  TRACKING_PARAMS = /\A(utm_.*|fbclid|gclid)\z/i

  belongs_to :user
  has_many :article_tags, dependent: :destroy
  has_many :tags, through: :article_tags

  enum :status, { processing: 0, ready: 1, failed: 2 }

  before_validation :normalize_url

  validates :url, presence: true, uniqueness: { scope: :user_id }
  validate :url_must_be_http

  # Returns the normalized URL string, or the stripped input when unparseable.
  def self.normalize_url(raw)
    stripped = raw.to_s.strip
    uri = URI.parse(stripped)
    return stripped unless uri.is_a?(URI::HTTP) && uri.host.present?

    uri.scheme = uri.scheme.downcase
    uri.host = uri.host.downcase
    uri.fragment = nil
    if uri.query
      kept = URI.decode_www_form(uri.query).reject { |key, _| key.match?(TRACKING_PARAMS) }
      uri.query = kept.empty? ? nil : URI.encode_www_form(kept)
    end
    uri.path = uri.path.chomp("/")
    uri.to_s
  rescue URI::InvalidURIError
    stripped
  end

  private

  def normalize_url
    self.url = self.class.normalize_url(url) if url.present?
  end

  def url_must_be_http
    return if url.blank?

    uri = URI.parse(url)
    errors.add(:url, "must be a valid http or https URL") unless uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    errors.add(:url, "must be a valid http or https URL")
  end
end
