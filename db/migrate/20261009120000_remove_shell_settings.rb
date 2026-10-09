class RemoveShellSettings < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM site_settings WHERE key IN ('shell_opening', 'shell_whoami', 'shell_whoami_es')"
  end

  def down
  end
end
