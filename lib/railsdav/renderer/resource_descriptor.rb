# encoding: utf-8

module Railsdav
  class Renderer
    class ResourceDescriptor
      attr_accessor :url, :props

      def initialize(url, props)
        @url, @props = url, props
      end

      def collection?
        self.props[:format] == :collection
      end

      def url
        @url += '/' if self.collection? and @url[-1] != '/'
        @url
      end
    end
  end
end

