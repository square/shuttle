RACK_ATTACK_THROTTLE_PATHS = %w(/users /users/sign_in /users/unlock).freeze

RACK_ATTACK_CONNECTION_POOL = ConnectionPool.new(size: 10, timeout: 0.1) do
  redis = Redis.new(Shuttle::Configuration.redis.symbolize_keys)
  Redis::Namespace.new('rack::attack', redis: redis)
end

Rack::Attack.cache.store = RateLimitRedisCache.new(RACK_ATTACK_CONNECTION_POOL)

# Lockout IP addresses that are hammering user sign ups, sign ins and unlocks.
Rack::Attack.blacklist('allow2ban sign in/up access throttling') do |req|
  if RACK_ATTACK_THROTTLE_PATHS.include?(req.path) && req.post?
    # This is used to experiment what the proper IP should be used in throttling.
    ip = req.ip
    client_ip = req.env['HTTP_CLIENT_IP']
    forward_ip = req.env['HTTP_X_FORWARDED_FOR']
    remote_addr = req.env['REMOTE_ADDR']
    Rails.logger.info("RACK-ATTACK checking - ip:#{ip} client_ip:#{client_ip} forward_ip:#{forward_ip} remote_addr:#{remote_addr}")

    # After 20 requests in 5 minute, block all requests from that IP for 1 hour.
    real_ip = client_ip || remote_addr || forward_ip || ip || 'unknown ip'
    Rack::Attack::Allow2Ban.filter(real_ip, maxretry: 20, findtime: 5.minutes, bantime: 1.hour) do
      true
    end
  end
end

Rack::Attack.blacklisted_response = lambda do |_env|
  # Using 503 because it may make attacker think that they have successfully
  # DOSed the site. Rack::Attack returns 403 for blacklists by default
  [503, {}, ['Please try again later']]
end

Rack::Attack.throttled_response = lambda do |_env|
  # Using 503 because it may make attacker think that they have successfully
  # DOSed the site. Rack::Attack returns 429 for throttle by default
  [503, {}, ['Please try again later']]
end

ActiveSupport::Notifications.subscribe('rack.attack') do |_name, _start, _finish, _request_id, req|
  match_type = req.env['rack.attack.match_type']
  if [:throttle, :blacklist].include?(match_type)
    ip = req.ip
    client_ip = req.env['HTTP_CLIENT_IP']
    forward_ip = req.env['HTTP_X_FORWARDED_FOR']
    remote_addr = req.env['REMOTE_ADDR']
    Rails.logger.info("RACK-ATTACK throttled - ip:#{ip} client_ip:#{client_ip} forward_ip:#{forward_ip} remote_addr:#{remote_addr}")
  end
end
