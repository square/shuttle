# This file is copied from public-web project.
RateLimitRedisCache = Struct.new(:redis_pool) do
  def read(key)
    redis_pool.with do |conn|
      conn.get(key)
    end
  rescue => e
    ExceptionNotifier.notify(e)
    nil
  end

  def write(key, value, options = {})
    redis_pool.with do |conn|
      if options[:expires_in].present?
        conn.setex(key, options[:expires_in], value)
      else
        conn.set(key, value)
      end
    end
  rescue => e
    ExceptionNotifier.notify(e)
    nil
  end

  def increment(key, amount, options = {})
    redis_pool.with do |conn|
      count = nil
      conn.pipelined do
        count = conn.incrby(key, amount)
        conn.expire(key, options[:expires_in]) if options[:expires_in]
      end
      count&.value
    end
  rescue => e
    ExceptionNotifier.notify(e)
    nil
  end

  def delete(key)
    redis_pool.with do |conn|
      conn.del(key)
    end
  rescue => e
    ExceptionNotifier.notify(e)
    nil
  end
end
