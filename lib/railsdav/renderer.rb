require 'builder'

module Railsdav
  class Renderer
    def propstat(controller, options = {})
      resource_layout = options[:resource_layout]
      class << resource_layout
        attr_accessor :controller

        Mime::EXTENSION_LOOKUP.each do |name, type|
          unless name == 'webdav'
            define_method(name) {|*args| }
          end
        end

        def webdav
          return false unless block_given?
          additional_paths = yield
          # loop over all urls marked as subresources in webdav responder block
          # and add them with all their acceptable mime types
          additional_paths.each do |path_or_structure|
            if path_or_structure.is_a? Array
              path, options = *path_or_structure
            else
              path, options = path_or_structure, {}
            end
            route  = Picos::Application.routes.recognize_path(path)
            layout = "#{route[:controller]}_controller".camelize.constantize.webdav_layout

            # If the route is recognized, a controller and action can be identified.
            # To get the properties for that URI, we lookup the metadata
            # specified in the target controller using #enable_webdav_for
            if layout and meta = layout[route[:action].to_sym]
              # show the resource as a collection unless explicitely disabled
              if meta[:collection] != false
                self.merge!(path => options.merge(:format => :collection))
              elsif meta[:accept].blank?
                # show the resource without .:format suffix, but not as a collection
                self.merge! path => options
              end

              # show the resource with the specified format suffixes
              if meta[:accept]
                [meta[:accept]].flatten.each do |type_name|
                  self.merge! controller.url_for(route.merge(:format => type_name)) => options.merge(:format => type_name)
                end
              end
            else
              raise "no  metadata found for #{route.inspect}"
            end
          end
        end
      end

      params = controller.params
      # retrieve properties from subresources if the Depth-header is > 0
      if options[:responder] and params[:format].blank? and options[:depth] > 0
        resource_layout.controller = controller
        options[:responder].call(resource_layout)
      end

      render do |dav|
        resource_layout.keys.sort.each do |resource_url|
          hash = resource_layout[resource_url]

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
            :getcontenttype        => Mime::Type.lookup_by_extension(hash[:format].to_s).to_s
          }

          if hash[:format] == :collection
            response_hash[:resourcetype] = lambda { dav.collection }
          end

          dav.response do
            dav.href resource_url
            dav.propstat do
              dav.prop do
                params[:propfind] ||= {:prop => []}
                params[:propfind][:prop].each do |prop_name, opts|
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
                end
              end
              dav.status(options[:response] || 'HTTP/1.1 200 OK')
            end
          end
        end
      end
    end

    def response(options = {})
      elements = options.slice(:href, :status, :error)
      code = Rack::Utils.status_code(elements[:status])
      elements[:status] = "HTTP/1.1 #{code} #{Rack::Utils::HTTP_STATUS_CODES[code]}"

      render do |dav|
        dav.response do
          elements.each do |name, value|
            dav.__send__ name, value
          end
        end
      end
    end

    def render
      dav = Builder::XmlMarkup.new(:indent => 2)
      dav.instruct!
      dav.multistatus :xmlns => 'DAV:' do
        yield dav
      end
      dav.target!
    end

  end
end

