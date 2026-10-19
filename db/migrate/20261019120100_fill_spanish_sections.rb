# Puts the drafted Spanish (db/seeds/sections_es.yml) on the sections the
# seeds created, by key, one field at a time and only where that field is
# still blank. English is never touched, and Spanish already written in the
# admin stays as written.
class FillSpanishSections < ActiveRecord::Migration[8.1]
  class Section < ActiveRecord::Base
    self.table_name = "sections"
  end

  def up
    Section.reset_column_information
    YAML.load_file(Rails.root.join("db/seeds/sections_es.yml")).each do |key, spanish|
      section = Section.find_by(key: key) or next
      section.update!(spanish.select { |field, _| section[field].blank? })
    end
  end

  def down
  end
end
