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
        { base_path: }.merge(
          PayloadBuilder::Routes.for(base_path, prefix:, suffixes:),
        )
      end

    private

      def base_path
        @base_path ||= item.public_path(locale: I18n.locale)
      end
    end
  end
end
