# encoding: utf-8

require 'builder'

if Rails.version > '4.0'
  require 'active_support'
  require 'active_support/core_ext/hash/conversions'
end


module Railsdav
  class Renderer
    autoload :ResourceDescriptor,   'railsdav/renderer/resource_descriptor'
    autoload :ResponseCollector,    'railsdav/renderer/response_collector'
    autoload :ResponseTypeSelector, 'railsdav/renderer/response_type_selector'

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
#       @depth      = (@request.headers['Depth'].to_i > 0) ? 1 : 0 # depth "infinite" is not yet supported
      @depth      = (@request.headers['Depth'].to_i)
      Rails.logger.debug "Depth:#{@request.headers['Depth']}"
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
      @dav.tag!("D:multistatus", "xmlns:D" => 'DAV:') do
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
        response_for options[:href] do |dav|
          elements.each do |name, value|
            status_for options[:status]
            dav.__send__ name, value
          end
        end
      end
    end

    def status_for(status)
      code   = Rack::Utils.status_code(status || :ok)
      status = "HTTP/1.1 #{code} #{Rack::Utils::HTTP_STATUS_CODES[code]}"
      @dav.tag! "D:status", status
    end

    # Allows you to `render :webdav => :not_found` and get a 404
    # status properly embedded inside multi-status
    def not_found(options = {})
      render do |dav|
        status_for 404
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
        propstat_for response_collector.subresources if @depth >= 0
      end
    end

    private

    def propstat_for(*resources)
      params = @controller.params.dup
      if params[:propfind]
        # OK
      elsif @controller.request.body.size > 0 # rails version without automatic XML body params parsing, so do it by hand here:
        @controller.request.body.rewind
        params.merge! Hash.from_xml(@controller.request.body.read)
      else
        params[:propfind] ||= {:prop => []}
      end

      if params[:propfind].has_key? 'allprop'
        requested_properties = nil # fill it later, see below.
      else
        requested_properties = params[:propfind][:prop]
      end

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

        # note: all of these are assumed to be from the DAV:
        # namespace!
        response_hash = {
          :quota_used_bytes      => 0,
          :quota_available_bytes => 10.gigabytes,
          :creationdate          => updated_at.iso8601,
          :getlastmodified       => updated_at.rfc2822,
          :getcontentlength      => hash[:size],
          :getcontenttype        => hash[:format].to_s
        }

        if resource.collection?
          response_hash[:resourcetype]   = proc { @dav.tag! "D:collection" } # must be block to render <collection></collection> instead of "collection"
          response_hash[:getcontenttype] = nil
        end

        requested_properties ||= response_hash.keys

        # as a workaround for another bug in Flycode's WebDAV module,
        # which expects (because of how it does element name matching)
        # that the properties are always returned with a specified
        # namespace prefix.  Now, the original Railsdav makes a
        # slightly careless assumption of its own; it just directly
        # matches element names in its fixed list, counting on (and
        # there are none so far) collisions between property names
        # from various name spaces.  As such, it just assumes that if
        # the property name is discrimated by a namespace, the client
        # has only done so by putting a non-prefixed `xmlns` attribute
        # on the propfind properties (ie., it did not try to use a
        # prefix itself).  Railsdav really should track and match
        # properties by both name *and* namespace, in order to be
        # properly compliant.

        # So, back to the Flycode WebDAV bug: we work around this here
        # by collecting all of the requested properties, gathering the
        # namespaces from them, and defining them *all* as prefixes.

        # all of our built-in properties are in the DAV namespace
        # anyway:
        gathered_namespaces = {}
        @namespace_counter ||= 1

        namespaced_requested_properties = {}

        Rails.logger.debug requested_properties.inspect
        requested_properties.each do |prop_name, opts|
          if prop_name.to_s.include?(":")
            # see first paragraph of big comment above
            Rails.logger.warn("DAV propfind prop request contains a namespace prefix; we do NOT handle these properly yet!")
          end

          if (!opts.nil?) and opts["xmlns"]
            gathered_namespaces["xmlns:lp#{@namespace_counter}"] = opts["xmlns"]
            opts.delete("xmlns")
            namespaced_requested_properties["lp#{@namespace_counter}:#{prop_name}"] = opts
            @namespace_counter +=1
          else
            # just copy it through; however, we'll assume it's in the
            # DAV namespace (which we hardcoded to the `D` prefix).
            namespaced_requested_properties["D:#{prop_name}"] = opts
          end
        end

        response_for(resource.url) do |dav|
          dav.tag! "D:propstat", gathered_namespaces do
            status_for hash[:status]
            dav.tag! "D:prop" do
              namespaced_requested_properties.each do |both_prop_name, opts|
                prop_space_and_name_pair = both_prop_name.split(":")
                prop_name = prop_space_and_name_pair[1] || prop_space_and_name_pair[0]
                if prop_val = response_hash[prop_name.to_sym]
                  if prop_val.respond_to? :call
                    if opts
                      dav.tag! both_prop_name, opts, &prop_val
                    else
                      dav.tag! both_prop_name, &prop_val
                    end
                  else
                    dav.tag! both_prop_name, prop_val, opts
                  end
                elsif opts
                  dav.tag! both_prop_name, opts
                else
                  dav.tag! both_prop_name
                end
              end # requested_properties.each
            end # dav.prop
          end # dav.propstat
        end # dav.response_for
      end # resource_layout.keys.each
    end # def propstat_for

    def response_for(href)
      @dav.tag! "D:response" do
        @dav.tag! "D:href", href
        yield @dav
      end
    end

  end # class Railsdav
end # module Railsdav

