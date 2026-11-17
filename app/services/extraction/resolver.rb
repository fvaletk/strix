require "resolv"

class Extraction
  # host -> list of IP address strings. Injectable so specs can fake DNS.
  class Resolver
    def self.call(host) = Resolv.getaddresses(host)
  end
end
