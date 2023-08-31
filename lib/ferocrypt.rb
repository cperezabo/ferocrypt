require "faraday"
require "acme-client"
require "json"
require "awesome_print"
require "openssl"
require "colorize"
require_relative "./onepassword"
require_relative "./ferozo"
require_relative "./crafter"

accounts_provider = OnePasswordAccountsProvider.new
crafter = CertificateCrafter.register_with contact_email: ARGV[0]

accounts_provider.accounts.each do |account|
  ferozo = Ferozo.connect_with account

  account.domains.each do |domain|
    puts "Updating certificate for #{domain.bold} 🧹"

    ferozo.clear_acme_records(domain:)

    certificate = crafter.craft(domain) do |challenge|
      challenge.add_dns_record_to ferozo
    end

    certificate.install_on ferozo

    puts "Done 🚀".bold
  end
end
