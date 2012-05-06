require 'builder'

module Railsdav
  class Renderer
    autoload :ResponseCollector,    'railsdav/renderer/response_collector'
    autoload :ResponseTypeSelector, 'railsdav/renderer/response_type_selector'

    ResourceDescriptor = Struct.new(:url, :props)

    class ResourceDescriptor
      def collection?
        self.props[:format] == :collection
      end
    end

    # Return the webdav metadata for a given URL/path
    #
    # If the given route is recognized, a controller and action can be identified.
    # To get the properties for that URI, we lookup the metadata
    # specified in the target controller (see #enable_webdav_for)
    #
    def self.webdav_metadata_for_url(routing_data)
      controller = "#{routing_data[:controller]}_controller".camelize.constantize
      controller ? controller.webdav_metadata_for_action(routing_data[:action]) : nil
    end

    attr_accessor :depth

    # Create a new Renderer instance that will render an XML multistatus response.
    # 
    # Arguments:
    #   controller: the current controller instance
    #
    def initialize(controller)
      @controller = controller
      @request    = controller.request
      @depth      = (@request.headers['Depth'].to_i > 0) ? 1 : 0 # depth "infinite" is not yet supported
    end

    # Render the requested response_type.
    #
    # Arguments:
    #   response_type: currently either :propstat or :response.
    #   options:
    #     - for response: :href, :status, :error (see #response)
    #     - for propstat: :size, :format, :created_at, :updated_at, :resource_layout, ... (see #propstat)
    def respond_with(response_type, options = {})
      self.send response_type, options
    end

    protected

    def request_format
      if @controller.params[:format].blank?
        if @controller.webdav_metadata_for_current_action[:collection]
          return :collection
        else
          return @controller.request_format
        end
      else
        return @controller.params[:format]
      end
    end

    def render
      @dav = Builder::XmlMarkup.new :indent => 2
      @dav.instruct!
      @dav.multistatus :xmlns => 'DAV:' do
        yield @dav
      end
      @dav.target!
    end

    # Render a WebDAV multistatus response with a single "response" element.
    # This is primarily intended vor responding to single resource errors.
    #
    # Arguments:
    #   options:
    #     - href: the requested resource URL, usually request.url
    #     - status: the response status, something like :unprocessable_entity or 204.
    #     - error: an Error description, if any.
    #
    def response(options = {})
      elements = options.slice(:error)

      render do
        response_for options[:href], options[:status] do |dav|
          elements.each do |name, value|
            dav.__send__ name, value
          end
        end
      end
    end

    # Render a WebDAV multistatus response with a "response" element per resource
    # TODO: explain the magic implemented here
    # Arguments:
    #    TODO: describe valid arguments
    #
    def propstat(options = {})
      response_collector = ResponseCollector.new(@controller, self.request_format)
      # retrieve properties for this resource and all subresources if this is a collection
      if options[:respond_to_block]
        options[:respond_to_block].call(response_collector)
      end

      render do |dav|
        propstat_for response_collector.resource
        propstat_for response_collector.subresources if @depth > 0
      end
    end

    private

    def propstat_for(*resources)
      params = @controller.params
      params[:propfind] ||= {:prop => []}
      requested_properties = params[:propfind][:prop]

      resources.flatten.each do |resource|
        hash = resource.props

        case hash[:updated_at]
        when Time, DateTime
          updated_at = hash[:updated_at]
        when String
          updated_at = Time.parse(hash[:updated_at])
        else
          updated_at = Time.now
        end

        response_hash = {
          :quota_used_bytes      => 0,
          :quota_available_bytes => 10.gigabytes,
          :creationdate          => updated_at.rfc2822,
          :getlastmodified       => updated_at.rfc2822,
          :getcontentlength      => hash[:size],
          :getcontenttype        => hash[:format].to_s,
          :executable            => 0
        }

        # TODO: implement 'allprop'
        # TODO: implement 'allprop' with 'include'

        if resource.collection?
          response_hash[:resourcetype]   = lambda { @dav.tag! :collection }
          response_hash[:getcontenttype] = nil
        end

        response_for(resource.url, hash[:status] || :ok) do |dav|
          dav.propstat do
            dav.prop do
              requested_properties.each do |prop_name, opts|
                if prop = response_hash[prop_name.to_sym]
                  if prop.respond_to? :call
                    if opts
                      dav.tag! prop_name, opts, &prop
                    else
                      dav.tag! prop_name, &prop
                    end
                  else
                    dav.tag! prop_name, prop, opts
                  end
                elsif opts
                  dav.tag! prop_name, opts
                else
                  dav.tag! prop_name
                end
              end # requested_properties.each
            end # dav.prop
          end # dav.propstat
        end # dav.response_for
      end # resource_layout.keys.each
    end # def propstat_for

    def response_for(href, status)
      code   = Rack::Utils.status_code(status)
      status = "HTTP/1.1 #{code} #{Rack::Utils::HTTP_STATUS_CODES[code]}"

      @dav.response do
        @dav.href href
        yield @dav
        @dav.status status
      end
    end

  end # class Railsdav
end # module Railsdav

