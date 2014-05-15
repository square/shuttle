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

# A concern for {Commit} that records errors that happen during commit importing. It uses Redis to
# store import errors in a threadsafe fashion. At the end of the import process, these errors are
# moved to the sql db to be stored for the long term.

module ImportErrors
  # @return [Array<Array<String>>] An array containing import error details stored in redis
  # represented as  `[path_to_file_with_error, error_message]`.
  def import_errors_in_redis
    Shuttle::Redis.smembers(import_errors_redis_key).map do |err|
      first, *rest = err.split(' ')
      [first, rest.join(' ')]
    end
  end

  # Adds an import error to redis for a commit
  #   @param [String] path The path of the file which the error occurred in.
  #   @param [String] err The error message to record.
  def add_import_error_in_redis(path, err)
    Shuttle::Redis.sadd(import_errors_redis_key, "#{path} #{err}")
  end

  # Copies import errors from Redis to SQL database
  def copy_import_errors_from_redis_to_sql_db
    old_metadata = JSON.parse(metadata) rescue {}
    old_metadata[:import_errors] = import_errors_in_redis
    update_column(:metadata, old_metadata.to_json)
    reload
  end

  # Removes all previous import errors from redis and postgres.
  def clear_import_errors
    clear_import_errors_in_redis
    update_attributes(import_errors: [])
  end

  private

  def import_errors_redis_key
    "commit:#{revision}:import_errors"
  end

  # Removes all previous import errors from redis.
  def clear_import_errors_in_redis
    Shuttle::Redis.del(import_errors_redis_key)
  end
end
