class CertificationJournal
  def initialize(path = "journal.txt")
    @path = path
  end

  def certified?(account_id)
    entries.any? { |entry| entry.start_with?("#{account_id} ") }
  end

  def record(account_id, domains_description)
    File.open(@path, "a") { |f| f.write("#{account_id} # #{domains_description}\n") }
  end

  private

  def entries
    return [] unless File.exist?(@path)

    File.readlines(@path)
  end
end
