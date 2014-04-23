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
  # BLOCK DEVISE ROUTES
  get 'users/sign_up', to: redirect('/users/sign_in#sign-up')
  get 'users/password/new', to: redirect('/users/sign_in#forgot-password')
  
  # AUTHENTICATION
  devise_for :users, controllers: {
      registrations: 'registrations',
      passwords: 'passwords'
  }

  # API
  post 'api/1.0/strings' => 'api/v1#strings'

  # REST
  resources :projects do
    resources :commits, only: [:show, :create, :update, :destroy] do
      member do
        post :import, :sync, :redo, :clear, :recalculate, :ping_stash
        get :manifest, :localize
      end

      resources :keys, only: [:index, :show], controller: 'commit/keys'
    end

    resources :keys, only: [] do
      resources :translations, only: [:show, :new, :create, :edit, :update] do
        member do
          get :match, :fuzzy_match
          put :approve, :reject
        end
      end
    end

    member do
      post 'github-pull-request-builder' => 'projects#github_webhook'
      post 'stash-pull-request-builder' => 'projects#stash_webhook'
    end
  end

  resources :locales, only: :index do
    collection { get :countries }
    resources :projects, only: [:index, :show], controller: 'locale/projects' do
      resources :translations, controller: 'locale/translations', only: :index
    end
    resources :glossary_entries, only: [:index, :create, :update, :destroy]
  end

  resources :users, only: [:index, :show, :update, :destroy] do
    member { post :become }
  end

  resources :translation_units, only: [:index, :edit, :update, :destroy]

  get 'substitute' => 'substitution#convert'

  # SEARCH PAGES
  get 'search' => redirect('/search/translations')
  get 'search/translations' => 'search#translations', as: :search_translations
  get 'search/keys' => 'search#keys', as: :search_keys
  get 'search/commits' => 'search#commits', as: :search_commits

  # STATS PAGES
  get 'stats' => 'stats#index'
  get 'stats/words_per_project' => 'stats#words_per_project'
  get 'stats/translation_metrics' => 'stats#translation_metrics'

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
