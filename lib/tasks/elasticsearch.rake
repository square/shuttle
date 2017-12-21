# Copyright 2016 Square Inc.
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

# A collection of Rake tasks to facilitate importing data from your models into Elasticsearch.
#
# To import all elasticsearch indexed models, run:
#
#     $ bundle exec rake RAILS_ENV=environment elasticsearch:import:model FORCE=y
#
# To import the records from your `Article` model, run:
#
#     $ bundle exec rake RAILS_ENV=environment elasticsearch:import:model CLASS='MyModel'
#
# Run this command to display usage instructions:
#
#     $ bundle exec rake -D elasticsearch
#

require 'elasticsearch/rails/tasks/import'

Rake::Task['elasticsearch:import:all'].clear
namespace :elasticsearch do
  namespace :import do
    task :all do
      dir = ENV['DIR'].presence || Rails.root.join('app', 'models')
      puts "[IMPORT] Loading models from: #{dir}"
      Pathname.glob(dir.join('**', '*.rb')).each do |path|
        next if path.each_filename.include?('concerns')
        next if path.each_filename.include?('observers')
        require path.relative_path_from(dir)
      end

      ActiveRecord::Base.subclasses.each do |klass|
        next unless klass.respond_to?(:__elasticsearch__)
        puts "[IMPORT] Processing model: #{klass}..."

        ENV['CLASS'] = klass.to_s
        Rake::Task['elasticsearch:import:model'].invoke
        Rake::Task['elasticsearch:import:model'].reenable
      end
    end
  end
end
