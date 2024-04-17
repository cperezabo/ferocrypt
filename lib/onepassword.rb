class OnePasswordAccountsProvider
  def self.with_each_account
    # TODO: Get all the accounts without specifying a specific one
    accounts = [JSON.parse(`op item get "#{ARGV[1]}" --fields=username,password --format=json`)]
    accounts.each do |account|
      yield FerozoAccount.new(account[0]["value"], account[1]["value"])
    end
  end
end
