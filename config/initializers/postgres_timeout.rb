# pg gem doesn't respect the timeout value in the database.yml file
# this initializer fixes that problem.

begin
  database_config = Rails.configuration.database_configuration[Rails.env]
  if database_config['timeout'] && ('postgresql' == database_config['adapter'].downcase)
    ActiveRecord::Base.connection.execute "SET statement_timeout = '#{database_config['timeout']}s'"
  end
rescue Exception => e
  logger.error e.inspect
end
