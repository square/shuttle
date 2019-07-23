# Wraps Sidekiq jobs with a `Chewy.strategy(:atomic)` call.

class ChewyAtomic
  def initialize(options=nil)

  end

  def call(_worker, _msg, _queue)
    Chewy.strategy(:atomic) { yield }
  end
end
