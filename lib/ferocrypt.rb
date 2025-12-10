require "faraday"
require "acme-client"
require "json"
require "awesome_print"
require "openssl"
require "colorize"
require_relative "donweb"
require_relative "ferozo"
require_relative "crafter"

crafter = CertificateCrafter.register_with contact_email: ARGV[0]

DonWebAccountsProvider.with_each_account { |account|
  crafter.craft_in(account)
}
