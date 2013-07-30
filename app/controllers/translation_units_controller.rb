# Copyright 2013 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

# Controller where users can view, edit, and delete translation units

class TranslationUnitsController < ApplicationController
  before_filter :reviewer_required
  before_filter :find_translation_unit, only: [:edit, :update, :destroy]

  respond_to :html, :json

  TRANSLATION_UNITS_PER_PAGE = 50

  # Renders information about all translation units.
  #
  # Routes
  # -------
  #
  # * 'GET /translation_units'
  #
  # Path Parameters
  # ---------------
  #
  # |              |                                               |
  # |:-------------|:----------------------------------------------|
  # | 'offset'     | The offset used to display the next 50 results|
  def index
    @offset = params[:offset].to_i
    @offset = 0 if @offset < 0
    @previous = @offset > 0

    @translation_units = TranslationUnit
      .order('source_copy')
      .offset(@offset)
      .limit(TRANSLATION_UNITS_PER_PAGE)


    if params[:target_locales].present?
      @target_locales = params[:target_locales].split(',').map { |l| Locale.from_rfc5646(l.strip) }
      return head(:unprocessable_entity) unless @target_locales.all?
      @translation_units = @translation_units.where(rfc5646_locale: @target_locales.map(&:rfc5646))
    end

    method   = case params[:field]
                 when 'searchable_source_copy' then
                   :source_copy_query
                 else
                   :copy_query
               end

    tsc      = @locale ? SearchableField::text_search_configuration(@locale) : 'english'

    @translation_units = if params[:keyword].present?
                           @translation_units.send(method, params[:keyword], tsc)
                         else
                           @translation_units.where('FALSE')
                         end

    @next = (@translation_units.count == TRANSLATION_UNITS_PER_PAGE)
    @locales = if params[:locales].present?
                 params[:locales].split(',').map { |l| Locale.from_rfc5646 l }.compact
               else
                 []
               end

    respond_with (@translation_units) do |format|
      format.json { render json: decorate(@translation_units)}
      format.html
    end
  end

  # Edits a translation unit.
  #
  # Routes
  # ------
  #
  # * `GET /translation_unit/:id/edit`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                              |
  # |:-----|:-----------------------------|
  # | `id` | The id of a translation unit |
  #
  def edit
    respond_with @translation_unit
  end

  # Updates translation unit.
  #
  # Routes
  # ------
  #
  # * `PATCH /translation_unit/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                              |
  # |:-------------|:-----------------------------|
  # | `id`         | The id of a TranslationUnit. |
  #
  # Body Parameters
  # ---------------
  #
  # |                    |                                                |
  # |:-------------------|:-----------------------------------------------|
  # | `translation_unit` | Parameterized hash of TranslationUnit fields.  |

  def update
    @translation_unit.update_attributes translation_unit_params

    flash[:success] = t('controllers.translation_units.update.success')

    respond_with @translation_unit, location: translation_units_url
  end

  # Removes a translation unit.
  #
  # Routes
  # ------
  #
  # * `DELETE /translation_unit/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                                 |
  # |:-------------|:--------------------------------|
  # | `id`         | The id of a TranslationUnit.    |
  def destroy
    @translation_unit.destroy

    flash[:notice] = t('controllers.translation_units.destroy.success')

    respond_with @translation_unit
  end

  private

  def find_translation_unit
    @translation_unit = TranslationUnit.find(params[:id])
  end

  def translation_unit_params
    params.require(:translation_unit).permit(:copy)
  end

  def decorate(translation_units)
    translation_units.map do |translation_unit|
      translation_unit.as_json.merge(
          url: edit_translation_unit_url(translation_unit),
          source_locale_img_src: view_context.locale_image_path(translation_unit.source_locale),
          locale_img_src: view_context.locale_image_path(translation_unit.locale)
      )
    end
  end
end
