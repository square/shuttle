class TranslationsIndex < Chewy::Index
  TRANSLATION_STATE_NEW = 0
  TRANSLATION_STATE_TRANSLATED = 1
  TRANSLATION_STATE_APPROVED = 2
  TRANSLATION_STATE_REJECTED = 3

  define_type Translation.includes(key: :section) do
    field :id, type: 'integer'
    field :copy, analyzer: 'snowball', type: 'text', similarity: 'classic'
    field :source_copy, analyzer: 'snowball', type: 'text', similarity: 'classic'
    field :project_id, type: 'integer', value: ->(t) { t.key.project_id }
    field :article_id, type: 'integer', value: ->(t) { t.key.section&.article_id }
    field :section_id, type: 'integer', value: ->(t) { t.key.section_id }
    field :is_block_tag, type: 'boolean', value: ->(t) { t.key.is_block_tag }
    field :section_active, type: 'boolean', value: ->(t) { t.key.section&.active }
    field :index_in_section, type: 'integer', value: ->(t) { t.key.index_in_section }
    field :translator_id, type: 'integer'
    field :reviewer_id, type: 'integer'
    field :rfc5646_locale, type: 'keyword'
    field :created_at, type: 'date'
    field :updated_at, type: 'date'
    field :translation_state, 'integer', value: -> (t) do
      if t.approved
        TRANSLATION_STATE_APPROVED
      elsif t.translated
        if t.approved.nil?
          TRANSLATION_STATE_TRANSLATED
        else
          TRANSLATION_STATE_REJECTED
        end

      else
        TRANSLATION_STATE_NEW
      end
    end
    field :translated, type: 'boolean', value: -> (t) { !!t.translated } # converts nil to false
    field :approved, type: 'boolean', value: ->(t) { !!t.approved } # converts nil to false
    field :hidden_in_search, type: 'boolean', value: ->(t) { t.key.hidden_in_search }
  end
end
