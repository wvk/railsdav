Gem::Specification.new do |s|
  s.name    = %q{railsdav}
  s.version = '0.0.8'
  s.date    = Time.now
  s.authors = ['Willem van Kerkhof']
  s.email   = %q{wvk@consolving.de}
  s.summary = %q{Make your Rails 3/4 resources accessible via WebDAV}
  s.homepage = %q{http://github.com/wvk/railsdav}
  s.description = %q{Provides basic Rails 3/Rails 4 extensions for making your business resources accessible via WebDAV. This gem does by no means by no means implement the full WebDAV semantics, but it suffices to access your app with client(-libs) such as Konqueror, cadaver, davfs2 or NetDrive}
  s.files = %w(README.md init.rb lib/railsdav.rb lib/railsdav/routing_extensions.rb lib/railsdav/request_extensions.rb lib/railsdav/renderer/response_collector.rb lib/railsdav/renderer/response_type_selector.rb lib/railsdav/controller_extensions.rb lib/railsdav/renderer.rb)
end
