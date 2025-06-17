class FerozoAccount
  def initialize(connection)
    @connection = connection
  end

  def domains
    @domains ||= begin
      result = @connection.get("/hosting/domain/listdomains").body["result"]
      all_domains = result.map { |record| record["domain"] }
      all_domains.reject { |domain| domain.end_with? "ferozo.com" }
    end
  end

  def domains_as_text
    domains.join(", ")
  end

  def install_ssl(domain:, domain_alt:, private_key:, certificate:)
    response = @connection.post(
      "/hosting/domain/installsslcrtkey",
      body: {
        params: {
          crt: certificate,
          key: private_key,
          domain:,
          domainAlt: domain_alt.join(", "),
          forcedhttps: 0,
        },
      }
    )

    raise response.body["error"]["message"] if response.body.key?("error")

    response
  end

  def add_dns_record(name:, type:, content:, domain:)
    @connection.post(
      "/hosting/dns/records/add",
      body: {
        params: {
          id: "",
          domain:,
          name:,
          type:,
          content:,
          ttl: "14400",
          prio: "0",
        },
      }
    )
  end

  def clear_acme_records
    puts "Deleting old DNS records 🧹"
    domains.each do |domain|
      records = dns_records_named("_acme-challenge.#{domain}", domain:)
      records.each { |record| delete_dns_record_identified_as(record["id"], domain:) }
    end
  end

  private

  def dns_records(domain:)
    response = @connection.post(
      "/hosting/dns/zone/get",
      body: {
        params: {
          domain:,
        },
      }
    )

    response.body["result"]["Records"]
  end

  def dns_records_named(name, domain:)
    dns_records(domain:).select { |record| record["name"] == name }
  end

  def delete_dns_record_identified_as(id, domain:)
    @connection.post(
      "/hosting/dns/records/delete",
      body: {
        params: {
          id:,
          domain:,
        },
      }
    )
  end
end

class FerozoConnection
  def initialize(phpsessid)
    @phpsessid = phpsessid
  end

  def get(url)
    connection.get(url) do |req|
      req.headers["CSRF-Token"] = csrf_token
    end
  end

  def post(url, body:)
    connection.post(url) do |req|
      req.headers["CSRF-Token"] = csrf_token
      req.body = body.to_json
    end
  end

  private

  def connection
    @connection ||= Faraday.new("https://ferozo.host") do |f|
      f.response :json
      f.headers["Accept"] = "application/json"
      f.headers["Cookie"] = cookie
    end
  end

  def csrf_token
    @csrf_token ||= begin
      response = connection.get("/common/security/csrf/token/get")
      response.body["result"]["token"]
    end
  end

  def cookie
    @cookie ||= "PHPSESSID=#{@phpsessid}; isDhm=0; locale=es"
  end
end
