module TokenProviders
  module Env
    class Provider
      def provide
        ENV.fetch("DONWEB_TOKEN")
      end
    end
  end
end
