# Copyright 2013 Square Inc.
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

# HACKY HACKY HACK -- fix a nasty-ass bug in PGconn#escape_bytea that only
# happens in production. Remove this when we upgrade to PostgreSQL 9.0+.

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  def escape_bytea(value)
    return nil unless value
    output = ''
    value.each_byte { |byte| output << '\\\\' << byte.to_s(8).rjust(3, '0') }
    return output
  end

  def quote_with_bytea(value, column=nil)
    if value.kind_of?(String) && column.try(:sql_type) == 'bytea'
      "E'#{escape_bytea(value)}'::bytea"
    else
      quote_without_bytea value, column
    end
  end
  alias_method_chain :quote, :bytea
end #if ActiveRecord::Base.connection.send(:postgresql_version) < 90000
