set :rails_env, 'production'

role :web, 'ironweed.corp.squareup.com'
role :app, 'ironweed.corp.squareup.com', 'ginger.corp.squareup.com'
role :db, 'ironweed.corp.squareup.com', primary: true
