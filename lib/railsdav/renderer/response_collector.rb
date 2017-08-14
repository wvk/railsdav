# encoding: utf-8

require "uri"

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

        request_path = URI(@controller.request.url).path
        @resource ||= Renderer::ResourceDescriptor.new(request_path, @selector.resource_options)
      end

      # responds to calls like html, xml, json by ignoring them
      def method_missing(name, *args)
        super unless Mime::EXTENSION_LOOKUP[name.to_s] or name == :any
      end

      def webdav
        if block_given?
          yield @selector
        end
      end
    end
  end
end
