class CommitsSearchPresenter
  include Rails.application.routes.url_helpers

  attr_reader :is_translator, :project, :locales

  def initialize(locales, is_translator, project)
    @is_translator = is_translator
    @project = project
    @locales = locales
  end

  def original_key(key)
    key.original_key
  end

  def source(key)
    key.source
  end

  def locales_to_show
    locale_requirements = project.locale_requirements
    to_show =  if locales
                  locales_arr = locales.map(&:strip).uniq.select { |l| locale_requirements.include? Locale.from_rfc5646(l) }
                  Hash[locales_arr.map { |l| [Locale.from_rfc5646(l), locale_requirements[Locale.from_rfc5646(l)]]}]
               else
                 locale_requirements.select{ |_, required| required }
               end
    # since base locale is not always required, add it in and make sure locales stays under 5
    if to_show.include? project.base_locale
      to_show.delete(project.base_locale)
    end
    # re add it such that its the first key and will be displayed first
    to_show = {project.base_locale => true}.merge(to_show)
    if to_show.size > 5
      to_delete = to_show.keys.from(5)
      to_delete.each { |d| to_show.delete(d) }
    end
    to_show
  end

  def translation_for_locale(key, locale)
    key.translations.find { |t| t.locale == locale }
  end

  def translation_class(translation)
    if translation.approved
      'text-success'
    elsif translation.approved == false
       'text-error'
    elsif translation.translated
      'text-info'
    else
      'muted'
    end
  end

  def translation_text(translation)
    if !translation.translated?
      '(not yet translated)'
    elsif /\A\s*\z/ =~ translation.copy
      '(blank string)'
    else
      translation.copy[0..30]
    end
  end

  def translation_url(translation)
    if is_translator
      edit_project_key_translation_path(project, translation.key, translation)
    else
      project_key_translation_path(@project, translation.key, translation)
    end
  end
end