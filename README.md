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

Example
=======

TODO


Changelog
=========

0.0.1: Initial Release: Basic support for PROPFIND and webdav_resource(s) based routing

Copyright (c) 2012 Willem van Kerkhof <wvk@consolving.de>, released under the MIT license

