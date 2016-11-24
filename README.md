# RailsDAV

Make your Rails 3/4 resources accessible via WebDAV.

This gem provides basic Rails 3/4 extensions for making your business
resources accessible via WebDAV. This gem does by no means by no means
implement the full WebDAV semantics, but it suffices to access your
app with client(-libs) such as Konqueror, cadaver, davfs2 or NetDrive.

## Compatibility

Definitely works with Rails 3.0.9, 3.2.13 and 4.2.4, but should also work
with versions in between.  This is due to some hacking done "under the
hood" in the Rails routing implementation as well as a simple method
override in ActionController.

If you encounter any problems with other Rails versions, please feel
free to report an issue or send me a pull request on github.

## Installation

Ensure that your project has the
[Rails ActionPack XML Params Parser gem](https://github.com/rails/actionpack-xml_parser)
installed, and then just add the following to your Gemfile:

    gem 'railsdav'

and then run:

    bundle install

## Usage

TODO: Context

### Controller

#### Doing the Set-Up

Tell your controller which actions should be available as WebDAV resources, what media types should be advertised and whether or not they should be also available as collection resources (i.e. "folders"):

    class FoosController < ApplicationController
      enable_webdav_for :index,
          :accept => :json

      enable_webdav_for :show,
          :accept     => [:xml, :json],
          :collection => false

      # ...

This stores some metadata about your actions that can be accessed from another controller, in case this one acts as a subresource of another resource. You may provide an arbitrary list of media types ("formats") with the :accept options. This causes RailsDAV to advertise that resource as separate files, one for each provided media type.
By default, RailsDAV also advertises each resource as a collection ("folder"), containing a resource's subresources. You may choose not to let it do so by setting the :collection option to false (nil won't do, it really must be /false/).

# Handling PROPFIND Requests

As for the actions themselves they, too, need some attention. Collection resources usually contain subresources (otherwise, why bother?) that are specified in the format.webdav responder block:

      # ...

      def index
        @foos = Foo.limit(100)
        respond_to do |format|
          # you already know this...
          format.html
          format.xml  { render :json => @foos }
          format.json { render :xml  => @foos }

          # and this one is new...
          format.webdav do |dav|
            @foos.each |foo|
              dav.subresource foo_path(foo)
            end
            dav.format :xml,  :size => @foos.to_json.size, :updated_at => @foos.maximum(:updated_at)
            dav.format :json, :size => @foos.to_xml.size, :updated_at => @foos.maximum(:updated_at)
          end
        end
      end

      # ...

The webdav responder block is called when a PROPFIND request comes in. Within the block, we define a metadata set for each possible mime type that will be served via WebDAV. If the index resource is accessed as a collection (PROPFIND /foos), a multi-status response is rendered with the foos collection containting up to 100 foo entries as separate XML and JSON files:

    PROPFIND /foos

will return a directory layout similar to:

    /foos
      -> /foos/1.xml
      -> /foos/1.json
      -> /foos/2.xml
      -> /foos/2.json
      ...

If the index resource is accessed as XML (PROPFIND /foos.xml) or JSON (PROPFIND /foos.json), size and last-update of the XML/JSON "file" are included in the response. You can include that metatdata for each subresource, too:

          format.webdav do |dav|
            @foos.each do |foo|
              dav.subresource foo_path(foo), :updated_at => foo.updated_at
            end
          end

the "dav.format" statements are entirely optional if you do not wish to include any metadata such as updated-at, created-at, or size. There's no need to be redundant here, since you already specified the most important metadata with "enable_webdav_for".

The show action looks similar.

      def show
        @foo = Foo.find(params[:id])
        respond_to do |format|
          format.html
          format.json { render :json => @foo }
          format.xml  { render :xml  => @foo }

          format.webdav do |dav|
            dav.format :xml,  :size => @foo.to_xml.size,  :updated_at => @foo.updated_at
            dav.format :json, :size => @foo.to_json.size, :updated_at => @foo.updated_at
          end
        end
      end

TODO: explain why respond_to is always needed

TODO: explain difference between PROPFIND /foos/1 and PROPFIND /foos/1.:format and medadata defined on class level and in responder block

### Routing

To make the rails routing mechanism webdav aware, RailsDAV extends it by means of some new DSL methods. Let's take the above example again and what the default routing would look like:

    MyAwesomeApp::Application.routes.draw do
      resources :foos
    end

In order to accept PROPFIND and other WebDAV requests, you'll have to change it to look rather this way:

    MyAwesomeApp::Application.routes.draw do
      webdav_resources :foos
    end

Easy enough. As you may have guessed, there exists also a "webdav_resource" counterpart for singleton resources and some more. By the way: the above also produces a route for OPTIONS requests that matches the capabilities of the resource. In case you only want the show and update action to be present, the following would also adapt the OPTIONS responder to only contain PROPFIND, GET and PUT:

      webdav_resource :bar,
          :only => %w(show update)

To enable propfind for a single action somewhere, use:
      dav_propfind '/my-foo', :to => 'my_foos#show'

the other available helpers are: dav_copy, dav_move, dav_mkcol, dav_lock, dav_unlock, dav_proppatch.

### Authentication

RailsDAV does not do any authentication whatsoever, nor is there any sugar to go nicely with $your_favourite_authentication_gem. However, since cookie/session based authentication does not like to be friends with WebDAV, it's up to you to ensure Basic or Digest Authentication is used when a request from a WebDAV client comes in.

Assuming you have an application where resources are normally accessed as text/html but never so for WebDAV, a simple means of providing access control using HTTP Basic might look like this:

    class ApplicationController < ActionController::Base
      before_filter :authenticate_unless_session

      protected

      def authenticate_unless_session
        # Always use Basic Authentication if the request method is one of WebDAV's
        if is_webdav_request?
          basic_auth
        elsif request.format == Mime::HTML
          # skip Basic Authentication and use anoher way
        else
          basic_auth # or whatever...
        end
      end

      def basic_auth
        session = authenticate_with_http_basic {|usr, pwd| Session.new :login => usr, :password => pwd }
        if session and session.valid?
          @current_user = session.user
        else
          request_http_basic_authentication 'My Awesome App'
        end
      end
    end

is_webdav_request? checks whether an Incoming request is issued by a WebDAV client using any specific HTTP verbs (such as PROPFIND, MKCOL, COPY, MOVE, etc.) or a media type other than text/html is requested.

## Changelog

* 0.1.0: Rails 4.2 compatibility
* 0.0.9: Add missing file to gemspec
* 0.0.8: Merge Contributions from naserca, orospakr, and rutgerg
* 0.0.7: Fix metadata class attribute inheritance problem
* 0.0.6: Fix update_all for Rails 3.2
* 0.0.5: Rails 3.2.x compatibility, add encoding hints, fix ResourceDescriptor load error
* 0.0.4: Basic support for allprop in PROPFIND
* 0.0.3: Change the API within the responder block to a more concise one
* 0.0.2: More or less a complete rewrite: Use more sensible API, modularize the renderer code, get rid of controller monkey patching
* 0.0.1: Initial Release: Basic support for PROPFIND and webdav_resource(s) based routing

Copyright (c) 2012 Willem van Kerkhof <wvk@consolving.de>, released under the MIT license

