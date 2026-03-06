require_relative "token_providers/env"
require_relative "token_providers/web"

module TokenProviders
  def self.fetch(name)
    const_get(name)::Provider.new
  end
end
