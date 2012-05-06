module Railsdav
  module RequestExtensions

    def self.included(base)
      base.class_eval do
        Railsdav::WEBDAV_HTTP_VERBS.each do |verb|
          method_name = "#{verb.underscore}?"

          # just to make sure we don't accidentally break things...
          raise "#{method_name} is already defined in #{self.class}!" if respond_to? method_name

          define_method method_name do
            ActionDispatch::Request::HTTP_METHOD_LOOKUP[request_method] == verb.underscore.to_sym
          end
        end
      end
    end

    def webdav?
      Railsdav::WEBDAV_HTTP_VERBS.include? request_method
    end

  end # module RequestExtensions
end # module Railsdav
