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
  # The number of records to return by default.
  PER_PAGE = 50

  before_filter :reviewer_required
  before_filter :find_translation_unit, only: [:edit, :update, :destroy]

  respond_to :html, :json

  # Renders a filtered list of all translation units.
  #
  # Routes
  # -------
  #
  # * `GET /translation_units`
  #
  # Query Parameters
  # ----------------
  #
  # |              |                                               |
  # |:-------------|:----------------------------------------------|
  # | `offset`     | The offset used to display the next 50 results.|

  def index
    respond_with (@translation_units) do |format|
      format.json do
        @offset = params[:offset].to_i
        @offset = 0 if @offset < 0
        @previous = @offset > 0

        limit = params[:limit].to_i
        limit = PER_PAGE if limit < 1

        @translation_units = TranslationUnit.
            order('id DESC').
            offset(@offset).
            limit(limit)


        if params[:target_locales].present?
          @target_locales = params[:target_locales].split(',').map { |l| Locale.from_rfc5646(l.strip) }
          return head(:unprocessable_entity) unless @target_locales.all?
          @translation_units = @translation_units.where(rfc5646_locale: @target_locales.map(&:rfc5646))
        end

        method = case params[:field]
                   when 'searchable_source_copy' then
                     :source_copy_query
                   else
                     :copy_query
                 end

        @translation_units = if params[:keyword].present?
                               @translation_units.send(method, params[:keyword])
                             else
                               @translation_units.where('FALSE')
                             end

        render json: decorate(@translation_units)
      end

      format.html
    end
  end

  # Displays a page where a user can edit a translation unit.
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
  # | `id` | The ID of a TranslationUnit. |
  #
  def edit
    respond_with @translation_unit
  end

  # Updates a translation unit with values in the body parameters.
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
  # | `id`         | The ID of a TranslationUnit. |
  #
  # Body Parameters
  # ---------------
  #
  # |                    |                                                |
  # |:-------------------|:-----------------------------------------------|
  # | `translation_unit` | Parameterized hash of TranslationUnit fields.  |

  def update
    @translation_unit.update_attributes translation_unit_params
    flash[:success] = t('controllers.translation_units.update.success') if @translation_unit.valid?
    respond_with @translation_unit, location: translation_units_url
  end

  # Deletes a translation unit.
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
  # | `id`         | The ID of a TranslationUnit.    |

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
          url:                edit_translation_unit_url(translation_unit),
          source_locale_flag: view_context.locale_image_path(translation_unit.source_locale),
          locale_flag:        view_context.locale_image_path(translation_unit.locale)
      )
    end
  end
end
