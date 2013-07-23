class TranslationUnitsController < ApplicationController
  before_filter :translator_required

  respond_to :html

  TRANSLATION_UNITS_PER_PAGE = 50

  def index
    @offset = params[:offset].to_i
    @offset = 0 if @offset < 0
    @previous = @offset > 0
    @translation_units = TranslationUnit.offset(@offset).limit(TRANSLATION_UNITS_PER_PAGE)
    @next = (@translation_units.count == TRANSLATION_UNITS_PER_PAGE)
    respond_with @translation_units
  end
end
