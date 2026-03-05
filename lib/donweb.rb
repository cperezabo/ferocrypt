class DonWebAccountsProvider
  def self.with_each_account(&)
    new.with_each_account(&)
  end

  def initialize
    @connection = Faraday.new("https://administracion.donweb.com") { |f|
      f.response :json
      f.headers["Accept"] = "application/json"
      f.headers["Cookie"] = "sitio=#{donweb_phpsessid}"
    }
  end

  def with_each_account
    puts "Fetching accounts...".bold

    accounts_ids.filter_map { |id|
      phpsessid = phpsessid_for_account(id)

      unless phpsessid
        puts "#{'✗'.red.bold} Account #{id}: no PHPSESSID received"
        next
      end

      yield FerozoAccount.new(FerozoConnection.new(phpsessid))
    }
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
    response.body["jsonMC"]["respuesta"]["items"]
      .select { |item| item["estado"] == "ACTIVA" }
      .map { |item| item["id"] }
  end

  def phpsessid_for_account(id)
    response = Faraday.get(remotelogin_url_for_account(id))
    response.headers["set-cookie"]&.match(/PHPSESSID=([^;]+)/)&.[](1)
  end

  def remotelogin_url_for_account(id)
    response = @connection.get("/apiv3/servicios/hosting/#{id}/datosAcceso")
    response.body["jsonMC"]["respuesta"]["servidorURL"]
  end
end
