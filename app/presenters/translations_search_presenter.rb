class TranslationsSearchPresenter
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TextHelper

  def initialize(is_translator)
    @is_translator = is_translator
  end

  def project(translation)
    translation.key.project.name
  end

  def url_text(translation)
    translation.id
  end

  def url(translation)
    if @is_translator
      edit_project_key_translation_path(translation.key.project, translation.key, translation)
    else
      project_key_translation_path(translation.key.project, translation.key, translation)
    end
  end

  def from(translation)
    translation.source_locale.rfc5646
  end

  def source(translation)
    translation.source_copy
  end

  def to(translation)
    translation.locale.rfc5646
  end

  def translation_class_name(translation)
    if translation.translated
      if translation.approved == true
        'text-success'
      elsif translation.approved == false
        'text-error'
      else
        'text-info'
      end
    else
      'muted'
    end
  end

  def translation_text(translation)
    if translation.translated
      translation.copy
    else
      '(untranslated)'
    end
  end

  def key(translation)
    translation.key.key
  end
end
