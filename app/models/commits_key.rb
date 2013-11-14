# A `has_and_belongs_to_many` join table between {Commit} and {Key} that has
# been upgraded to a full model class. This is so it can be eager-loaded with
# keys to speed the process of populating the `commit_ids` field on the Key's
# ElasticSearch index.

class CommitsKey < ActiveRecord::Base
  belongs_to :commit, inverse_of: :commits_keys
  belongs_to :key, inverse_of: :commits_keys

  validates :commit_id, :key_id,
            presence: true
  validates :key_id,
            uniqueness: {scope: :commit_id}

  #after_create :add_to_commit_index
  #after_destroy :remove_from_commit_index

  private

  def remove_from_commit_index
    url = "#{key.tire.index.url}/key/#{Tire::Utils.escape(key_id)}"
    Tire::Configuration.client.put url, MultiJson.encode(
        script: 'ctx._source.commit_ids -= commit_id',
        params: {
            commit_id: commit_id
        }
    )
  end

  def add_to_commit_index
    url = "#{key.tire.index.url}/key/#{Tire::Utils.escape(key_id)}"
    Tire::Configuration.client.put url, MultiJson.encode(
        script: 'ctx._source.commit_ids += commit_id',
        params: {
            commit_id: commit_id
        }
    )
  end
end
