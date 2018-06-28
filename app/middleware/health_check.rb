# Rack middleware that responds to a /_status ping before Rack::SSL gets a
# chance to return a redirect to the HTTPS site.

class HealthCheck
  # @private
  def initialize(app)
    @app = app
  end

  # @private
  def call(env)
    if env['ORIGINAL_FULLPATH'] == '/_status'
      db = Project.connection.select_all('SELECT CURRENT_TIME') rescue nil
      redis = (Shuttle::Redis.get('s') || true) rescue nil
      elasticsearch = Elasticsearch::Model.search({size: 1}, Translation).results.first rescue nil
      status = (db && redis && elasticsearch) ? 'OK' : 'error'

      json = {
          status:        status,
          database:      db ? 'up' : 'down',
          redis:         redis ? 'up' : 'down',
          elasticsearch: elasticsearch ? 'up' : 'down'
      }

      if status == 'OK'
        [200, {}, [json.to_json]]
      else
        [500, {}, [json.to_json]]
      end
    else
      @app.call env
    end
  end
end
