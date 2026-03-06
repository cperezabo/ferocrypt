require "faraday"
require "acme-client"
require "json"
require "awesome_print"
require "openssl"
require "colorize"
require_relative "donweb"
require_relative "ferozo"
require_relative "crafter"
require_relative "certification_journal"

crafter = CertificateCrafter.register_with(
  contact_email: ARGV[0],
  journal: CertificationJournal.new,
)

already_certified = 0

DonWebAccountsProvider.with_each_account { |account|
  already_certified += 1 if crafter.craft_in(account) == :already_certified
}

puts "#{already_certified} accounts already certified 🚀".bold if already_certified.positive?
