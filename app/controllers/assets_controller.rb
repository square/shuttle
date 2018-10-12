# Language: Ruby, Level: Level 3
class AssetsController < ApplicationController
  respond_to :json, only: [:create, :show, :update]
  respond_to :html, only: [:create, :show, :update, :new, :edit]

  before_filter :find_project
  before_filter :find_asset, only: [:show, :edit, :update, :issues, :show_in_dashboard, :hide_in_dashboard, :manifest]
  before_filter :reviewer_required, only: [:show_in_dashboard, :hide_in_dashboard]

  def show
    respond_with @asset do |format|
      format.json { render json: decorate(@asset).to_json }
    end
  end

  def new
    @asset = @project.assets.build
    respond_with @asset
  end

  def create
    @asset = @project.assets.create(params_for_create)

    if @asset.errors.blank?
      flash[:success] = 'Asset is successfuly created!'
    else
      flash.now[:alert] = ['Asset could not be created: '] + @asset.errors.full_messages
    end

    respond_with @asset, location: (project_asset_url(@project, @asset) if @asset.persisted? ) do |format|
      format.json do
        if @asset.errors.blank?
          render json: decorate_asset(@asset)
        else
          render json: { error: { errors: @asset.errors } }, status: :bad_request
        end
      end
    end
  end

  def edit
    respond_with @asset
  end

  def update
    _params_for_update = params_for_update # cache
    if @asset.loading? && Asset::FIELDS_THAT_REQUIRE_IMPORT_WHEN_CHANGED.any? do |field|
        # if there is a pending import or an import is in progress, and an import triggering field is trying to be changed
        _params_for_update.key?(field) && (_params_for_update[field] != @asset.send(field.to_sym))
      end
      @asset.errors.add(:base, :not_finished)
    else
      @asset.update(_params_for_update)
    end

    respond_with @asset do |format|
      format.html do
        if @asset.errors.blank?
          flash[:success] = 'Asset is successfuly updated!'
          redirect_to project_asset_url(@project, @asset)
        else
          flash.now[:alert] = ['Asset could not be updated:'] + @asset.errors.full_messages
          render 'assets/edit'
        end
      end

      format.json do
        if @asset.errors.blank?
          render json: decorate_asset(@asset)
        else
          render json: { error: { errors: @asset.errors } }, status: :bad_request
        end
      end
    end
  end

  def manifest
    begin
      @manifest = Exporter::Asset.new(@asset).export
    rescue Exporter::Asset::Error => @error
    end

    if @error
      flash[:alert] = 'An error has occured creating the manifest, please try again later.'
      redirect_to project_asset_path(@project, @asset)
    else
      # generate file
      send_data @manifest.read, filename: "#{@asset.file_name}.zip"
    end
  end

  def show_in_dashboard
    unless @asset.hidden
      redirect_to edit_project_asset_path(@project, @asset), flash: { alert: 'This asset state has been modified, please refresh and try again'}
    else
      @asset.update!(hidden: false)
      redirect_to edit_project_asset_path(@project, @asset), flash: { success: 'This asset is now showing on dashboard'}
    end
  end

  def hide_in_dashboard
    if @asset.hidden
      redirect_to edit_project_asset_path(@project, @asset), flash: { alert: 'This asset state has been modified, please refresh and try again'}
    else
      @asset.update!(hidden: true)
      redirect_to edit_project_asset_path(@project, @asset), flash: { success: 'This asset is now hidden from dashboard'}
    end
  end

private
  def find_project
    @project = Project.find_from_slug(params[:project_id])

    unless @project
      respond_with(nil) do |format|
        format.html { redirect_to root_path, alert: t('controllers.assets.project_not_found') }
        format.json { render json: { error: { errors: [{ message: t("controllers.assets.project_not_found") }] } }, status: :not_found }
      end
    end
  end

  def find_asset
    @asset = @project.assets.find(params[:id])

    unless @asset
      respond_with(nil) do |format|
        format.html { redirect_to root_path, alert: t("controllers.assets.asset_not_found") }
        format.json { render json: { error: { errors: [{ message: t("controllers.assets.asset_not_found") }] } }, status: :not_found }
      end
    end
  end


  def decorate_asset(asset)
    [
     :name, :project_id, :ready, :description, :email, :file_name,
     :base_rfc5646_locale, :targeted_rfc5646_locales,
     :approved_at, :created_at, :updated_at
    ].inject({}) do |hsh, field|
      hsh[field] = asset.send(field)
      hsh
    end
  end

  def params_for_create
    params_for_update.merge(params.require(:asset).permit(:base_rfc5646_locale))
  end

  def params_for_update
    hsh = params.require(:asset).permit(:name, :description, :email, :file, :file_name)

    if params[:asset].try(:key?, :targeted_rfc5646_locales)
      locales = {}
      params[:asset][:targeted_rfc5646_locales].each do |k,v|
        if k.class == String && !v
          locales.merge! JSON.parse(k.gsub('=>', ':'))
        else
          locales.merge! k => v
        end
      end
      hsh[:targeted_rfc5646_locales] = locales
    end

    hsh[:priority] = params[:asset][:priority] # default to nil
    hsh[:due_date] = DateTime::strptime(params[:asset][:due_date], "%m/%d/%Y") rescue '' if params[:asset].try(:key?, :due_date)
    hsh[:file_name] = File.basename(params[:asset][:file].original_filename, File.extname(params[:asset][:file].original_filename)) if params[:asset][:file].try(:original_filename)
    hsh.merge(user_id: current_user.try(:id))
  end
end
