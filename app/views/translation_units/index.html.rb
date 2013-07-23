# encoding: utf-8

require Rails.root.join('app', 'views', 'layouts', 'application.html.rb')

module Views
  module TranslationUnits
    class Index <Views::Layouts::Application

      needs :translation_units, :offset, :previous, :next#, :locales

      protected

      def body_content
        article(class: 'container') do
          page_header do
            h1 "All Translations"
          end
          #filter_bar
          translation_grid
          pagination_links
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
        table(class:'table table-striped', id:'translation_units') do
          thead do
            tr do
              th "Source", colspan: 3
              th "Target", colspan: 3
            end
          end

          tbody do
            @translation_units.each do |trans_unit|
              tr do
                td trans_unit.source_locale.rfc5646
                td { image_tag(locale_image_path(trans_unit.source_locale), style: 'max-width: inherit') }
                td trans_unit.source_copy
                td trans_unit.locale.rfc5646
                td { image_tag(locale_image_path(trans_unit.locale), style: 'max-width: inherit') }
                td trans_unit.copy
              end
            end
          end
        end
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