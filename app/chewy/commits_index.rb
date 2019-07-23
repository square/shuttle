class CommitsIndex < Chewy::Index
  settings analysis: {
      analyzer: {
          sha: {
              tokenizer: 'keyword'
          }
      }
  }

  define_type Commit.includes(:commits_keys) do
    field :id, type: 'integer'
    field :project_id, type: 'integer'
    field :user_id, type: 'integer'
    field :priority, type: 'integer'
    field :due_date, type: 'date'
    field :created_at, type: 'date'
    field :revision, analyzer: 'sha'
    field :loading, type: 'boolean'
    field :ready, type: 'boolean'
    field :exported, type: 'boolean'
    field :fingerprint, analyzer: 'sha'
    field :duplicate, type: 'boolean'
    field :key_ids, value: ->(c) { c.commits_keys.pluck(:key_id) }
  end
end
