# Copyright 2014 Square Inc.
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

# Controller for working with {LocaleAssociation LocaleAssociations}.

class LocaleAssociationsController < ApplicationController
  before_filter :translator_required
  before_filter :set_locale_association, only: [:edit, :update, :destroy]

  # Returns a list of LocaleAssociations.
  #
  # Routes
  # ------
  #
  # * `GET /locale_associations`

  def index
    @locale_associations = LocaleAssociation.all
  end

  # Displays a form where translators can add a Locale Association.
  #
  # Routes
  # ------
  #
  # * `GET /locale_associations/new`

  def new
    @locale_association = LocaleAssociation.new
  end

  # Displays a form where an admin can edit a Locale Association.
  #
  # Routes
  # ------
  #
  # * `GET /locale_associations/:id/edit`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                              |
  # |:-----|:-----------------------------|
  # | `id` | A LocaleAssociation's slug. |
  def edit
  end

  # Creates a new Locale Association.
  #
  # Routes
  # ------
  #
  # * `POST /locale_associations`
  #
  # Body Parameters
  # ---------------
  #
  # |                      |                                                      |
  # |:---------------------|------------------------------------------------------|
  # | `locale_association` | Parameterized hash of LocaleAssociation information. |

  def create
    @locale_association = LocaleAssociation.new(locale_association_params)

    if @locale_association.save
      redirect_to edit_locale_association_path(@locale_association), notice: 'Locale association was successfully created.'
    else
      flash.now[:alert] = @locale_association.errors.full_messages.unshift('Errors occured during create:')
      render action: 'new'
    end
  end

  # Updates a LocaleAssociation with new information.
  #
  # Routes
  # ------
  #
  # * `PATCH /locale_association/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                             |
  # |:-----|:----------------------------|
  # | `id` | A LocaleAssociation's slug. |
  #
  # Body Parameters
  # ---------------
  #
  # |                      |                                                      |
  # |:---------------------|------------------------------------------------------|
  # | `locale_association` | Parameterized hash of LocaleAssociation information. |

  def update
    if @locale_association.update(locale_association_params)
      redirect_to edit_locale_association_path(@locale_association), notice: 'Locale association was successfully updated.'
    else
      flash.now[:alert] = @locale_association.errors.full_messages.unshift('Errors occured during update:')
      render action: 'edit'
    end
  end

  # Deletes a LocaleAssociation.
  #
  # Routes
  # ------
  #
  # * `DELETE /locale_association/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                             |
  # |:-----|:----------------------------|
  # | `id` | A LocaleAssociation's slug. |

  def destroy
    @locale_association.destroy
    redirect_to locale_associations_url, notice: 'Locale association was successfully destroyed.'
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_locale_association
    @locale_association = LocaleAssociation.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def locale_association_params
    params.require(:locale_association).permit(:source_rfc5646_locale, :target_rfc5646_locale, :checked, :uncheck_disabled)
  end
end
