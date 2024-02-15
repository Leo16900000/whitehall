module PublishingApi
  module PayloadBuilder
    class Routes
      attr_reader :base_path, :suffixes, :additional_paths

      def self.for(base_path, prefix: false, suffixes: [], additional_paths: [])
        new(base_path, prefix:, suffixes:, additional_paths:).call
      end

      def initialize(base_path, prefix: false, suffixes: [], additional_paths: [])
        @base_path = base_path
        @prefix = prefix
        @suffixes = suffixes
        @additional_paths = additional_paths
      end

      def call
        routes = []
        routes << { path: base_path, type: }
        suffixes.each do |suffix|
          routes << { path: "#{base_path}.#{suffix}", type: "exact" }
        end
        additional_paths.each do |additional_path|
          routes << { path: additional_path, type: "exact" }
        end
        { routes: }
      end

    private

      def type
        @prefix ? "prefix" : "exact"
      end
    end
  end
end
