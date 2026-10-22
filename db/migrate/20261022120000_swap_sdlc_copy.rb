# Puts the wording the owner approved on 2026-10-22 on the live site: in each
# named field, every exact occurrence of the approved old fragment becomes the
# new one, and the text around it stays. A field without the exact fragment
# (rewritten in the admin, blank, or missing) is left alone, and nothing is
# created: a tagline never saved in the admin is already the new default.
# Only the field is written, not its timestamp. Each target is logged as
# swapped or skipped, so the deploy log shows which fields matched.
class SwapSdlcCopy < ActiveRecord::Migration[8.1]
  class Section < ActiveRecord::Base
    self.table_name = "sections"
  end

  class Setting < ActiveRecord::Base
    self.table_name = "site_settings"
  end

  SECTIONS = {
    [ "home_what_i_do", "body" ] => [
      "I build the systems that let agents build good software: plans and context, orchestration, and the verification that makes the output trustworthy.",
      "I automate the software development lifecycle (SDLC) with agents: plans and context, orchestration, review, and the verification that makes the output trustworthy." ],
    [ "home_what_i_do", "body_es" ] => [
      "Construyo los sistemas que permiten a los agentes construir buen software: planes y contexto, orquestación, y la verificación que hace confiable el resultado.",
      "Automatizo el ciclo de vida del desarrollo de software (SDLC) con agentes: planes y contexto, orquestación, revisión, y la verificación que hace confiable el resultado." ],
    [ "contact_intro", "body" ] => [ "and automate SDLC.", "and automating their SDLC." ],
    [ "about_bio", "body" ] => [ "Buenos Aires Argentina (GMT-3)", "Buenos Aires, Argentina (GMT-3)" ]
  }.freeze

  SETTINGS = {
    [ "tagline", "value" ] => [
      "Senior Software Engineer. I build the systems that let agents build good software.",
      "Senior Software Engineer. I build the systems that let agents build good software, across the whole SDLC." ],
    [ "tagline_es", "value" ] => [
      "Ingeniero de software senior. Construyo los sistemas que permiten a los agentes construir buen software.",
      "Ingeniero de software senior. Construyo los sistemas que permiten a los agentes construir buen software, en todo el ciclo de desarrollo." ]
  }.freeze

  def up
    { Section => SECTIONS, Setting => SETTINGS }.each do |model, swaps|
      model.reset_column_information
      swaps.each do |(key, field), (old, new)|
        row = model.find_by(key: key)
        swapped = row.present? && row[field].to_s.include?(old)
        row.update_columns(field => row[field].gsub(old, new)) if swapped
        say "#{key}.#{field} #{swapped ? 'swapped' : 'skipped'}", true
      end
    end
  end

  def down
  end
end
