RailsDAV
========

Make your Rails 3 resources accessible via WebDAV

ProvidesThis gem provides basic Rails 3 extensions for making your business resources accessible via WebDAV. This gem does by no means by no means implement the full WebDAV semantics, but it suffices to access your app with client(-libs) such as Konqueror, cadaver, davfs2 or NetDrive.

Compatibility
=============

Currently only works with Rails 3.0.9!
This is due to some hacking done "under the hood" in the Rails routing implementation as well as a simple method override in ActionController.

Support for newer Rails versions is planned, so stay tuned!

Installation
============

With Rails 3.0.9, just at the following to your Gemfile

    gem 'railsdav', :git => 'https://github.com/wvk/railsdav.git'

and then run

    bundle install

put the following into an initializer (e.g. config/initializers/webdav.rb)

    Railsdav.initialize!

This will, among other setup wirings, register a 'webdav' Mime Type named as an alias for 'application/xml', which will be discussed later.

Usage
=====

TODO: Context

Tell your controller which actions should be abailable as WebDAV resources, what media types should be advertised and whether or not they should be also available as collection resources (i.e. "folders"):

    class FoosController < ApplicationController
      enable_webdav_for :index,
          :accept => :json

      enable_webdav_for :show,
          :accept     => [:xml, :json],
          :collection => false

      # ...

This stores some metadata about your actions that can be accessed from another controller, in case this one acts as a subresource of another resource. You may provide an arpitrary list of media types ("formats") with the :accept options. This causes RailsDAV to advertise that resource as separate files, one for each provided media type.
By default, RailsDAV also advertises each resource as a collection ("folder"), containing a resource's subresources. You may choose not to let it do so by setting the :collection option to false (nil won't do, it really must be /false/).

As for the actions themselves they, too, need some attention. Collection resources usually contain subresources (otherwise, why bother?) that are specified in the format.webdav responder block:

      # ...

      def index
        @foos = Foo.limit(100)
        respond_to do |format|
          format.html
          format.json   { render :json => @foos }
          format.webdav { @foos.map{|foo| foo_path(@foo) } }
        end
      end

      # ...

This may seem a little awkward and hacky, but it is really the most shorthand thing to do: What really happens inside that responder block when a PROPFIND request hits the resource is an XML builder template being rendered with all the needed information taken from the paths you specify within the block and the metada stored in the target controllers (see above: enable_webdav_for).

If you define a webdav responder block, the minimum it should contain is an Array with path names of subresources. So in the above example, when a PROPFIND request hits the index action, a multi-status response is rendered with the foos collection containting up to 100 foo entries as separate XML and JSON files:

    PROPFIND /foos

will return a directory layout similar to:

    /foos
      -> /foos/1.xml
      -> /foos/1.json
      -> /foos/2.xml
      -> /foos/2.json
      ...

The show action looks similar, but here things get a little more brain twisty.

TODO: explain options to respond_to
TODO: explain why respond_to is always needed
TODO: explain difference bettween PROPFIND /foos/1 and PROPFIND /foos/1.:format

      def show
        @foo = Foo.find(params[:id])
        respond_to(:updated_at => @foo.updated_at) do |format|
          format.html
          format.json { render :json => @foo }
          format.xml  { render :xml  => @foo }
          # no webdav responder needed, since no subresources are present
        end
      end
    end

Routing:

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



Authentication
==============

RailsDAV does not do any authentication whatsoever, nor is there any sugar to go nicely with $your_favourite_authentication_gem. However, since cookie/session based authentication does not like to be friends with WebDAV, it's up to you to ensure Basic or Digest Authentication is used when a Request from a WebDAV client comes in.

Assuming you have an Application where resources are normally accessed as text/html but never so for WebDAV, a simple means of providing access control using HTTP Basic might look as follows:

    class ApplicationController < ActionController::Base
      before_filter :authenticate_unless_session

      protected

      def authenticate_unless_session
        # Always use Basic Authentication if the request method is one of WebDAV's
        if is_webdav_request
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

Changelog
=========

0.0.1: Initial Release: Basic support for PROPFIND and webdav_resource(s) based routing

Copyright (c) 2012 Willem van Kerkhof <wvk@consolving.de>, released under the MIT license

