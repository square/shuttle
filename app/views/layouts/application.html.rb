# encoding: utf-8

# Copyright 2013 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

module Views
  module Layouts
    class Application < Erector::Widget
      # include helpers here for access to erector methods
      include ApplicationHelper
      include DeviseHelper
      include ShuttleDeviseHelper

      def content
        rawtext "<!DOCTYPE html>"
        html(lang: 'en') do
          head_portion
          body_portion
        end
      end

      protected

      # Override this method with your web page content.
      def body_content
        raise NotImplementedError
      end

      # Override this method to customize the title tag.
      def page_title() nil end

      # Override this method to associate your page with a tab from the
      # navigation bar.
      def active_tab() end

      ### HELPERS

      # Like link_to, but makes a button.
      def button_to(name, location, overrides={})
        button name, overrides.reverse_merge(href: location, type: 'button')
      end

      # Sticks the content in a page-header block. Typically used for the page
      # title.
      def page_header(title=nil, &block)
        if block_given?
          div({class: 'page-header'}, &block)
        elsif title
          div(class: 'page-header') { h1 title }
        else
          raise ArgumentError, "Must specify title or block"
        end
      end

      private

      def head_portion
        metas
        page_title ?
            title("Shuttle | #{page_title}") :
            title("Shuttle: Magic localization dust")

        stylesheet_link_tag 'application'
        inline_css
        comment('[if lt IE 9]') { javascript_include_tag 'http://html5shim.googlecode.com/svn/trunk/html5.js' }
      end

      def metas
        meta charset: 'utf-8'
        meta name: 'description', content: "A tool for automatically detecting and managing a project’s localizable strings."
        meta name: 'author', content: "Square, Inc."
        meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
        csrf_meta_tags
      end

      def body_portion
        body(class: controller_name, id: [controller_name, action_name].join('-')) do
          navbar

          div(class: 'container', id: 'flashes') { flashes }
          body_content

          javascript_include_tag 'application'
          inline_javascript
        end
      end

      def navbar
        div(class: 'navbar navbar-fixed-top') do
          div(class: 'navbar-inner') do
            div(class: 'container') do
              a(class: 'btn btn-navbar', :'data-toggle' => 'collapse', :'data-target' => '.nav-collapse') do
                span class: 'icon-bar'
                span class: 'icon-bar'
                span class: 'icon-bar'
              end
              div(class: 'brand') do
                a "Shuttle", href: root_url
              end
              div(class: 'nav-collapse') do
                if current_user
                  ul(class: 'nav') do
                    tab "Search", 'search', search_url
                  end

                  div(class: 'nav pull-right worker-status') do
                    if current_user.admin?
                      a "…", href: '/sidekiq'
                    else
                      a "…"
                    end
                  end

                  ul(class: 'nav pull-right') do
                    #tab "Settings", 'account', account_url
                    tab "Projects", 'projects', projects_url if current_user.monitor?
                    tab "Glossary", 'glossary', glossary_url if current_user.translator?
                    tab "Users", 'users', users_url if current_user.admin?
                    tab "Log Out", 'logout', destroy_user_session_url, :'data-method' => 'delete'
                  end
                else
                  ul(class: 'nav pull-right') do
                    tab "Log In", 'login', new_user_session_url
                  end
                end
              end
            end
          end
        end
      end

      def tab(name, id, url, options={})
        li(class: (active_tab == id ? 'active' : nil)) do
          link_to name, url, options
        end
      end

      def flashes
        flash_bar :alert, 'alert-error'
        flash_bar :warning
        flash_bar :success, 'alert-success'
        flash_bar :notice, 'alert-info'
      end

      def flash_bar(level, styling='')
        if flash[level].present? then
          div(class: "alert #{styling}".strip) do
            a "×", class: 'close', :'data-dismiss' => 'alert'
            p flash[level]
          end
        end
      end

      def inline_javascript
        file = Rails.root.join('app', self.class.to_s.underscore + '.js')
        script(raw(File.read(file)), type: 'text/javascript') if File.exist?(file)

        file = Rails.root.join('app', self.class.to_s.underscore + '.js.coffee')
        script(raw(CoffeeScript.compile(File.read(file))), type: 'text/javascript') if File.exist?(file)

        file = Rails.root.join('app', self.class.to_s.underscore + '.js.erb')
        script(raw(ERB.new(File.read(file)).result(binding)), type: 'text/javascript') if File.exist?(file)

        file = Rails.root.join('app', self.class.to_s.underscore + '.js.coffee.erb')
        script(raw(CoffeeScript.compile(ERB.new(File.read(file)).result(binding))), type: 'text/javascript') if File.exist?(file)
      end

      def inline_css
        file = Rails.root.join('app', self.class.to_s.underscore + '.css')
        style(raw(File.read(file)), type: 'text/css') if File.exist?(file)

        filename = Rails.root.join('app', self.class.to_s.underscore + '.css.scss')
        if File.exist?(filename)
          file = File.read(filename)
          compiled_css = Sass.compile(file, style: :compressed, syntax: :scss, filename: filename)
          style(compiled_css, type: 'text/css')
        end

        filename = Rails.root.join('app', self.class.to_s.underscore + '.css.sass')
        if File.exist?(filename)
          file         = File.read(filename)
          compiled_css = Sass.compile(file, style: :compressed, syntax: :sass, filename: filename)
          style(compiled_css, type: 'text/css')
        end

        file = Rails.root.join('app', self.class.to_s.underscore + '.css.erb')
        style(raw(ERB.new(File.read(file)).result(binding)), type: 'text/css') if File.exist?(file)
      end
    end
  end
end
