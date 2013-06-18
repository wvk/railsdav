# encoding: utf-8

module Railsdav
  class Renderer
    class ResponseCollector
      attr_writer :controller

      delegate :subresources,
          :to => :@selector

      def initialize(controller, request_format)
        @controller, @request_format = controller, request_format
        @selector = ResponseTypeSelector.new(controller, request_format)
      end

      def resource
        @resource ||= Renderer::ResourceDescriptor.new(@controller.request.url, @selector.resource_options)
      end

      # responds to calls like html, xml, json by ignoring them
      def method_missing(name, *args)
        super unless Mime::EXTENSION_LOOKUP[name.to_s]
      end

      def webdav
        if block_given?
          yield @selector
        end
      end
    end
  end
end
