module Admin
  class CopiesController < BaseController
    def show
      @settings = SiteSetting.all_settings.slice(*SiteSetting::COPY_KEYS)
    end

    def update
      values = params.fetch(:copy, ActionController::Parameters.new).permit(*SiteSetting::COPY_KEYS).to_h
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
