require "resolv"
require "socket"
require "io/wait"

class AuthoritativeDns
  REPLY_TIMEOUT_SECONDS = 5

  def published?(name, content, domain:)
    nameservers = delegated_nameservers_of(domain)

    nameservers.any? && nameservers.all? { |nameserver| txt_records_at(name, nameserver).include?(content) }
  end

  private

  # The nameservers the parent zone delegates to are the ones Let's Encrypt asks, and they
  # may differ from the domain's own NS records (wenoa.studio lists Ferozo's, but is delegated to DonWeb's).
  def delegated_nameservers_of(domain)
    parent = domain.split(".", 2).last
    parent_nameserver = Resolv::DNS.open { |dns| dns.getresources(parent, Resolv::DNS::Resource::IN::NS).first.name.to_s }

    reply = ask(ipv4_address_of(parent_nameserver), query_for(domain, Resolv::DNS::Resource::IN::NS))
    reply.authority.filter_map { |_name, _ttl, record| record.name.to_s if record.is_a?(Resolv::DNS::Resource::IN::NS) }.uniq
  end

  def txt_records_at(name, nameserver)
    reply = ask(ipv4_address_of(nameserver), query_for(name, Resolv::DNS::Resource::IN::TXT))
    reply.answer.filter_map { |_name, _ttl, record| record.data if record.is_a?(Resolv::DNS::Resource::IN::TXT) }
  end

  # Without recursion, as Let's Encrypt's resolvers do: Ferozo's nameservers
  # may answer recursive queries with a stale NXDOMAIN.
  def query_for(name, type)
    query = Resolv::DNS::Message.new
    query.rd = 0
    query.add_question(name, type)
    query
  end

  def ask(address, query)
    socket = UDPSocket.new
    socket.send(query.encode, 0, address, 53)
    return Resolv::DNS::Message.new unless socket.wait_readable(REPLY_TIMEOUT_SECONDS)

    Resolv::DNS::Message.decode(socket.recvfrom(4096).first)
  ensure
    socket&.close
  end

  def ipv4_address_of(nameserver)
    Resolv::DNS.open { |dns| dns.getresource(nameserver, Resolv::DNS::Resource::IN::A).address.to_s }
  end
end
