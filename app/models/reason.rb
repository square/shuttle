class Reason < ActiveRecord::Base
  def as_json(options=nil)
    options ||= {}

    options[:except] = Array.wrap(options[:only])
    options[:except] << :created_at
    options[:except] << :updated_at

    super options
  end
end
