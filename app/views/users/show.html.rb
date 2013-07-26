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

require Rails.root.join('app', 'views', 'layouts', 'application.html.rb')

module Views
  module Users
    class Show < Views::Layouts::Application
      needs :user

      protected

      def body_content
        article(class: 'container') do
          page_header @user.name
          user_info
          user_form
        end
      end

      def active_tab() 'users' end

      private

      def user_info
        dl do
          dt "Email"
          dd @user.email

          dt "Signed Up"
          dd "#{l @user.created_at, format: :full} (#{time_ago_in_words @user.created_at} ago)"

          dt "Last Updated"
          dd "#{l @user.updated_at, format: :full} (#{time_ago_in_words @user.updated_at} ago)"

          dt "Number of logins"
          dd number_with_delimiter(@user.sign_in_count)

          dt "Number of failed logins"
          dd number_with_delimiter(@user.failed_attempts)

          dt "Locked because of too many failed logins?"
          dd do
            if @user.locked_at
              text "Yes, since #{time_ago_in_words @user.locked_at} ago (#{l @user.locked_at, format: :full})"
            else
              text "No"
            end
          end

          dt "Reset password token sent?"
          dd do
            if @user.reset_password_sent_at
              text "Yes, #{time_ago_in_words @user.reset_password_sent_at} ago (#{l @user.reset_password_sent_at, format: :full})"
            else
              text "No"
            end
          end

          dt "Currently signed in since"
          dd do
            if @user.current_sign_in_at
              text "#{l @user.current_sign_in_at, format: :full} (#{time_ago_in_words @user.current_sign_in_at} ago) from #{@user.current_sign_in_ip}"
            else
              text "never"
            end
          end

          dt "Last signed in at"
          dd do
            if @user.last_sign_in_at
              text "#{l @user.last_sign_in_at, format: :full} (#{time_ago_in_words @user.last_sign_in_at} ago) from #{@user.last_sign_in_ip}"
            else
              text "never"
            end
          end
        end
      end

      def user_form
        form_for(@user, html: {class: 'form-horizontal'}) do |f|
          div(class: 'control-group') do
            f.label :first_name, class: 'control-label'
            div(class: 'controls') do
              f.text_field :first_name
            end
          end
          div(class: 'control-group') do
            f.label :last_name, class: 'control-label'
            div(class: 'controls') do
              f.text_field :last_name
            end
          end
          div(class: 'control-group') do
            f.label :role, class: 'control-label'
            div(class: 'controls') do
              f.select :role, t('models.user.role').to_a.map(&:reverse), include_blank: true
            end
          end
          div(class: 'control-group') do
            f.label :approved_rfc5646_locales, class: 'control-label'
            div(class: 'controls') do
              f.content_tag_field 'div', :approved_rfc5646_locales, 'data-value' => @user.approved_rfc5646_locales.to_json
            end
          end
          div(class: 'control-group') do
            f.label :password, class: 'control-label'
            div(class: 'controls') do
              f.password_field :password, placeholder: 'password'
            end
            div(class: 'controls') do
              f.password_field :password_confirmation, placeholder: 'again'
            end
          end

          div(class: 'form-actions') do
            f.submit class: 'btn btn-primary'
            text ' '
            button "Delete",
                   class:         'btn btn-danger',
                   href:          user_url(@user),
                   'data-method'  => 'DELETE',
                   'data-confirm' => "Deleting an account cannot be undone."

            unless @user.admin? || @user == current_user
              button "Become This User",
                     class:        'btn btn-warning pull-right',
                     href:         become_user_url(@user),
                     'data-method' => 'POST'
            end
          end
        end

        p "If you want to deactivate an account, remove its role. Deleting an account removes historical translation data.", class: 'text-error'
      end
    end
  end
end
