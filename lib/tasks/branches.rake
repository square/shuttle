namespace :branches do
  desc "Updates touchdown branches as necessary"
  task update: :environment do
    Project.find_each(&:update_touchdown_branch)
  end
end
