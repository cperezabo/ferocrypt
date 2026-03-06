class CertificateCrafter
  def self.register_with(contact_email:, journal:)
    client = Acme::Client.new(
      private_key: OpenSSL::PKey::RSA.new(File.read("./private.pem")),
      directory: "https://acme-v02.api.letsencrypt.org/directory"
    )
    client.new_account(contact: "mailto:#{contact_email}", terms_of_service_agreed: true)
    new client, journal
  end

  def craft_in(account)
    @account = account

    return :already_certified if @account.certified_according_to?(@journal)

    puts "Crafting certificate for #{@account} ✨"
    @account.clear_acme_records

    begin
      @order = create_order
      authorize
      finalize
      @account.record_certification_in(@journal)
      puts "Done 🚀".bold
    rescue RuntimeError => e
      puts e.message.red
    end
  end

  private

  def initialize(client, journal)
    @client = client
    @journal = journal
  end

  def create_order
    identifiers = @account.domains.map { |domain| ["*.#{domain}", domain] }.flatten
    @client.new_order(identifiers:)
  end

  def authorize
    @order.authorizations.each { |authorization|
      challenge = authorization.dns
      record_name = "#{challenge.record_name}.#{authorization.domain}"
      record_content = challenge.record_content

      puts "Adding and validating DNS Record #{record_name} #{record_content.yellow.bold}"

      @account.add_dns_record(
        name: record_name,
        type: challenge.record_type,
        content: record_content,
        domain: authorization.domain,
      )

      challenge.request_validation

      while challenge.status == "pending"
        sleep(2)
        challenge.reload
      end

      raise challenge.error["detail"] unless challenge.status == "valid"
    }
  end

  def finalize
    private_key = OpenSSL::PKey::RSA.new(4096)
    csr = Acme::Client::CertificateRequest.new(
      private_key:,
      subject: { common_name: domain },
      names: domain_names
    )

    @order.finalize(csr:)

    while @order.status == "processing"
      sleep(1)
      @order.reload
    end

    puts "Installing...".bold
    @account.install_ssl(
      domain:,
      domain_alt: domain_names,
      private_key: private_key.to_pem,
      certificate: @order.certificate,
    )
  end

  def domain
    domain_names.last
  end

  def domain_names
    @order.identifiers.map { |item| item["value"] }
  end
end
