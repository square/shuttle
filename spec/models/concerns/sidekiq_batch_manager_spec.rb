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

# Any model with a column that stores the batch id can be used. The specs in this file will be using
# the Commit model, for no specific reason.

require 'spec_helper'

describe SidekiqBatchManager do
  class BatchFinisher
    def on_success(_status, options)
    end
  end

  before :each do
    # remove methods that will be defined later
    [:import_batch, :import_batch_status].each { |method_name| Commit.send :remove_method, method_name }
    Commit.extend SidekiqBatchManager
    @commit = FactoryGirl.create(:commit)
  end

  after :each do
    load 'commit.rb' # reload the commit class so that other specs don't get confused
  end

  describe "#sidekiq_batch" do
    before :each do
      proc = Proc.new do |batch|
        batch.description = "Import Commit #{id} (#{revision})"
        batch.on :success, BatchFinisher, commit_id: id
      end
      Commit.send :sidekiq_batch, :import_batch, &proc
    end

    it "defines an import_batch method which returns a sidekiq batch with the settings from the given proc" do
      BatchFinisher.any_instance.should_receive(:on_success).with(instance_of(Sidekiq::Batch::Status), 'commit_id'=>@commit.id)
      batch = @commit.import_batch.tap { |b| b.jobs {} }
      expect(@commit.import_batch).to be_a_kind_of(Sidekiq::Batch)
      expect(@commit.import_batch_id).to eql(batch.bid)
      expect(batch.description).to eql("Import Commit #{@commit.id} (#{@commit.revision})")
    end

    it "defines an import_batch_status method which returns a sidekiq batch status" do
      batch = @commit.import_batch.tap { |b| b.jobs {} }
      status = @commit.import_batch_status
      expect(status).to be_a_kind_of(Sidekiq::Batch::Status)
      expect(status.bid).to eql(batch.bid)
    end
  end

  describe "#define_batch_method" do
    context "[defines the batch method which]" do
      before :each do
        proc = Proc.new do |batch|
          batch.description = "Import Commit #{id} (#{revision})"
          batch.on :success, BatchFinisher, commit_id: id
        end
        Commit.send :define_batch_method, :import_batch, :import_batch_id, proc
      end

      it "returns the existing batch if there is one" do
        batch = Sidekiq::Batch.new.tap { |b| b.jobs {} }
        @commit.update! import_batch_id: batch.bid
        expect(@commit.import_batch).to be_a_kind_of(Sidekiq::Batch)
        expect(@commit.import_batch_id).to eql(batch.bid)
      end

      it "returns a new batch if there is a batch id saved in sql db but the batch is already stale" do
        @commit.update! import_batch_id: 'fakebatchid'
        batch = @commit.import_batch
        expect(batch).to be_a_kind_of(Sidekiq::Batch)
        expect(@commit.import_batch_id).to eql(batch.bid)
        expect(@commit.import_batch_id).to_not eql('fakebatchid')
      end

      it "returns a new batch if there is no batch id saved in sql db" do
        @commit.update! import_batch_id: nil
        batch = @commit.import_batch
        expect(batch).to be_a_kind_of(Sidekiq::Batch)
        expect(@commit.import_batch_id).to eql(batch.bid)
      end

      it "adds a description and an on_success hook from the proc to the batch" do
        BatchFinisher.any_instance.should_receive(:on_success).with(instance_of(Sidekiq::Batch::Status), 'commit_id'=>@commit.id)
        @commit.import_batch.jobs {}
        expect(@commit.import_batch.description).to eql("Import Commit #{@commit.id} (#{@commit.revision})")
      end
    end
  end

  describe "#define_batch_status_method" do
    context "[defines the batch status method which]" do
      before :each do
        Commit.send :define_batch_status_method, :import_batch_status, :import_batch_id
      end

      it "returns the existing batch if there is one" do
        batch = Sidekiq::Batch.new.tap { |b| b.jobs {} }
        @commit.update! import_batch_id: batch.bid
        expect(@commit.import_batch_status).to be_a_kind_of(Sidekiq::Batch::Status)
        expect(@commit.import_batch_status.bid).to eql(batch.bid)
      end

      it "returns nil if there is a saved batch id but it's stale" do
        @commit.update! import_batch_id: 'fakebatchid'
        expect(@commit.import_batch_status).to be_nil
      end

      it "returns nil if no batch id saved in sql db" do
        @commit.update! import_batch_id: nil
        expect(@commit.import_batch_status).to be_nil
      end
    end
  end
end
