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

# Adds the {#searchable_field} method to models.
#
# @example
#   class Model < ActiveRecord::Base
#     extend SearchableField
#     searchable_field :my_field
#   end

module SearchableField

  # @overload searchable_field(field, ..., options={})
  #   Defines one or more columns that have corresponding columns in the model
  #   table of type `TSVECTOR`, used to perform textual searches on those
  #   fields. When these fields are modified, the corresponding TSVECTOR will be
  #   updated. (Remember to add GiST indexes to your table!)
  #
  #   This method also adds a scope called "<field>_query" (with
  #   "<field>" being the name of the field) that is used to perform a textual
  #   search of the field.
  #
  #   @param [Symbol] field The name of a table column.
  #   @param [Hash] option Additional options.
  #   @option options [String] language ("english") The default language that
  #     values of this field are in. (Also the default language for queries
  #     using the scope.) This must be a valid PostgreSQL text search
  #     configuration name.
  #   @option options [Symbol] language_from If provided, PostgreSQL will save
  #     the TSVECTOR using a text search configuration determined from the
  #     return value of this method. The method should return a {Locale}. The
  #     Locale will be converted to a text search configuration using the
  #     `text_search_configurations.yml` file.
  #   @option options [Symbol] search_column The name of the TSVECTOR-type table
  #     column. By default it is "searchable_<field>" with "<field>" being the
  #     source column name.

  def searchable_field(*fields)
    options = fields.extract_options!
    options[:language] ||= 'english'

    attr_accessor :_searchable_field_operations

    fields.each do |field|
      search_column = options[:search_column] || :"searchable_#{field}"

      scope :"#{field}_query", ->(query, lang=options[:language]) {
        where("PLAINTO_TSQUERY(#{connection.quote lang}, #{connection.quote(query || '')}) @@ #{quoted_table_name}.#{connection.quote_column_name search_column}")
      }

      before_save do |object|
        return true unless send(:"#{field}_changed?")

        language = if options[:language_from]
                     SearchableField::text_search_configuration(send(options[:language_from]))
                   else
                     options[:language]
                   end

        object._searchable_field_operations ||= []
        object._searchable_field_operations << [search_column, language, send(field) || '']

        true
      end
    end

    after_save do |object|
      return true unless object._searchable_field_operations.present?

      commands = []
      until object._searchable_field_operations.empty?
        column, language, value = object._searchable_field_operations.pop
        commands << "#{self.class.connection.quote_column_name column} = TO_TSVECTOR(#{self.class.connection.quote language}, #{self.class.connection.quote value})"
      end
      pkey_hash = Array.wrap(object.class.primary_key).inject({}) { |hsh, key| hsh[key] = object[key]; hsh }

      self.class.where(pkey_hash).update_all commands.join(', ')

      true
    end
  end

  # Returns a PostgreSQL text search configuration for a given locale, or
  # "simple" if PostgreSQL has no native configuration for that locale. Only the
  # language portion of the locale is considered.
  #
  # @param [Locale] locale A locale.
  # @return [String] A PostgreSQL text search configuration name.

  def self.text_search_configuration(locale)
    @tsc ||= YAML.load_file(Rails.root.join('data', 'text_search_configurations.yml'))
    @tsc[locale.iso639] || 'simple'
  end
end
