# Gives each mutant worker its own copy of the SQLite test database, so tests
# that write to it cannot trample one another. Adapted from mutant's
# docs/rails.md; the eager load lives in test/mutant/boot.rb.
worker_database_dir = File.join(Dir.pwd, "tmp/mutant")

hooks.register(:setup_integration_post) do
  ActiveRecord::Base.connection_pool.disconnect!
end

isolate_database = lambda do |index:|
  ActiveRecord::Base.connection_pool.disconnect!
  config = ActiveRecord::Base.connection_pool.db_config.configuration_hash
  template = config.fetch(:database)
  raise "Missing #{template}; run bin/rails db:test:prepare before mutant" unless File.file?(template)

  FileUtils.mkdir_p(worker_database_dir)
  isolated = File.join(worker_database_dir, "#{File.basename(template, ".*")}_mutant_worker_#{index}.sqlite3")
  FileUtils.cp(template, isolated)
  ActiveRecord::Base.establish_connection(config.merge(database: isolated))
end

hooks.register(:test_worker_process_start) { |index:| isolate_database.call(index:) }
hooks.register(:mutation_worker_process_start) { |index:| isolate_database.call(index:) }
