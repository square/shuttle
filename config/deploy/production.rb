set :stage, :production

worker_boxes = (1..3).map { |i| "square@shuttle-worker#{i.to_s.rjust(2, '0')}.corp.squareup.com" } + (1..5).map { |i| "square@shuttle-worker-a-#{i.to_s.rjust(2, '0')}.corp.squareup.com" }
web_boxes    = (1..2).map { |i| "square@shuttle-web-a-#{i.to_s.rjust(2, '0')}.corp.squareup.com" }

role :app, (web_boxes + worker_boxes).uniq
role :web, web_boxes
role :db, worker_boxes[1] # Migrations will be run on this box
role :sidekiq, worker_boxes
role :cron, worker_boxes.first
