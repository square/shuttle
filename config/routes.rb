# Copyright 2014 Square Inc.
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

Shuttle::Application.routes.draw do
  # Redirect request with not matching hosts or protocol to a default url.
  # For example, `http://shuttle.server1.example.com` would redirect to `https://shuttle.example.com`
  # if the default url provided in the configs were `https://shuttle.example.com`.
  if !Rails.env.development?
    full_root_url = lambda { |opts| opts.fetch(:protocol, 'http') + '://' + opts.host + (opts.key?(:port) ? ':' + opts.port.to_s : '')}.call(Shuttle::Configuration.app.default_url_options)
    constraints(lambda { |req| !req.url.start_with?(full_root_url) }) do
      match '*glob' => redirect(full_root_url), via: [:get, :post, :put, :patch, :delete]
    end
  end

  # AUTHENTICATION
  devise_for :users, controllers: {
      registrations: 'registrations'
  }

  # API
  namespace :api do
    namespace :v1 do
      resources :projects, only: [] do
        resources :articles, param: :name, only: [:index, :new, :create, :show, :edit, :update] do
          member do
            patch :hide_in_dashboard, :show_in_dashboard
            get :manifest, :issues
          end
        end
      end
    end
  end

  # IN-CONTEXT TRANSLATION
  constraints(key_id: /[^\s]+/) do
    get '/projects/:project_id/commits/:commit_id/keys/:key_id/translations/:id' => 'incontext/translations#show', as: :incontext_translation
    get '/projects/:project_id/commits/:commit_id/keys/:key_id/translations/:id/edit' => 'incontext/translations#edit', as: :edit_incontext_translation
  end

  # REST
  resources :projects do
    resources :commits, only: [:show, :create, :update, :destroy] do
      member do
        post :sync, :recalculate, :ping_stash
        get :manifest, :localize, :search, :tools, :gallery, :issues
      end

      resources :keys, only: [:index, :show], controller: 'commit/keys'
      resources :screenshots, only: [:create] do
        collection do
          post :request, action: :request_screenshots
        end
      end
    end

    resources :keys, only: [] do
      resources :translations, only: [:show, :new, :create, :edit, :update] do
        member do
          patch :hide_in_search, :show_in_search
          get :match, :fuzzy_match
        end
      end

      resources :translations, only: [] do
        resources :issues, only: [:create, :update] do
          member do
            patch :resolve
            patch :subscribe
            patch :unsubscribe
          end
        end
      end
    end

    member do
      post 'github-pull-request-builder' => 'projects#github_webhook'
      post 'stash-pull-request-builder' => 'projects#stash_webhook'
      get  'mass-copy-translations' => 'projects#setup_mass_copy_translations', as: :setup_mass_copy_translations
      post 'mass-copy-translations' => 'projects#mass_copy_translations', as: :mass_copy_translations
      get 'tmx' => 'projects#tmx'
    end
  end

  resources :issues, only: [] do
    resources :comments, only: [:create]
  end

  resources :locales, only: :index do
    collection { get :countries }
    resources :projects, only: [:index, :show], controller: 'locale/projects' do
      resources :translations, controller: 'locale/translations', only: :index
    end
    resources :glossary_entries, only: [:index, :create, :update, :destroy]
  end

  resources :users, only: [:index, :show, :update, :destroy] do
    collection { get :search }
    member { post :become }
  end

  resources :locale_associations, except: :show

  get 'substitute' => 'substitution#convert'

  # SEARCH PAGES
  get 'search' => redirect('/search/translations')
  get 'search/translations' => 'search#translations', as: :search_translations
  get 'search/keys' => 'search#keys', as: :search_keys
  get 'search/commits' => 'search#commits', as: :search_commits
  get 'search/issues' => 'search#issues', as: :search_issues

  # STATS PAGES
  get 'stats' => 'stats#index'
  get 'stats/translation-report' => 'stats#translation_report', as: :stats_translation_report
  post 'stats/generate-translation-report' => 'stats#generate_translation_report', as: :stats_generate_translation_report, format: :csv
  get 'stats/project-translation-report' => 'stats#project_translation_report', as: :stats_project_translation_report
  post 'stats/generate-project-translation-report' => 'stats#generate_project_translation_report', as: :stats_generate_project_translation_report, format: :csv
  get 'stats/incoming-new-words-report' => 'stats#incoming_new_words_report', as: :stats_incoming_new_words_report
  post 'stats/generate-incoming-new-words-report' => 'stats#generate_incoming_new_words_report', as: :stats_generate_incoming_new_words_report, format: :csv
  get 'stats/translator-report' => 'stats#translator_report', as: :stats_translator_report
  post 'stats/generate-translator-report' => 'stats#generate_translator_report', as: :stats_generate_translator_report, format: :csv
  get 'stats/backlog-report' => 'stats#backlog_report', as: :stats_backlog_report
  post 'stats/generate-backlog-report' => 'stats#generate_backlog_report', as: :stats_generate_backlog_report, format: :csv

  # GLOSSARY PAGES
  get 'glossary' => 'glossary#index', as: :glossary
  namespace 'glossary' do
    resources :sources, only: [:index, :create, :edit, :update, :destroy], controller: 'source_glossary_entries' do
      resources :locales, only: [:create, :edit, :update], controller: 'locale_glossary_entries' do
        member { patch :approve, :reject }
      end
    end
  end

  # HOME PAGES
  get 'administrators' => 'home#administrators', as: :administrators
  get 'translators' => 'home#translators', as: :translators
  get 'reviewers' => 'home#reviewers', as: :reviewers
  root to: 'home#index'

  require 'sidekiq/web'
  begin
    require 'sidekiq/pro/web'
  rescue LoadError
    # no sidekiq pro
  end
  constraint = lambda { |request| request.env['warden'].authenticate? and request.env['warden'].user.admin? }
  constraints(constraint) { mount Sidekiq::Web => '/sidekiq' }

  get '/queue_status' => proc {
    queue_size   = %w(high low).map { |q| Sidekiq::Queue.new(q).size }.inject(:+)
    queue_status = if queue_size == 0
                     'idle'
                   elsif queue_size < 21
                     'working'
                   else
                     'heavy'
                   end
    [200, {'Content-Type' => 'text/plain'}, [queue_status]]
  }
end
