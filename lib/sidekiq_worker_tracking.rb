# Adds the ability to track Sidekiq workers performing an oepration on an object
# and update the value of a `loading` column when all workers have completed.
#
# To use this module, your model must have an attribute named `loading`. When
# you add a worker that performs an operation on your model, you should pass its
# JID to the {#add_worker!} method. The model's `loading` column will be set to
# `false`, and will remain `false` until all such workers have completed.
#
# @example
#   class MyModel
#     include SidekiqWorkerTracking
#     attr_accessor :loading
#
#     def perform_operation
#       10.times do
#         add_worker! OperationPerformer.perform_async(...)
#       end
#     end
#
#     def all_operations_completed?
#       !loading
#     end
#   end

module SidekiqWorkerTracking
  # Adds a worker to the loading list. This object, if not already loading, will
  # be marked as loading until this and all other added workers call
  # {#remove_worker!}.
  #
  # @param [String] jid A unique identifier for this worker.

  def add_worker!(jid)
    self.loading = true
    save!
    Shuttle::Redis.sadd worker_set_key, jid
  end

  # Removes a worker from the loading list. This object will not be marked as
  # loading if this was the last worker. Also recalculates Commit statistics if
  # this was the last worker.
  #
  # @param [String] jid A unique identifier for this worker.
  # @see #add_worker!

  def remove_worker!(jid)
    if jid.nil?
      return
    end
    
    Shuttle::Redis.srem worker_set_key, jid
    loading = (Shuttle::Redis.scard(worker_set_key) > 0)

    self.loading = loading
    save!
  end

  # Returns all workers from the loading list

  def list_workers
    Shuttle::Redis.smembers worker_set_key
  end

  # Removes all workers from the loading list, marks the Commit as not loading,
  # and recalculates Commit statistics if the Commit was previously loading.
  # This method should be used to fix "stuck" Commits.

  def clear_workers!
    Shuttle::Redis.del worker_set_key
    if loading?
      self.loading = false
      save!
    end
  end

  private

  def worker_set_key
    "loading:#{self.class.to_s}:#{self.id}"
  end
end
