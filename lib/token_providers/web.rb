require "ferrum"
require "net/http"

module TokenProviders
  module Web
    class Provider
      def provide
        Browser.open("https://micuenta.donweb.com/es-ar/dashboard") { |browser|
          wait_for_user_confirmation
          fetch_cookie_from(browser)
        }
      end

      private

      def fetch_cookie_from(browser)
        cookie = browser.cookies["sitio"]
        abort "Cookie 'sitio' not found." unless cookie

        cookie.value
      end

      def wait_for_user_confirmation
        puts "Log in to the browser. Press Enter when done..."
        $stdin.gets
      end
    end

    class Browser
      DEBUG_PORT = 9222
      DEBUG_URL = "http://localhost:#{DEBUG_PORT}".freeze

      def self.open(url, &)
        new(url).open(&)
      end

      def open(&block)
        @pid = spawn(chromium_path, "--remote-debugging-port=#{DEBUG_PORT}", @url, pgroup: true, err: "/dev/null")
        abort "Could not connect to browser" unless ready?

        block.call Ferrum::Browser.new(url: DEBUG_URL)
      ensure
        shutdown
      end

      private

      def initialize(url)
        @url = url
      end

      def chromium_path
        ENV.fetch("CHROMIUM_PATH")
      end

      def ready?
        print "Waiting for browser to start..."
        10.times.any? {
          sleep 0.5
          print "."
          begin
            Net::HTTP.get(URI("#{DEBUG_URL}/json/version")) && true
          rescue StandardError
            false
          end
        }.tap { puts }
      end

      def shutdown
        Process.kill("-TERM", Process.getpgid(@pid)) if @pid
      rescue StandardError
        nil
      end
    end
  end
end
