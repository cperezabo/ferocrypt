require "date"

class CertificationJournal
  RENEWAL_WINDOW_DAYS = 15

  def initialize(path = "journal.txt")
    @path = path
  end

  def certified?(account_id)
    expiration = expirations_of(account_id).max
    !expiration.nil? && expiration - Date.today > RENEWAL_WINDOW_DAYS
  end

  def record(account_id, domains_description, expires_on:)
    File.open(@path, "a") { |f| f.write("#{account_id} #{expires_on.iso8601} # #{domains_description}\n") }
  end

  private

  def expirations_of(account_id)
    entries.filter_map { |entry|
      id, date = entry.split(" # ").first.split
      Date.iso8601(date) if id == account_id.to_s && date
    }
  end

  def entries
    return [] unless File.exist?(@path)

    File.readlines(@path)
  end
end
