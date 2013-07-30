# encoding: utf-8

require Rails.root.join('app', 'views', 'layouts', 'application.html.rb')

module Views
  module TranslationUnits
    class Index <Views::Layouts::Application

      needs :translation_units, :offset, :previous, :next, :locales

      protected

      def body_content
        article(class: 'container') do
          page_header do
            h1 "All Translations"
          end
          filter_bar
          translation_grid
          pagination_links
        end
      end

      def active_tab() 'translator' end

      private

      def filter_bar
        form_tag(translation_units_url, method: 'GET', id: 'translation-units-search-form', class: 'filter form-inline') do
          text 'Find '
          text_field_tag 'keyword', '', id: 'search-field', placeholder: 'keyword'
          text ' in '
          select_tag 'field', options_for_select([
                                                     %w(source searchable_source_copy),
                                                     %w(translation searchable_copy),
                                                 ]), id: 'field-select', class: 'span2'
          text ' with translation in '
          if current_user.approved_locales.any?
            select_tag 'target_locales', options_for_select(current_user.approved_locales.map { |l| [l.name, l.rfc5646] })
          else
            text_field_tag 'target_locales', '', class: 'locale-field locale-field-list span2', id: 'locale-field', placeholder: "any target locale"
          end
          text ' '
          submit_tag "Search", class: 'btn btn-primary'
        end
      end

      def translation_grid
        table(class:'table table-striped table-hover', id:'translation_units', 'data-url' => translation_units_url(format: 'json'))
      end

      def pagination_links
        p do
          if @previous
            link_to "« previous", url_for(request.query_parameters.merge('offset' => @offset - 50))
          end
          text ' '
          if @next
            link_to "next »", url_for(request.query_parameters.merge('offset' => @offset + 50))
          end
        end
      end
    end
  end
end