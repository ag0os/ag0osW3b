require "ipaddr"

class ClientAddress
  LOOPBACK = [ IPAddr.new("127.0.0.0/8"), IPAddr.new("::1") ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    env.delete("HTTP_FORWARDED")
    env.delete("HTTP_CLIENT_IP")
    env.delete("HTTP_X_FORWARDED_FOR") unless local_peer?(env["REMOTE_ADDR"])
    @app.call(env)
  end

  private
    def local_peer?(address)
      peer = IPAddr.new(address.to_s)
      LOOPBACK.any? { |range| range.include?(peer) }
    rescue IPAddr::InvalidAddressError
      false
    end
end
