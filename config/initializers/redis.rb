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

redis_options = Shuttle::Configuration.redis.symbolize_keys

Shuttle::Redis    = Redis.new(redis_options)
RedisClassy.redis = Shuttle::Redis

Rails.application.config.cache_store = :redis_store, redis_options.merge(namespace: :shuttle_cache)
Rails.application.config.action_dispatch.rack_cache = {
    metastore:   URI::Generic.build(redis_options.merge(scheme: 'redis', path: '/shuttle_metastore')).to_s,
    entitystore: URI::Generic.build(redis_options.merge(scheme: 'redis', path: '/shuttle_entitystore')).to_s
}
