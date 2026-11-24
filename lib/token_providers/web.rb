require "ferrum"
require "net/http"

module TokenProviders
  module Web
    class Provider
      DASHBOARD_URL = "https://micuenta.donweb.com/es-ar/dashboard".freeze
      DASHBOARD_PAGE = %r{\Ahttps://micuenta\.donweb\.com/[a-z]{2}-[a-z]{2}/dashboard}
      SESSION_COOKIE = "sitio".freeze

      def provide
        Browser.open { |browser|
          browser.forget_cookie(SESSION_COOKIE)
          browser.visit(DASHBOARD_URL)
          wait_for_dashboard_in(browser)
        }
      end

      private

      # DonWeb sets the session cookie on its login page too, before anyone logs in;
      # only reaching the dashboard with it means the session is active.
      def wait_for_dashboard_in(a_browser)
        puts "Log in to the browser. It will continue on its own once you're logged in..."
        sleep 1 until a_browser.showing?(DASHBOARD_PAGE) && a_browser.cookie?(SESSION_COOKIE)
        a_browser.cookie(SESSION_COOKIE)
      rescue Ferrum::Error
        abort "Browser closed before logging in."
      end
    end

    class Browser
      DEBUG_PORT = 9222
      DEBUG_URL = "http://localhost:#{DEBUG_PORT}".freeze
      PROFILE_DIR = File.expand_path("../../.browser_profile", __dir__).freeze

      def self.open(&)
        new.open(&)
      end

      def open
        @pid = spawn(chromium_path, "--remote-debugging-port=#{DEBUG_PORT}", "--user-data-dir=#{PROFILE_DIR}", pgroup: true, err: "/dev/null")
        abort "Could not connect to browser" unless ready?

        @devtools = Ferrum::Browser.new(url: DEBUG_URL)
        yield self
      ensure
        shutdown
      end

      def forget_cookie(a_name)
        cookies_named(a_name).each { |cookie|
          @devtools.command("Storage.setCookies", cookies: [expired(cookie)])
        }
      end

      def visit(a_url)
        @devtools.command("Target.createTarget", url: a_url)
      end

      def showing?(a_page)
        @devtools
          .command("Target.getTargets")["targetInfos"]
          .any? { |target| target["type"] == "page" && a_page.match?(target["url"]) }
      end

      def cookie?(a_name)
        cookies_named(a_name).any?
      end

      def cookie(a_name)
        cookies_named(a_name).first["value"]
      end

      private

      def cookies_named(a_name)
        @devtools
          .command("Storage.getCookies")["cookies"]
          .select { |cookie| cookie["name"] == a_name }
      end

      def expired(a_cookie)
        a_cookie
          .slice("name", "domain", "path")
          .merge("value" => "", "expires" => 1)
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
