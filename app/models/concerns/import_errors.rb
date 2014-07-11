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

# A concern for {Commit} that records errors that happen during commit
# importing. It uses Redis to store import errors in a threadsafe fashion.
# At the end of the import process, these errors are moved to the sql db
# to be stored for the long term.

module ImportErrors
  # @return [Array<Array<String>>] An array containing import error details
  # stored in redis represented as  `[error class name, error_message]`.
  def import_errors_in_redis
    Shuttle::Redis.smembers(import_errors_redis_key).map do |err|
      first, *rest = err.split(' - ')
      [first, rest.join(' - ')]
    end
  end

  # Adds an import error to redis for a commit
  #   @param [Error] err The error object.
  #   @param [String] addition_message The error message to record in addition to the
  #       actual error message. If provided, it will be added to the end, in paranthesis.
  def add_import_error_in_redis(err, addition_message = nil)
    message = addition_message ? "#{err.message} (#{addition_message})" : err.message
    Shuttle::Redis.sadd(import_errors_redis_key, "#{err.class} - #{message}")
  end

  # Moves import errors from Redis to SQL database
  def move_import_errors_from_redis_to_sql_db!
    update!(import_errors: import_errors_in_redis)
    clear_import_errors_in_redis
  end

  # Removes all previous import errors from redis and postgres.
  def clear_import_errors!
    clear_import_errors_in_redis
    update!(import_errors: [])
  end

  private

  # Removes all previous import errors from redis.
  def clear_import_errors_in_redis
    Shuttle::Redis.del(import_errors_redis_key)
  end

  def import_errors_redis_key
    "commit:#{revision}:import_errors"
  end
end
