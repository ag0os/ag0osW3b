# Selection completeness, independent of the survivor gate. See CI-13 to CI-16.
require "date"
require "pathname"
require "yaml"
require "rubocop"
require_relative "../mutant/floor"

module MutantCompleteness
  ACCEPTED = "test/mutant/selection_accepted.yml"
  CONTROLLER_CAP = 100
  FRONTEND = { ".erb" => "ERB templates", ".builder" => "Builder templates", ".js" => "JavaScript", ".css" => "CSS" }.freeze
  SUFFIXES = [ ".rb", ".rake", *FRONTEND.keys ].freeze
  Scope = Data.define(:name, :node, :methods, :namespace)

  module_function

  def candidate?(path)
    path.match?(%r{\A(?:app|lib)/}) && SUFFIXES.include?(File.extname(path))
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
    unless document.is_a?(Hash) && document.keys == [ "paths" ] && document["paths"].is_a?(Array)
      raise ArgumentError, "must be a mapping containing only a paths list"
    end
    document["paths"]
  end

  def acceptance_problem(entry)
    return [ "#{ACCEPTED}: entry must contain only path, on and reason" ] unless entry.is_a?(Hash) && entry.keys.sort == %w[on path reason]

    path, on, reason = entry.values_at("path", "on", "reason")
    problems = []
    unless path.is_a?(String) && candidate?(path) && path.split("/", -1).all? { |part| part.match?(/\A[\w.-]+\z/) && !%w[. ..].include?(part) }
      problems << "#{ACCEPTED}: needs an exact app/ or lib/ code path"
    end
    problems << "#{ACCEPTED}: needs a nonblank reason" unless reason.is_a?(String) && !reason.strip.empty?
    begin
      raise ArgumentError unless on.is_a?(String) && on.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      Date.iso8601(on)
    rescue ArgumentError
      problems << "#{ACCEPTED}: needs a real ISO date in on"
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
    [ [], [ "accepted: #{path} on #{entry["on"]}: #{entry["reason"]}" ] ] if entry
  end

  def controller?(path, scopes, outside)
    path.match?(%r{\Aapp/controllers/(?!concerns/).+_controller\.rb\z}) && !outside && scopes.any? &&
      scopes.all? { |scope| scope.namespace || (scope.node.class_type? && scope.name.end_with?("Controller")) }
  end

  def check_scopes(path, scopes, reached)
    problems, reports = [], []
    scopes.reject(&:namespace).each do |scope|
      if reached.fetch(scope.name, []).include?(path)
        reports << "reached: #{path}: #{scope.name} (per constant, not per method)"
      elsif !scope.methods
        reports << "tool limit: #{path}: #{scope.name} has only declarations or Rails macros, no ordinary method body"
      else
        problems << "#{path}: #{scope.name} is unreached; list the subject in config/mutant.yml or add a dated acceptance in #{ACCEPTED}"
      end
    end
    [ problems, reports ]
  end

  def method_body?(node)
    node.def_type? || node.defs_type? || (node.send_type? && %i[define_method define_singleton_method].include?(node.method_name))
  end

  # Namespace-only modules do not claim executable reach from their children.
  # Definitions inside DSL blocks still belong to their enclosing constant.
  def declarations(ast)
    scopes, outside = [], false
    visit = lambda do |node, nesting, current|
      next unless node.is_a?(RuboCop::AST::Node)

      if node.class_type? || node.module_type?
        name = node.children.first.source
        name = name.delete_prefix("::") if name.start_with?("::")
        name = "#{nesting}::#{name}" if !node.children.first.source.start_with?("::") && !nesting.empty?
        body = node.body
        children = body&.begin_type? ? body.children : [ body ].compact
        namespace = node.module_type? && children.any? && children.all? { |child| child.class_type? || child.module_type? }
        index = scopes.size
        scopes << Scope.new(name:, node:, methods: false, namespace:)
        visit.call(body, name, index)
      elsif (node.casgn_type? || (node.send_type? && node.method_name == :const_set)) && node.each_descendant.any? { |child| method_body?(child) }
        # A dynamically constructed constant cannot borrow its enclosing
        # constant's reach. Its body needs an explicit path acceptance.
        outside = true
      elsif method_body?(node)
        if current
          scopes[current] = scopes[current].with(methods: true)
        else
          outside = true
        end
      else
        outside = true if current.nil? && !node.begin_type? && !(node.send_type? && %i[require require_relative].include?(node.method_name))
        # Arguments to load directives do not constitute independent code.
        next if current.nil? && node.send_type? && %i[require require_relative].include?(node.method_name)

        node.each_child_node { |child| visit.call(child, nesting, current) }
      end
    end
    visit.call(ast, "", nil)
    [ scopes, outside ]
  end
end
