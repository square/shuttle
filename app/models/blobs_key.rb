# An upgraded `has_and_belongs_to_many` association between {Blob Blobs} and
# {Key Keys}.

class BlobsKey < ActiveRecord::Base
  belongs_to :blob, foreign_key: [:project_id, :sha_raw], inverse_of: :blobs_keys
  belongs_to :key, inverse_of: :blobs_keys

  #validates :project_id, :sha_raw, :key_id,
  #          presence: true
  #validates :key_id,
  #          uniqueness: {scope: [:project_id, :sha_raw]}
end
