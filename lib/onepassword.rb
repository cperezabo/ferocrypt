class OnePasswordAccountsProvider
  def accounts
    # TODO: Get all the accounts without specifying a specific one
    accounts = [JSON.parse(`op item get "#{ARGV[1]}" --fields=username,password,domains --format=json`)]
    accounts.map(&method(:map_account_from_hash))
  end

  private

  def map_account_from_hash(account)
    username = account[0]["value"]
    password = account[1]["value"]
    domains = account[2]["value"].split(",").map(&:strip)
    FerozoAccount.new username, password, domains
  end
end
