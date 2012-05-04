
# Allow usage of WebDAV specific HTTP verbs
%w(propfind proppatch mkcol copy move lock unlock userinfo).each do |method|
  ActionDispatch::Request::HTTP_METHODS << method.upcase
  ActionDispatch::Request::HTTP_METHOD_LOOKUP[method.upcase] = method.to_sym
end

# Extend routing s.t. webdav_resource and webdav_resources can be used,
# enabling things like PROPFIND /foo/index.(:format) and such.
#
# ATTENTION: adapt this to newer rails version if upgrading the framework!
class ActionDispatch::Routing::Mapper
  module HttpHelpers
    def dav_propfind(*args, &block)
      map_method(:propfind, *args, &block)
    end

    def dav_options(*args, &block)
      map_method(:options, *args, &block)
    end

    def dav_copy(*args, &block)
      map_method(:copy, *args, &block)
    end

    def dav_move(*args, &block)
      map_method(:move, *args, &block)
    end
  end

  module Resources
    CANONICAL_ACTIONS << :update_all

    class WebDAVResource < Resource
      DEFAULT_ACTIONS = [:index, :create, :new, :show, :update, :destroy, :edit, :update_all]
    end

    class WebDAVSingletonResource < SingletonResource
      DEFAULT_ACTIONS = [:show, :create, :update, :destroy, :new, :edit]
    end

    def resource_scope?
      [:webdav_resource, :webdav_resources, :resource, :resources].include?(@scope[:scope_level])
    end

    def resource_scope(resource)
      case resource
      when WebDAVSingletonResource
        scope_level = :webdav_resource
      when WebDAVResource
        scope_level = :webdav_resources
      when SingletonResource
        scope_level = :resource
      when Resource
        scope_level = :resources
      end
      with_scope_level(scope_level, resource) do
        scope(parent_resource.resource_scope) do
          yield
        end
      end
    end

    def dav_options_response(*allowed_http_verbs)
      lambda { [200, {'Allow' => allowed_http_verbs.flatten.map{|s| s.to_s.upcase}.join(' '), 'DAV' => '1'}, ''] }
    end

    def dav_match(*args)
      get *args
      dav_propfind *args
    end

    def webdav_resource(*resources, &block)
      options = resources.extract_options!

      if apply_common_behavior_for(:webdav_resource, resources, options, &block)
        return self
      end

      resource_scope(WebDAVSingletonResource.new(resources.pop, options)) do
        yield if block_given?

        if parent_resource.actions.include?(:create)
          collection do
            post :create
          end
        end

        if parent_resource.actions.include?(:new)
          new do
            get :new
          end
        end

        member do
          if parent_resource.actions.include?(:show)
            dav_match :show
          end
          get    :edit    if parent_resource.actions.include?(:edit)
          put    :update  if parent_resource.actions.include?(:update)
          delete :destroy if parent_resource.actions.include?(:destroy)
        end
      end

      self
    end

    def webdav_resources(*resources, &block)
      options = resources.extract_options!

      if apply_common_behavior_for(:webdav_resources, resources, options, &block)
        return self
      end

      resource_scope(WebDAVResource.new(resources.pop, options)) do
        yield if block_given?

        opts = []
        collection do
          if parent_resource.actions.include?(:index)
            dav_match :index
            opts << [:get, :propfind]
          end

          if parent_resource.actions.include?(:create)
            post :create
            opts << :post
          end

          if parent_resource.actions.include?(:update_all)
            put :index, :action => :update_all
            opts << :put
          end
          dav_options :index, :to => dav_options_response(opts)
        end

        if parent_resource.actions.include?(:new)
          new do
            dav_match :new
            put :new, :action => :create
            dav_options :new, :to => dav_options_response(:get, :put, :propfind, :options)
          end
        end

        member do
          opts = []
          if parent_resource.actions.include?(:show)
            dav_match :show
            opts << :get
            opts << :propfind
          end

          if parent_resource.actions.include?(:update)
            put :update
            opts << :put
          end

          if parent_resource.actions.include?(:destroy)
            delete :destroy
            opts << :delete
          end

          dav_options :show, :to => dav_options_response(opts)

          if parent_resource.actions.include?(:edit)
            dav_match :edit
            dav_options :edit, :to => dav_options_response(:get, :propfind)
          end
        end
      end
      self
    end

  end
end
