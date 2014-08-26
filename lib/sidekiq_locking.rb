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

# Adds the {ClassMethods#perform_once} method to the class. This class must be
# included after the `perform` method is defined.

module SidekiqLocking
  extend ActiveSupport::Concern

  included do
    alias_method_chain :perform, :locking
  end

  # @private
  def perform_with_locking(*args)
    self.class.unlock *args
    perform_without_locking *args
  end

  module ClassMethods

    # Enqueues this job unless a job with identical arguments is already in the
    # queue.

    def perform_once(*args)
      perform_async(*args) if mutex(*args).lock
    end

    # @private
    def unlock(*args)
      mutex(*args).unlock(true)
    end

    private

    def lock_name(*args)
      "#{name.downcase}:#{Sidekiq.dump_json(args)}"
    end

    def mutex(*args)
      Redis::Mutex.new(lock_name(*args), expire: 1.hour)
    end
  end
end
