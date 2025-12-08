class DonWebAccountsProvider
  def self.with_each_account(&)
    new.with_each_account(&)
  end

  def initialize
    @connection = Faraday.new("https://administracion.donweb.com") do |f|
      f.response :json
      f.headers["Accept"] = "application/json"
      f.headers["Cookie"] = "sitio=#{donweb_phpsessid}"
    end
  end

  def with_each_account
    puts "Fetching accounts...".bold

    accounts_ids.map do |id|
      response = @connection.get("/apiv3/servicios/hosting/#{id}/datosAcceso")
      remotelogin_url = response.body["jsonMC"]["respuesta"]["servidorURL"]
      response = @connection.get(remotelogin_url) do |r|
        r.headers["Accept"] = "text/html"
      end
      phpsessid = response.headers["set-cookie"].match(/PHPSESSID=([^;]+)/)[1]

      yield FerozoAccount.new(FerozoConnection.new(phpsessid))
    end
  end

  private

  def donweb_phpsessid
    `op item get "DonWeb" --format=json | jq -r '.fields[]? | select(.label=="PHPSESSID") | .value'`
  end

  def reseller_id
    response = @connection.get("/apiv3/servicios/hosting/revendedor")
    json_response = response.body["jsonMC"]

    if json_response["error"]
      error_msg = json_response["error"]
      puts "\n#{'✗'.red.bold} Authentication error: #{error_msg}"
      puts "#{'Hint:'.yellow.bold} Update the PHPSESSID field in 1Password with the 'sitio' cookie value"
      exit 1
    end

    json_response["respuesta"]["items"].first["servicioID"]
  end

  def accounts_ids
    response = @connection.get("/apiv3/servicios/hosting/revendedor/cuentas/#{reseller_id}?registrosPorPagina=9999999")
    response.body["jsonMC"]["respuesta"]["items"].map { |item| item["id"] }
  end
end
