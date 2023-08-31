class SSLCertificate
  def initialize(domain:, domain_alt:, private_key:, certificate:)
    @domain = domain
    @domain_alt = domain_alt
    @private_key = private_key
    @certificate = certificate
  end

  def install_on(provider)
    puts "Installing...".bold
    provider.install_ssl(
      domain: @domain,
      domain_alt: @domain_alt,
      private_key: @private_key,
      certificate: @certificate,
    )
  end
end

class DnsChallenge
  def initialize(domain, challenge)
    @domain = domain
    @record_name = "#{challenge.record_name}.#{domain}"
    @record_type = challenge.record_type
    @record_content = challenge.record_content
  end

  def add_dns_record_to(provider)
    puts "Adding DNS Record #{@record_name.bold} #{@record_content.yellow.bold}"
    provider.add_dns_record(
      name: @record_name,
      type: @record_type,
      content: @record_content,
      domain: @domain,
    )
  end
end

class CertificateCrafter
  def self.register_with(contact_email:)
    client = Acme::Client.new(
      private_key: OpenSSL::PKey::RSA.new(File.read("./private.pem")),
      directory: "https://acme-v02.api.letsencrypt.org/directory"
    )
    # account = client.new_account(contact: "mailto:#{contact_email}", terms_of_service_agreed: true)

    new client
  end

  def initialize(client)
    @client = client
  end

  def craft(domain, &block)
    puts "Crafting certificate ✨"

    begin
      attempts ||= 5
      @order = @client.new_order(identifiers: ["*.#{domain}", domain])
      authorize(&block)
      finalize
    rescue RuntimeError
      attempts -= 1
      raise unless attempts.positive?

      puts "Retrying...".red
      retry
    end
  end

  private

  def authorize(&block)
    @order.authorizations.each do |authorization|
      puts "Resolving DNS Challenge..."

      challenge = authorization.dns

      block.call DnsChallenge.new(domain, challenge)

      sleep(5)
      challenge.request_validation

      while challenge.status == "pending"
        sleep(2)
        challenge.reload
      end

      raise "Challenge failed with: #{challenge.error['detail']}" unless challenge.status == "valid"
    end
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

    SSLCertificate.new(
      domain: domain_names.last,
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
