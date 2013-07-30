# encoding: utf-8

require Rails.root.join('app', 'views', 'layouts', 'application.html.rb')

module Views
  module TranslationUnits
    class Edit <Views::Layouts::Application

      needs :translation_unit

      protected

      def body_content
        article(class: 'container') do
          ul(class: 'nav nav-tabs') do
            li { a "Translations", href: search_translations_url }
            li { a "Keys", href: search_keys_url }
            li(class: 'active') { a "Translation Memory", href: translation_units_url }
          end
          div(class: 'tab-content') do
            div(class: 'row-fluid') do
              div(class: 'span6') { translation_side }
              div(class: 'span6') { information_side }
            end
          end
        end
      end

      def active_tab() 'search' end

      private

      def translation_side
        h3 @translation_unit.locale.name
        form_for @translation_unit do |f|
          f.text_area :copy, class: 'span12'

          div(class: 'form-actions') do
            f.submit class: 'btn btn-primary'
            button_to 'Delete', translation_unit_url(@translation_unit),
                      'data-method'  => :delete,
                      id:            'delete_button',
                      'data-confirm' => 'Do you really want to delete this translation unit?',
                      class:         'btn btn-danger pull-right'
          end
        end
      end

      def information_side
        h3 @translation_unit.source_locale.name
        pre @translation_unit.source_copy, id: 'source-copy'
      end
    end
  end
end
