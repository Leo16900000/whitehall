module PublishingApi
  module PayloadBuilder
    class PolymorphicPath
      attr_reader :item, :prefix, :suffixes

      def self.for(item, prefix: false, suffixes: [])
        new(item, prefix:, suffixes:).call
      end

      def initialize(item, prefix: false, suffixes: [])
        @item = item
        @prefix = prefix
        @suffixes = suffixes
      end

      def call
        routes = PayloadBuilder::Routes.for(base_path, prefix:, suffixes:, additional_paths:)
        { base_path: }.merge(routes)
      end

    private

      def base_path
        @base_path ||= item.public_path(locale: I18n.locale)
      end

      def additional_paths
        return [] unless item.respond_to?(:multipart_content_paths)

        item.multipart_content_paths
      end
    end
  end
end
