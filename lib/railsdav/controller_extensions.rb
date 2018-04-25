# encoding: utf-8

module Railsdav
  module ControllerExtensions
    extend ActiveSupport::Concern

    # ruby 2+ compatibility
    module RespondWithWebdav
      # decorate behaviour defined in ActionController::MimeResponds
      def respond_to(*mimes, &block)
        if request.propfind?
          render :webdav => :propstat, :respond_to_block => block
        else
          super *mimes, &block
        end
      end

      # decorate behaviour defined in ActionController::MimeResponds
      def respond_with(*resources, &block)
        if request.propfind?
          render :webdav => :propstat, :respond_to_block => block
        else
          super *resources, &block
        end
      end

    end

    included do
      class_attribute :webdav_metadata

      if respond_to? :prepend # ruby >= 2.0
        prepend RespondWithWebdav
      elsif respond_to? :alias_method_chain # ruby < 2.0
        alias_method_chain :respond_to, :webdav
        alias_method_chain :respond_with, :webdav
      end
    end

    module ClassMethods
      def enable_webdav_for(*names_and_options, &block)
        options = names_and_options.extract_options!
        names   = names_and_options
        self.webdav_metadata ||= {}

        options[:collection] = true unless options.has_key?(:collection)

        names.each do |name|
          self.webdav_metadata = self.webdav_metadata.merge(name => options)
        end
      end

      def webdav_metadata_for_action(action)
        webdav_metadata[action.to_sym]
      end
    end

    # decorate behaviour defined in ActionController::MimeResponds
    def respond_to_with_webdav(*mimes, &block)
      if request.propfind?
        render :webdav => :propstat, :respond_to_block => block
      else
        respond_to_without_webdav *mimes, &block
      end
    end

    # decorate behaviour defined in ActionController::MimeResponds
    def respond_with_with_webdav(*resources, &block)
      if request.propfind?
        render :webdav => :propstat, :respond_to_block => block
      else
        respond_with_without_webdav *resources, &block
      end
    end

    def webdav_metadata_for_current_action
      self.class.webdav_metadata_for_action params[:action]
    end

  end
end
