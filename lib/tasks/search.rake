namespace :search do
  task index: :environment do
    Dir[Rails.root.join('app', 'models', '**', '*.rb')].each { |f| require f }
    ActiveRecord::Base.subclasses.each do |klass|
      total  = klass.count rescue nil
      next unless klass.respond_to?(:tire)
      Tire::Tasks::Import.add_pagination_to_klass(klass)
      Tire::Tasks::Import.progress_bar(klass, total) if total
      index = klass.tire.index
      Tire::Tasks::Import.delete_index(index) if ENV['FORCE']
      Tire::Tasks::Import.create_index(index, klass)
      Tire::Tasks::Import.import_model(index, klass, {})
    end
  end
end
