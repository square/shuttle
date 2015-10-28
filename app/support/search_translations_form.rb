class SearchTranslationsForm

  attr_reader :form

  def initialize(form)
    @form = extract_translations_search_params(form)
  end


  # @param form hash of parameters to process
  def extract_translations_search_params(form)
    processed_params = form.deep_dup
    processed_params[:project_id] = processed_params[:project_id].to_i
    processed_params[:translator_id] = processed_params[:translator_id].to_i

    start_date    = Date.strptime(processed_params[:start_date], "%m/%d/%Y") rescue nil
    end_date      = Date.strptime(processed_params[:end_date], "%m/%d/%Y") rescue nil

    processed_params[:start_date] = start_date
    processed_params[:end_date] = end_date

    processed_params[:page] = if processed_params[:page]
                                processed_params[:page].to_i
                              else
                                1
                              end

    if processed_params[:target_locales].present?
      processed_params[:target_locales] = processed_params[:target_locales].split(',').map { |l| Locale.from_rfc5646(l.strip) }
    end
    processed_params
  end


  # @param [String] key name of the form variable
  # @return [String] variable's value
  def [](key)
    form[key]
  end
end