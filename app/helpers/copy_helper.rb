module CopyHelper
  def copy_lang(key)
    "en" if SiteSetting.untranslated?(key)
  end

  def copy_text(key)
    text = marked(SiteSetting.localized(key))
    token = SiteSetting::COPY_LINKS[key]
    return text unless token

    # marked escapes all author text before drawing marks. Replace only the
    # literal placeholder with a generated anchor, keeping marks around it.
    text.gsub(token) { copy_link(key) }.html_safe
  end

  def copy_link(key)
    if key == "footer_pitch"
      locale = SiteSetting.untranslated?(key) ? :en : I18n.locale
      link_to(t("footer.consulting", locale: locale), consulting_path)
    else
      link_to("LinkedIn", SiteSetting["linkedin_url"], target: "_blank", rel: "noopener")
    end
  end
end
