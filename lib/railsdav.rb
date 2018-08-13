# encoding: utf-8

require 'railsdav/routing_extensions'
require 'railsdav/controller_extensions'
require 'railsdav/request_extensions'
require 'railsdav/renderer'

module Railsdav
  class MissingWebDAVMetadata < StandardError; end

  WEBDAV_HTTP_VERBS = ActionDispatch::Request::RFC2518

  Mime::Type.register_alias 'application/xml', :webdav

  ActionController::Renderers.add :webdav do |response_type, options|
    renderer = Railsdav::Renderer.new(self)
    xml_str  = renderer.respond_with response_type, options

    Rails.logger.debug "WebDAV response:\n#{xml_str}"

    response.headers['Depth'] = renderer.depth.to_s
    response.headers['DAV']   = '1'

    send_data xml_str,
        :content_type => Mime[:xml],
        :status => :multi_status
  end

  ActionController::Base.send :include, Railsdav::ControllerExtensions
  ActionDispatch::Request.send :include, Railsdav::RequestExtensions

end # module Railsdav
