module ShellHelper
  # Pages the shell can `open`, by the name a visitor types. Shell::OPENABLE
  # lists the same names; test/services/shell_test.rb keeps the two in step.
  def shell_pages
    {
      "home"    => root_path,
      "about"   => about_path,
      "work"    => work_path,
      "writing" => posts_path,
      "contact" => contact_path
    }
  end

  # The strings the browser prints for the commands it answers itself.
  # Interpolation markers are left in for the controller to fill.
  def shell_strings
    I18n.t("shell.client").merge(
      presets: SiteSetting::PRESETS.join(", ")
    )
  end
end
