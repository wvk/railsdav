module Railsdav
  module ControllerExtensions
    extend ActiveSupport::Concern
  
    included do
      class_attribute :webdav_layout
    end

    module ClassMethods
      def enable_webdav_for(*names_and_options, &block)
        options = names_and_options.extract_options!

        self.webdav_layout ||= {}
        names_and_options.each do |name|
          self.webdav_layout[name] = options
        end
      end
    end

    module InstanceMethods
      protected
      def respond_to(options = {}, &block)
        if 'PROPFIND' == request.method
          response.headers['DAV'] = '1'
          if options[:collection] == false and params[:format].blank?
            this_action = {}
          else
            this_action = {request.env['REQUEST_URI'] => options.merge(:format => params[:format] ? params[:format] : :collection)}
          end
          render :webdav => :propstat, :resource_layout => this_action, :responder => block
        else
          super &block
        end
      end

    end
  end
end
