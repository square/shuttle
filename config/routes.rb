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

Shuttle::Application.routes.draw do
  # AUTHENTICATION
  devise_for :users, controllers: {registrations: 'registrations'}

  # API
  post 'api/1.0/strings' => 'api/v1#strings'

  # REST
  resources :projects do
    resources :commits, only: [:show, :create, :update, :destroy] do
      member do
        post :import, :sync, :redo
        get :manifest, :localize
      end

      resources :keys, only: [:index, :show], controller: 'commit/keys'
    end

    resources :keys, only: [] do
      resources :translations, only: [:show, :new, :create, :edit, :update] do
        member do
          get :match
          put :approve, :reject
        end
      end
    end

    member do
      post 'pull-request-builder' => 'projects#github_webhook'
    end
  end

  resources :locales, only: :index do
    collection { get :countries }
    resources :projects, only: [:index, :show], controller: 'locale/projects' do
      resources :translations, controller: 'locale/translations', only: :index
    end
    resources :glossary_entries, only: [:index, :create, :update, :destroy]
  end

  resources :source_glossary_entries, only: [:index, :create, :update, :destroy], controller: 'glossary/source_glossary_entries' do 
    resources :locale_glossary_entries, only: [:create, :update, :destroy], 
              as: 'locale', 
              controller: 'glossary/locale_glossary_entries'
  end 

  resources :users, only: [:index, :show, :update, :destroy] do
    member { post :become }
  end

  resources :translation_units, only: [:index, :edit, :update, :destroy]

  get 'substitute' => 'substitution#convert'

  get 'search' => redirect('/search/translations')
  get 'search/translations' => 'search#translations', as: :search_translations
  get 'search/keys' => 'search#keys', as: :search_keys
  get 'search/commits' => 'search#commits', as: :search_commits

  # HOME PAGES
  get 'administrators' => 'home#administrators', as: :administrators
  get 'translators' => 'home#translators', as: :translators
  get 'reviewers' => 'home#reviewers', as: :reviewers
  get 'glossary' => 'home#glossary', as: :glossary
  root to: 'home#index'

  require 'sidekiq/web'
  constraint = lambda { |request| request.env["warden"].authenticate? and request.env['warden'].user.admin? }
  constraints constraint do
    mount Sidekiq::Web => '/sidekiq'
  end
end
