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

# HACKY HACKY HACK -- fix a bug in Rails 4.0 around handling of bytea values

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter

  # The way Rails chooses to encode bytea values is incompatible with PostgreSQL
  # 8.x. To fix this, we instead encode bytea values in an octal escape format
  # compatible with all versions of PostgreSQL.

  def escape_bytea(value)
    return nil unless value
    output = ''
    value.each_byte { |byte| output << '\\\\' << byte.to_s(8).rjust(3, '0') }
    return output
  end

  # Wrap the encoded string (generated using the above method) with the
  # appropriate sigil to indicate that should be escaped.

  def quote_with_bytea(value, column=nil)
    if value.kind_of?(String) && column.try!(:sql_type) == 'bytea'
      "E'#{escape_bytea value}'::bytea"
    else
      quote_without_bytea value, column
    end
  end
  alias_method_chain :quote, :bytea

  # A bug in Rails 4.0 causes bytea values to be serialized as YAML-encoded
  # hashes of the format {value: "something", format: 1}. This is because Rails
  # 4.0 uses prepared statements and binds in Postgres, and the API for this
  # requires that non-ASCII bind values be passed as hashes of that format. The
  # problem is, the type_cast method is used too early in the process of
  # generating the query, meaning that bytea values actually get serialized as
  # that hash.
  #
  # This hack 1) reverts type_cast so it does not attempt to alter the bytea
  # value, and ...

  def type_cast_with_old_bytea_behavior(value, column, array_member=false)
    if value.kind_of?(String) && 'bytea' == column.sql_type
      value
    else
      type_cast_without_old_bytea_behavior value, column, array_member
    end
  end
  alias_method_chain :type_cast, :old_bytea_behavior

  # ... 2) correctly sends the bind value to the connection object.

  def exec_cache(sql, binds)
    stmt_key = prepare_statement sql

    # Clear the queue
    @connection.get_last_result
    @connection.send_query_prepared(stmt_key, binds.map { |col, val|
      if val.kind_of?(String) && col.try!(:sql_type) == 'bytea'
        {value: val, format: 1}
      else
        type_cast(val, col)
      end
    })
    @connection.block
    @connection.get_last_result
  rescue PGError => e
    # Get the PG code for the failure.  Annoyingly, the code for
    # prepared statements whose return value may have changed is
    # FEATURE_NOT_SUPPORTED.  Check here for more details:
    # http://git.postgresql.org/gitweb/?p=postgresql.git;a=blob;f=src/backend/utils/cache/plancache.c#l573
    begin
      code = e.result.result_error_field(PGresult::PG_DIAG_SQLSTATE)
    rescue
      raise e
    end
    if FEATURE_NOT_SUPPORTED == code
      @statements.delete sql_key(sql)
      retry
    else
      raise e
    end
  end
end

# Fix a bug with Composite Primary Keys that causes it to bypass the PostgreSQL
# adapter's type_cast method.

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLColumn
      # This overide is needed to ensure ActiveRecord::Dirty behaves as expected
      def type_cast(value)
        # CPK's version
        return value if value.kind_of?(Array)

        # PostgreSQLAdapter's version
        return if value.nil?
        return super if encoded?

        @oid_type.type_cast value
      end
    end
  end
end


# Fix another CPK bug with bytea

module ActiveRecord
  module AttributeMethods
    module Write
      def write_attribute(attr_name, value)
        # CPK
        if attr_name.kind_of?(Array)
          value = [nil]*attr_name.length if value.nil?
          unless value.length == attr_name.length
            raise "Number of attr_names #{attr_name.inspect} and values #{value.inspect} do not match"
          end
          [attr_name, value].transpose.map {|name,val| write_attribute(name, val)}
          value
        else
          attr_name = attr_name.to_s
          attr_name = self.class.primary_key if attr_name == 'id' && self.class.primary_key
          @attributes_cache.delete(attr_name)
          column = column_for_attribute(attr_name)

          # If we're dealing with a binary column, write the data to the cache
          # so we don't attempt to typecast multiple times.
          if column && column.binary?
            @attributes_cache[attr_name] = value
          end

          if column || @attributes.has_key?(attr_name)
            @attributes[attr_name] = type_cast_attribute_for_write(column, value)
          else
            raise ActiveModel::MissingAttributeError, "can't write unknown attribute `#{attr_name}'"
          end
        end
      end
      alias_method :raw_write_attribute, :write_attribute
    end
  end
end
