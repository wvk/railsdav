module Railsdav
  class Renderer

    class ResponseTypeSelector
      attr_reader :subresources, :resource_options

      def initialize(controller, request_format)
        @controller, @request_format = controller, request_format
        @subresources = []

        # TODO: somehow allow passing more options to current resource
        @resource_options = {:format => @request_format.to_sym}
      end

      # responds to calls like html, xml, json by ignoring them
      def method_missing(name, *args)
        if Mime::EXTENSION_LOOKUP[name.to_s]
          if @request_format.to_sym == name
            @resource_options = args.extract_options!
          end
        else
          super
        end
      end

      # loop over all urls marked as subresources in webdav responder block
      # and add them with all their acceptable mime types
      def collection(*subresources)
        return false unless @request_format == :collection

        subresources = subresources.first.is_a?(Hash) ? subresources.first : subresources
        subresources.each do |resource_url_and_options|
          if resource_url_and_options.is_a? String
            resource_url, options = resource_url_and_options, {}
          else
            options      = resource_url_and_options.extract_options!
            resource_url = resource_url_and_options.first
          end

          route = Rails.application.routes.recognize_path(resource_url)

          if meta = Renderer.webdav_metadata_for_url(route)
            # show the resource as a collection unless disabled
            if meta[:collection]
              @subresources << Renderer::ResourceDescriptor.new(resource_url, options.merge(:format => :collection))
            elsif meta[:accept].blank?
              # show the resource without .:format suffix, but not as a collection
              @subresources << Renderer::ResourceDescriptor.new(resource_url, options)
            end

            # show the resource with all the specified format suffixes
            if meta[:accept]
              [meta[:accept]].flatten.each do |type_name|
                mime_type = Mime::Type.lookup_by_extension(type_name)
                subresource_url = @controller.url_for(route.merge(:format => type_name))
                @subresources << Renderer::ResourceDescriptor.new(subresource_url, options.merge(:format => mime_type))
              end
            end
          else
            raise MissingWebDAVMetadata, "no WebDAV metadata found for #{resource_url}, please specify it using #enable_webdav_for"
          end
        end
        @resource_options[:size] = @subresources.size
      end

    end
    
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
