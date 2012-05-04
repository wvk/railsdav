module Railsdav
  autoload :ControllerExtensions, 'controller_extensions'
  autoload :RoutingExtensions, 'routing_extensions'
  autoload :Renderer, 'renderer'

  WEBDAV_HTTP_VERBS = %w(PROPFIND PROPPATCH MKCOL COPY MOVE LOCK UNLOCK).freeze

  def self.initialize!
    Mime::Type.register_alias 'application/xml', :webdav

    ActionController::Renderers.add :webdav do |response_type, options|
      options[:depth] = (request.headers['Depth'].to_i > 0) ? 1 : 0
      renderer = Railsdav::Renderer.new
      case response_type
      when :propstat
        str = renderer.propstat(self, options)
      when :response
        str = renderer.response(options)
      end

      Rails.logger.debug "Depth header is #{request.headers['Depth']}"
      Rails.logger.debug "PROPFIND response:\n#{str}"

      send_data str, :format => Mime::XML, :status => :multi_status, :depth => options[:depth]

      ActionController::Base.send :include, Railsdav::ControllerExtensions
    end
  end
end # module Railsdav
