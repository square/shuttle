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

# Adds the {#sidekiq_batch} method to models, which in turn adds more helper methods to manage
# the sidekiq batch and sidekiq batch status.
#
# @example
#   class Document < ActiveRecord::Base
#     extend SidekiqBatchManager
#     sidekiq_batch :parse_batch do |batch|
#       batch.description = "Parse document #{id} (#{name})"
#       batch.on :success, ParseFinisher, document_id: id
#     end
#   end
#
#   document = Document.new
#   document.parse_batch
#   document.parse_batch.jobs do
#     # add jobs here
#   end
#   document.parse_batch_status
#   document.reset_parse_batch_id
#

module SidekiqBatchManager

  # Defines 3 helper methods for Sidekiq Batches that handle persistance in sql database.
  # It expects a column in the database table whose name is batch_method_name suffixed with '_id'.
  # For instance, if the batch name is 'import_batch', it expects a 'import_batch_id' column, and
  # defines the following 3 methods: `import_batch`, `import_batch_status` and `reset_import_batch_id!`.

  # @param [Symbol] batch_method_name The batch method name to be created
  # @param [Proc] proc The proc that will be called in the context of this instance with the
  #   sidekiq batch. Use this to configure batch settings such as description or callbacks such
  #   as on_success.

  def sidekiq_batch(batch_method_name, &proc)
    batch_method_name = batch_method_name.to_sym
    batch_status_method_name = :"#{batch_method_name}_status"
    bid_column_name = :"#{batch_method_name}_id"
    reset_batch_id_method_name = :"reset_#{bid_column_name}!"

    define_batch_method(batch_method_name, bid_column_name, proc)
    define_batch_status_method(batch_status_method_name, bid_column_name)
    define_reset_batch_id_method(reset_batch_id_method_name, bid_column_name)
  end

  private

  # Defines the method which
  #   - finds or creates a Sidekiq batch for this record and for the specified batch method.
  #   - sets record's batch id in the db when a new batch is created.
  #
  # @param [Symbol] batch_method_name The method name which will find or create the sidekiq batch
  #   for this job
  # @param [Symbol] bid_column_name The name of the database column where batch id is stored.
  # @param [Proc] proc The proc that will be called in the context of this instance with the
  #   sidekiq batch. Use this to configure batch settings such as description or callbacks such
  #   as on_success.
  #
  # BELOW ARE THE ANNOTATIONS FOR THE DEFINED METHOD
  # @return [Sidekiq::Batch] The batch of Sidekiq workers performing the current import, if any.
  #    Otherwise, creates a new one.

  def define_batch_method(batch_method_name, bid_column_name, proc)
    define_method(batch_method_name) do
      if send(bid_column_name)
        begin
          return Sidekiq::Batch.new(send(bid_column_name))
        rescue Sidekiq::Batch::NoSuchBatch
        end
      end

      batch = Sidekiq::Batch.new
      instance_exec batch, &proc
      update_attribute bid_column_name, batch.bid
      batch
    end
  end


  # Defines the method which returns Sidekiq Batch Status if there is a batch.
  #
  # @param [Symbol] batch_status_method_name The method name for the method which returns the batch info.
  # @param [Symbol] bid_column_name The name of the database column where batch id is stored.
  #
  # BELOW ARE THE ANNOTATIONS FOR THE DEFINED METHOD
  # @return [Sidekiq::Batch::Status, nil] Information about the batch of Sidekiq
  #   workers performing the current job, if any.

  def define_batch_status_method(batch_status_method_name, bid_column_name)
    define_method(batch_status_method_name) do
      begin
        send(bid_column_name) ? Sidekiq::Batch::Status.new(send(bid_column_name)) : nil
      rescue Sidekiq::Batch::NoSuchBatch
        update_attribute bid_column_name, nil
        nil
      end
    end
  end

  # Defines the method which resets batch id column to nil.
  #
  # @param [Symbol] reset_batch_id_method_name The method name which will be defined.
  # @param [Symbol] bid_column_name The name of the database column where batch id is stored.

  def define_reset_batch_id_method(reset_batch_id_method_name, bid_column_name)
    define_method(reset_batch_id_method_name) do
      update! bid_column_name => nil
    end
  end
end
