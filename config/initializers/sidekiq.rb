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

module Squash
  class Sidekiq
    def call(_worker, msg, queue)
      begin
        yield
      rescue Exception => ex
        Squash::Ruby.notify ex, sidekiq: msg, queue: queue
        raise
      end
    end
  end
end

module Sidekiq::Util

  # Restore the presence of the process ID in the Sidekiq worker string. We need
  # this to find and kill dead lockfiles.
  def process_id() Process.pid end
end

configure_sidekiq = -> do
  Sidekiq.configure_client do |config|
    config.redis = YAML.load_file(Rails.root.join('config', 'sidekiq.yml')).
        merge(url: Shuttle::Redis.client.id)
  end
  Sidekiq.configure_server do |config|
    config.redis = YAML.load_file(Rails.root.join('config', 'sidekiq.yml')).
        merge(url: Shuttle::Redis.client.id)
    config.server_middleware do |chain|
      chain.add ::Squash::Sidekiq
    end

  end
end

if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    configure_sidekiq.call if forked
  end
else
  configure_sidekiq.call
end
