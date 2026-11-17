class CertificateCrafter
  PUBLICATION_TIMEOUT_SECONDS = 120

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

    begin
      @account.clear_acme_records
      @order = create_order
      @pending_authorizations = @order.authorizations.select { |authorization| authorization.status == "pending" }
      add_challenge_records
      unless challenge_records_published?
        puts "DNS records not published yet, run again later ⏳".yellow
        return
      end

      validate_challenges
      finalize
      @account.record_certification_in(@journal, expires_on: certificate_expiration)
      puts "Done 🚀".bold
    rescue RuntimeError => e
      puts e.message.red
    end
  end

  private

  def initialize(client, journal)
    @client = client
    @journal = journal
    @dns = AuthoritativeDns.new
  end

  def create_order
    identifiers = @account.domains.map { |domain| ["*.#{domain}", domain] }.flatten
    @client.new_order(identifiers:)
  end

  def add_challenge_records
    @pending_authorizations.each { |authorization| add_challenge_record_for(authorization) }
  end

  def challenge_records_published?
    deadline = Time.now + PUBLICATION_TIMEOUT_SECONDS
    until @pending_authorizations.all? { |authorization| challenge_record_published?(authorization) }
      return false if Time.now > deadline

      sleep 5
    end
    true
  end

  def challenge_record_published?(authorization)
    @dns.published?(challenge_record_name_of(authorization), authorization.dns.record_content, domain: authorization.domain)
  end

  def challenge_record_name_of(authorization)
    "#{authorization.dns.record_name}.#{authorization.domain}"
  end

  def add_challenge_record_for(authorization)
    record_name = challenge_record_name_of(authorization)
    record_content = authorization.dns.record_content

    puts "Adding DNS Record #{record_name} #{record_content.yellow.bold}"

    @account.add_dns_record(
      name: record_name,
      type: authorization.dns.record_type,
      content: record_content,
      domain: authorization.domain,
    )
  end

  def validate_challenges
    @pending_authorizations.each { |authorization| validate(authorization.dns) }
  end

  def validate(challenge)
    challenge.request_validation

    while challenge.status == "pending"
      sleep(2)
      challenge.reload
    end

    raise challenge.error["detail"] unless challenge.status == "valid"
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

    @certificate = @order.certificate

    puts "Installing...".bold
    @account.install_ssl(
      domain:,
      domain_alt: domain_names,
      private_key: private_key.to_pem,
      certificate: @certificate,
    )
  end

  def certificate_expiration
    OpenSSL::X509::Certificate.new(@certificate).not_after.to_date
  end

  def domain
    domain_names.last
  end

  def domain_names
    @order.identifiers.map { |item| item["value"] }
  end
end
