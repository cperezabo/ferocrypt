class DonWebAccountsProvider
  def self.with_each_account(token_provider:, &)
    new(token_provider).with_each_account(&)
  end

  def initialize(token_provider)
    @connection = Faraday.new("https://administracion.donweb.com") { |f|
      f.response :json
      f.headers["Accept"] = "application/json"
      f.headers["Cookie"] = "sitio=#{token_provider.provide}"
    }
  end

  def with_each_account
    puts "Fetching accounts...".bold

    accounts_ids.each { |id|
      yield FerozoAccount.new(id, FerozoConnection.new(id, @connection))
    }
  end

  private

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
end
