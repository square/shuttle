class KeysIndex < Chewy::Index
  settings analysis: {
      tokenizer: {
          key_tokenizer: {type: 'pattern', pattern: '[^A-Za-z0-9]'}
      },
      analyzer:  {
          key_analyzer: {type: 'custom', tokenizer: 'key_tokenizer', filter: 'lowercase'}
      }
  }

  define_type Key do
    field :id, type: 'integer'
    field :original_key, type: 'text', analyzer: 'key_analyzer'
    field :original_key_exact, type: 'keyword', value: ->(t) { t.original_key }
    field :project_id, type: 'integer'
    field :ready, type: 'boolean'
    field :hidden_in_search, type: 'boolean'
  end
end
