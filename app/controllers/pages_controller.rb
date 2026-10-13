class PagesController < SiteController
  def about
    @sections = Section.for_page("about").visible.ordered
  end

  def work
    @sections = Section.for_page("work").visible.ordered
  end

  def consulting
    @sections = Section.for_page("consulting").visible.ordered
  end

  def contact
    @sections = Section.for_page("contact").visible.ordered
  end
end
