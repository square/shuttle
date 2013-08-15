set :rails_env, 'staging'

role :web, 'baltimore.corp.squareup.com'
role :app, 'baltimore.corp.squareup.com'
role :db, 'baltimore.corp.squareup.com', primary: true
