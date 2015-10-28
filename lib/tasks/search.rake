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

namespace :search do
  task index: :environment do
    klasses = if ENV['CLASS'].present?
                ENV['CLASS'].split(',').map do |klass|
                  require Rails.root.join('app', 'models', klass.underscore + '.rb')
                  klass.constantize
                end
              else
                Dir[Rails.root.join('app', 'models', '**', '*.rb')].each { |f| require f }
                ActiveRecord::Base.subclasses
              end

    klasses.each do |klass|
      total  = klass.count rescue nil
      next unless klass.respond_to?(:tire)
      Tire::Tasks::Import.add_pagination_to_klass(klass)
      Tire::Tasks::Import.progress_bar(klass, total) if total
      index = klass.tire.index
      Tire::Tasks::Import.delete_index(index) if ENV['FORCE']
      Tire::Tasks::Import.create_index(index, klass)
      unless [Translation].include?(klass)
        Tire::Tasks::Import.import_model(index, klass, {})
      end
    end

    if klasses.include?(Translation)
      print "Importing translations (#{(Translation.count/1000.0).ceil} batches)"
      Translation.includes(key: { section: :article }).find_in_batches do |translations|
        print '.'
        Translation.tire.index.import translations
      end
      puts
    end
  end
end
