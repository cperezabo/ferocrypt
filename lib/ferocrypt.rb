require "faraday"
require "acme-client"
require "json"
require "awesome_print"
require "openssl"
require "colorize"
require_relative "./onepassword"
require_relative "./ferozo"
require_relative "./crafter"

crafter = CertificateCrafter.register_with contact_email: ARGV[0]

OnePasswordAccountsProvider.with_each_account do |account|
  ferozo = Ferozo.connect_with account
  crafter.craft_in(ferozo)
end
