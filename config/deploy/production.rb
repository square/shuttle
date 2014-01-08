set :stage, :production

role :app, %w{square@ironweed.corp.squareup.com square@ginger.corp.squareup.com square@shuttle-web01.corp.squareup.com square@shuttle-web02.corp.squareup.com square@shuttle-worker01.corp.squareup.com square@shuttle-worker02.corp.squareup.com square@shuttle-worker03.corp.squareup.com square@shuttle-worker04.corp.squareup.com square@shuttle-worker05.corp.squareup.com}
role :web, %w{square@shuttle-web01.corp.squareup.com square@shuttle-web02.corp.squareup.com}
role :db,  %w{square@ironweed.corp.squareup.com}
