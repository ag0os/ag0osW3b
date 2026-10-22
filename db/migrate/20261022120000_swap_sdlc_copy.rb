# Puts the four sentences the owner approved on 2026-10-22 on the live site:
# in each named field, the old sentence becomes the new one, and only where the
# field still holds the old one. A sentence the owner has since rewritten in
# the admin stays as written, and nothing is created: a tagline never saved in
# the admin is already the new default.
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
        next unless row && row[field].to_s.include?(old)

        row.update!(field => row[field].gsub(old, new))
      end
    end
  end

  def down
  end
end
