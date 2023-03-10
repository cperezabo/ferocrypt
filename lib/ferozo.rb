FerozoAccount = Struct.new(:username, :password, :domains)

class Ferozo
  def self.connect_with(account)
    new(FerozoConnection.new(account.username, account.password))
  end

  def initialize(connection)
    @connection = connection
  end

  def domains
    response = @connection.get("/hosting/domain/listdomains")
    response.body["result"]
  end

  def install_ssl(domain:, domain_alt:, private_key:, certificate:)
    response = @connection.post(
      "/hosting/domain/installsslcrtkey",
      body: {
        "params": {
          "crt": certificate,
          "key": private_key,
          "domain": domain,
          "domainAlt": domain_alt.join(", "),
          "forcedhttps": 0,
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
        "params": {
          "id": "",
          "domain": domain,
          "name": name,
          "type": type,
          "content": content,
          "ttl": "14400",
          "prio": "0",
        },
      }
    )
  end

  def clear_acme_records(domain:)
    puts "Deleting old DNS records 🧹"
    delete_dns_records_named "_acme-challenge.#{domain}", domain: domain
  end

  private

  def delete_dns_records_named(name, domain:)
    records = dns_records_named(name, domain: domain)
    records.each { |record| delete_dns_record_identified_as(record["id"], domain: domain) }
    records
  end

  def dns_records(domain:)
    response = @connection.post(
      "/hosting/dns/zone/get",
      body: {
        "params": {
          "domain": domain,
        },
      }
    )

    response.body["result"]["Records"]
  end

  def dns_records_named(name, domain:)
    dns_records(domain: domain).select { |record| record["name"] == name }
  end

  def delete_dns_record_identified_as(id, domain:)
    @connection.post(
      "/hosting/dns/records/delete",
      body: {
        "params": {
          "id": id,
          "domain": domain,
        },
      }
    )
  end
end

class FerozoConnection
  def initialize(username, password)
    @username = username
    @password = password
  end

  def get(url)
    connection.get(url) do |req|
      req.headers["Accept"] = "application/json"
      req.headers["Cookie"] = "#{cookie}; locale=es"
      req.headers["CSRF-Token"] = csrf_token
    end
  end

  def post(url, body:)
    connection.post(url) do |req|
      req.headers["Accept"] = "application/json"
      req.headers["Cookie"] = "#{cookie}; locale=es"
      req.headers["CSRF-Token"] = csrf_token
      req.body = body.to_json
    end
  end

  private

  def connection
    @connection ||= Faraday.new("https://ferozo.host") do |f|
      f.response :json
    end
  end

  def csrf_token
    @csrf_token ||= begin
      response = connection.get("/common/security/csrf/token/get") do |req|
        req.headers["Accept"] = "application/json"
        req.headers["Cookie"] = "#{cookie}; locale=es"
      end
      response.body["result"]["token"]
    end
  end

  def cookie
    @cookie ||= begin
      response = connection.post("/login_check") do |req|
        req.body = URI.encode_www_form(_username: @username, _password: @password, locale: "es")
        req.headers["Content-Type"] = "application/x-www-form-urlencoded; charset=utf-8"
        req.headers["Content-Length"] = req.body.length.to_s
        req.headers["Cookie"] = "PHPSESSID=;"
      end
      response.headers["set-cookie"]
    end
  end
end
