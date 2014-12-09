set :stage, :production

worker_boxes = (1..3).map { |i| "user@shuttle-worker#{i.to_s.rjust(2, '0')}.example.com" }
web_boxes    = (1..2).map { |i| "user@shuttle-web#{i.to_s.rjust(2, '0')}.example.com" }
db_boxes     = %w{user@shuttle-db.example.com}

role :app,          (web_boxes + worker_boxes + db_boxes).uniq
role :web,          web_boxes
role :db,           db_boxes
role :sidekiq,      worker_boxes
role :primary_cron, worker_boxes.first
