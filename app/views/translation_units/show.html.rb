require Rails.root.join('app', 'views', 'layouts', 'application.html.rb')

module Views
  module TranslationUnits
    class Index <Views::Layouts::Application

      needs :translation_units#, :locales

      protected

      def body_content
        article(class: 'container') do
          page_header do
            h1 "Translation history for #{@translation_unit.source_copy}"
          end
          #filter_bar
          translation_grid
        end
      end

      def active_tab() 'translator' end

      private

=begin
      def filter_bar
        form_tag(nil, method: 'GET', id: 'filter-form', class: 'filter form-inline') do
          text "Show me "
          select_tag 'filter', options_for_select(
              [
                  ['all', nil],
                  ['untranslated', 'untranslated'],
                  ['translated but not approved', 'unapproved'],
                  ['approved', 'approved']
              ]
          ),         id: 'filter-select'
          text " translations with key substring "
          text_field_tag 'filter', '', placeholder: 'filter by key', id: 'filter-field'
          text ' '
          submit_tag "Filter", class: 'btn btn-primary'
        end
      end
=end

      def translation_grid
        table class:         'table table-striped',
              id:            'translations',
              'data-url'     => translation_units_url(@translation_unit, format: 'json')
        #'data-locales' => @locales.to_json,
        #'data-locale'  => @project.base_rfc5646_locale
      end
    end
  end
end