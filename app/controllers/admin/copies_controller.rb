module Admin
  class CopiesController < BaseController
    def show
      @settings = SiteSetting.all_settings.slice(*SiteSetting::COPY_KEYS)
    end

    def update
      values = params.expect(copy: SiteSetting::COPY_KEYS).to_h
      raise ActionController::BadRequest if params[:copy].keys.intersection(SiteSetting::COPY_KEYS).size > values.size
      @records = values.map do |key, value|
        SiteSetting.find_or_initialize_by(key: key).tap { |record| record.value = value }
      end
      if @records.map(&:valid?).all?
        SiteSetting.transaction { @records.each(&:save!) }
        redirect_to admin_copy_path, notice: "Copy saved."
      else
        @settings = SiteSetting.all_settings.slice(*SiteSetting::COPY_KEYS).merge(values)
        render :show, status: :unprocessable_entity
      end
    end
  end
end
