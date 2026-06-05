module Admin
  class SectionsController < BaseController
    before_action :set_section, only: %i[edit update destroy toggle]

    def index
      @sections = Section.order(:page, :position, :id)
    end

    def new
      @section = Section.new(page: Section::PAGES.include?(params[:page]) ? params[:page] : "home")
    end

    def create
      @section = Section.new(section_params)
      if @section.save
        redirect_to admin_sections_path, notice: "Section created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @section.update(section_params)
        redirect_to admin_sections_path, notice: "Section updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @section.destroy
      redirect_to admin_sections_path, notice: "Section deleted.", status: :see_other
    end

    def toggle
      @section.update(visible: !@section.visible)
      redirect_to admin_sections_path, notice: "“#{@section.key}” is now #{@section.visible? ? "visible" : "hidden"}."
    end

    private

    def set_section
      @section = Section.find(params[:id])
    end

    def section_params
      params.require(:section).permit(:key, :page, :heading, :body, :visible, :position)
    end
  end
end
