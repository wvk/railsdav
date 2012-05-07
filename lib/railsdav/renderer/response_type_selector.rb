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

      def format(name, options)
        if Mime::EXTENSION_LOOKUP[name.to_s]
          if @request_format.to_sym == name
            # TODO: somehow get the attributes (size, updated-at, ...) from the actual Mime responder block here
            @resource_options.merge! options
          end
        else
          raise UnknownMimeTypeExtension, "#{name} is not a valid MIME type file extension."
        end
      end

      # loop over all urls marked as subresources in webdav responder block
      # and add them with all their acceptable mime types
      def subresource(*subresources)
        return unless @request_format == :collection

        options = subresources.extract_options!
        subresources.each do |resource_url|
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
  end
end
