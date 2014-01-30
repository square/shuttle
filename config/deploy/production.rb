set :stage, :production

worker_boxes = (1..5).map { |i| "square@shuttle-worker#{i.to_s.rjust(2, '0')}.corp.squareup.com" }
web_boxes    = (1..2).map { |i| "square@shuttle-web#{i.to_s.rjust(2, '0')}.corp.squareup.com" }
db_boxes     = %w{square@ironweed.corp.squareup.com}

role :app, (web_boxes + worker_boxes + db_boxes).uniq
role :web, web_boxes
role :db, db_boxes
role :sidekiq, worker_boxes
role :cron, worker_boxes.first
