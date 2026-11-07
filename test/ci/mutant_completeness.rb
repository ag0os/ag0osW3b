# Selection completeness, independent of the survivor gate. See CI-13 to CI-16.
require "date"
require "pathname"
require "yaml"
require "rubocop"
require_relative "../mutant/floor"

module MutantCompleteness
  ACCEPTED = "test/mutant/selection_accepted.yml"
  CONTROLLER_CAP = 100
  FRONTEND = { ".erb" => "ERB templates", ".builder" => "Builder templates", ".jbuilder" => "Jbuilder templates", ".js" => "JavaScript", ".css" => "CSS" }.freeze
  NON_CODE = %w[.woff .woff2 .ttf .otf .png .jpg .jpeg .gif .webp .avif .svg .ico .md .keep].freeze
  EVALUATIONS = %i[class_eval module_eval class_exec module_exec instance_eval instance_exec].freeze
  DEFINITIONS = %i[define_method define_singleton_method].freeze
  # Closed names, not open-ended before_*, validates_* or association guesses.
  RAILS_MACROS = %i[
    scope validate validates validates! validates_each validates_with
    validates_absence_of validates_acceptance_of validates_associated validates_comparison_of
    validates_confirmation_of validates_exclusion_of validates_format_of validates_inclusion_of
    validates_length_of validates_numericality_of validates_presence_of validates_size_of validates_uniqueness_of
    before_validation after_validation before_save around_save after_save
    before_create around_create after_create before_update around_update after_update
    before_destroy around_destroy after_destroy before_commit after_commit after_rollback
    after_create_commit after_update_commit after_destroy_commit after_save_commit after_touch after_find after_initialize
    before_action after_action around_action before_enqueue after_enqueue around_enqueue
    before_perform after_perform around_perform included class_methods prepended
    belongs_to has_one has_many has_and_belongs_to_many normalizes enum delegate
  ].freeze
  Scope = Data.define(:name, :node, :methods, :namespace)

  module_function

  def candidate?(path)
    path.match?(%r{\A(?:app|lib)/}) && File.basename(path) != ".keep" && !NON_CODE.include?(File.extname(path))
  end

  def listed(output, success)
    subjects = MutantFloor.selection(output) if success
    unless subjects && subjects.uniq.size == subjects.size && subjects.all? { |subject| subject.match?(/\A[A-Z]\w*(?:::[A-Z]\w*)*[#.].+\z/) }
      raise ArgumentError, "mutant could not list the subjects config/mutant.yml selects"
    end
    subjects
  end

  # Called in a separate Rails process, after eager loading. A lookup failure
  # is an error, never an empty inventory that a controller exemption can hide.
  def locations(subjects, root:)
    subjects.each_with_object({}) do |subject, reached|
      constant, separator, name = subject.partition(/[#.]/)
      owner = Object.const_get(constant)
      method = separator == "#" ? owner.instance_method(name) : owner.method(name)
      file, = method.source_location
      raise ArgumentError, "no source location for #{subject}" unless file

      relative = Pathname.new(File.expand_path(file)).relative_path_from(Pathname.new(root.to_s)).to_s
      (reached[constant] ||= []) << relative
    end.transform_values(&:uniq)
  end

  def acceptances(text, before)
    head = acceptance_document(text)
    base = acceptance_document(before)
    problems = head.flat_map { |entry| acceptance_problem(entry) }
    problems << "#{ACCEPTED} edits or removes an existing entry; append instead" unless head.first(base.size) == base
    problems << "#{ACCEPTED} repeats a path" unless head.map { |entry| entry["path"] if entry.is_a?(Hash) }.uniq.size == head.size
    [ head, problems ]
  rescue ArgumentError, Psych::Exception => error
    [ [], [ "#{ACCEPTED}: #{error.message}" ] ]
  end

  def acceptance_document(text)
    return [] if text.nil?

    document = YAML.safe_load(text)
    validate_keys!(document) if document.is_a?(Hash)
    unless document.is_a?(Hash) && document.keys == [ "paths" ] && document["paths"].is_a?(Array)
      raise ArgumentError, "must be a mapping containing only a paths list"
    end
    document["paths"]
  end

  def validate_keys!(mapping)
    bad = mapping.keys.reject { |key| key.is_a?(String) }
    raise ArgumentError, "non-String key #{bad.first.inspect}" if bad.any?
  end

  def acceptance_problem(entry)
    validate_keys!(entry) if entry.is_a?(Hash)
    return [ "#{ACCEPTED}: entry must contain only path, date and reason" ] unless entry.is_a?(Hash) && entry.keys.sort == %w[date path reason]

    path, date, reason = entry.values_at("path", "date", "reason")
    problems = []
    unless path.is_a?(String) && candidate?(path) && path.split("/", -1).all? { |part| part.match?(/\A[\w.-]+\z/) && !%w[. ..].include?(part) }
      problems << "#{ACCEPTED}: needs an exact app/ or lib/ code path"
    end
    problems << "#{ACCEPTED}: needs a nonblank reason" unless reason.is_a?(String) && !reason.strip.empty?
    begin
      raise ArgumentError unless date.is_a?(String) && date.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      Date.iso8601(date)
    rescue ArgumentError
      problems << "#{ACCEPTED}: needs a real ISO date in date"
    end
    problems
  end

  def check(path, text, reached:, accepted:)
    return [ [], [] ] unless candidate?(path)
    acceptance = accepted_result(path, accepted)
    if FRONTEND.key?(File.extname(path))
      return [ [], [ "tool limit: #{path}: #{FRONTEND.fetch(File.extname(path))} have no Ruby method subjects", *acceptance&.last ] ]
    end

    if File.extname(path) == ".rake"
      return acceptance || [ [ "#{path}: Rake task DSL is not verified by mutant; add a dated acceptance in #{ACCEPTED}" ], [] ]
    end

    unless File.extname(path) == ".rb"
      return acceptance || [ [ "#{path}: unknown code type; add a dated acceptance in #{ACCEPTED}" ], [] ]
    end

    source = RuboCop::ProcessedSource.new(text, 4.0, path)
    return [ [ "#{path}: Ruby parse failed" ], [] ] unless source.valid_syntax?

    scopes, outside = declarations(source.ast)
    return acceptance if acceptance
    return [ [ "#{path}: unattributed Ruby code; add a dated acceptance in #{ACCEPTED}" ], [] ] if outside

    reports = []
    if controller?(path, scopes, outside)
      size = controller_size(source, scopes)
      return [ [], [ "controller exemption: #{path}: #{size}/#{CONTROLLER_CAP} lines" ] ] if size <= CONTROLLER_CAP
      reports << "controller over cap: #{path}: #{size}/#{CONTROLLER_CAP} lines; ordinary reach rules apply"
    end

    problems, findings = check_scopes(path, scopes, reached)
    [ problems, reports + findings ]
  end

  def controller_size(source, scopes)
    roots = source.ast.begin_type? ? source.ast.children : [ source.ast ]
    loads = roots.reject { |node| node.class_type? || node.module_type? }
    (scopes.map(&:node) + loads).sum do |node|
      RuboCop::Cop::Metrics::Utils::CodeLengthCalculator.new(node, source).calculate
    end
  end

  def accepted_result(path, accepted)
    entry = accepted.find { |item| item["path"] == path }
    [ [], [ "accepted: #{path} on #{entry["date"]}: #{entry["reason"]}" ] ] if entry
  end

  def controller?(path, scopes, outside)
    path.match?(%r{\Aapp/controllers/(?!concerns/).+_controller\.rb\z}) && !outside && scopes.any? &&
      scopes.all? { |scope| scope.namespace || (scope.node.class_type? && scope.name.end_with?("Controller") &&
        scope.node.parent_class&.const_type? && scope.node.parent_class.source.end_with?("Controller")) }
  end

  def check_scopes(path, scopes, reached)
    problems, reports = [], []
    scopes.reject(&:namespace).each do |scope|
      if reached.fetch(scope.name, []).include?(path)
        reports << "reached: #{path}: #{scope.name} (per constant, not per method)"
      elsif !scope.methods
        reports << "tool limit: #{path}: #{scope.name} has no ordinary definitions or executable blocks outside the closed Rails macro list"
      else
        problems << "#{path}: #{scope.name} is unreached; list the subject in config/mutant.yml or add a dated acceptance in #{ACCEPTED}"
      end
    end
    [ problems, reports ]
  end

  def method_call?(node) = node.send_type? || node.csend_type?

  def self_receiver?(node) = node.nil? || node.self_type?

  def rails_macro?(node)
    node.send_type? && self_receiver?(node.receiver) && RAILS_MACROS.include?(node.method_name)
  end

  def method_body?(node)
    node.def_type? || node.defs_type? || (method_call?(node) && DEFINITIONS.include?(node.method_name))
  end

  def reflective_code?(node)
    method_call?(node) && %i[send public_send].include?(node.method_name) && node.first_argument&.sym_type? &&
      [ *DEFINITIONS, *EVALUATIONS, :eval ].include?(node.first_argument.value)
  end

  def string_eval?(node)
    method_call?(node) && [ :eval, *EVALUATIONS ].include?(node.method_name) && node.arguments.any?
  end

  def foreign_definition?(node)
    (node.defs_type? && !node.children.first.self_type?) ||
      (method_call?(node) && DEFINITIONS.include?(node.method_name) && !self_receiver?(node.receiver)) ||
      (%i[block numblock itblock].include?(node.type) && method_call?(node.children.first) &&
        EVALUATIONS.include?(node.children.first.method_name) && !self_receiver?(node.children.first.receiver))
  end

  # Namespaces do not borrow reach from children. A macro argument may contain
  # a callable, but its body is inspected without inheriting that permission.
  def declarations(ast)
    scopes, outside = [], false
    executable = lambda do |current|
      if current
        scopes[current] = scopes[current].with(methods: true)
      else
        outside = true
      end
    end
    visit = lambda do |node, nesting, current, macro_argument = false|
      next unless node.is_a?(RuboCop::AST::Node)

      if foreign_definition?(node)
        outside = true
      elsif node.class_type? || node.module_type?
        name = node.children.first.source
        name = name.delete_prefix("::") if name.start_with?("::")
        name = "#{nesting}::#{name}" if !node.children.first.source.start_with?("::") && !nesting.empty?
        body = node.body
        children = body&.begin_type? ? body.children : [ body ].compact
        namespace = node.module_type? && children.any? && children.all? { |child| child.class_type? || child.module_type? }
        index = scopes.size
        scopes << Scope.new(name:, node:, methods: false, namespace:)
        visit.call(body, name, index)
      elsif (node.casgn_type? || (method_call?(node) && node.method_name == :const_set)) && node.each_descendant.any? { |child| method_body?(child) }
        outside = true
      elsif %i[block numblock itblock].include?(node.type)
        call = node.children.first
        callable_argument = macro_argument && call.send_type? && self_receiver?(call.receiver) && %i[lambda proc].include?(call.method_name)
        executable.call(current) unless rails_macro?(call) || callable_argument
        node.each_child_node { |child| visit.call(child, nesting, current) }
      elsif method_body?(node) || reflective_code?(node) || string_eval?(node)
        executable.call(current)
        node.each_child_node { |child| visit.call(child, nesting, current) }
      else
        outside = true if current.nil? && !node.begin_type? && !(method_call?(node) && %i[require require_relative].include?(node.method_name))
        next if current.nil? && method_call?(node) && %i[require require_relative].include?(node.method_name)

        node.each_child_node { |child| visit.call(child, nesting, current, macro_argument || rails_macro?(node)) }
      end
    end
    visit.call(ast, "", nil)
    [ scopes, outside ]
  end
end
