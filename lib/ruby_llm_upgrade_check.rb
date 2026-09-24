# Lists what an app forked from this template must change for RubyLLM 2.0: code that calls removed
# 1.x APIs, and data the upgrade migrations would refuse. Run `bin/rails ruby_llm:upgrade_check`
# after merging the template and before `bin/rails db:migrate`; it should end with "nothing to fix".
class RubyLlmUpgradeCheck
  Finding = Data.define(:path, :line, :code, :fix, :severity)
  Rule = Data.define(:pattern, :fix, :severity, :only_in_files_matching)

  def self.rule(pattern, fix, severity = :blocker, only_in_files_matching: nil)
    Rule.new(pattern:, fix:, severity:, only_in_files_matching:)
  end

  SCAN_GLOBS = %w[app/**/*.{rb,erb} lib/**/*.{rb,rake} config/**/*.rb].freeze
  SKIP = %r{\A(db|vendor|test|spec|node_modules)/|\Alib/(ruby_llm_upgrade_check\.rb|tasks/ruby_llm_upgrade\.rake)\z}
  TOOL_FILE = /RubyLLM::Tool\b/

  RULES = [
    # App classes RubyLLM 2.0 replaced
    rule(/(?<!::)(?<![\w.])Model\.\w+[!?]?/, "RubyLLM::ActiveRecord::Model (app Model class removed); RubyLLM.models.refresh to refresh"),
    rule(/(?<!::)(?<![\w.])ToolCall\b/, "RubyLLM::ActiveRecord::ToolCall, or message.tool_calls (Hash of RubyLLM::ToolCall)"),
    rule(/\bacts_as_(model|tool_call)\b/, "delete the declaration and the class"),
    rule(/\b(tool_calls_foreign_key|chats_foreign_key|model_registry_class|model_registry_source|use_new_acts_as)\b/, "remove (acts_as_chat / acts_as_message defaults cover it)"),
    rule(/\bbelongs_to :model\b/, "remove: acts_as_chat defines belongs_to :model (FK ruby_llm_model_id, no counter cache)"),
    rule(/\bfrom_llm_attributes\b/, "removed; RubyLLM::ActiveRecord::Model.save_to_database writes registry rows (custom columns are not refreshed)"),
    rule(/\bRubyLLM\.models\.(refresh|load_from_database|load_from_json)!/, "RubyLLM.models.refresh / load_from_store / load_from_json"),
    rule(/\bRubyLLM::Models\.find\b|\bRubyLLM\.models\.find\([^)]*,\s*:/, "RubyLLM.models.find(id, provider: ...)"),
    rule(/\bRubyLLM::Model::Info\b/, "RubyLLM::Model"),
    rule(/\bsupports_(vision|functions|json_mode)\?/, "supports?(:vision | :function_calling | :structured_output)"),
    rule(/\b(input|output|cached_input)_price_per_million\b/, "model.price(:input | :output | :cache_read)"),

    # Chat API
    rule(/\bwith_params\(/, "with_provider_options(...)"),
    rule(/\bwith_tool\(/, "with_tools(...)"),
    rule(/\bwith_tools\([^)]*\b(choice|calls):/, "with_tools(...).with_tool_options(choice:, calls:)"),
    rule(/\bon_new_message\b/, "before_message"),
    rule(/\bon_end_message\b/, "after_message"),
    rule(/\bon_tool_call\b/, "before_tool_call"),
    rule(/\bon_tool_result\b/, "after_tool_result"),
    rule(/\bcreate_user_message\b/, "add_message(role: :user, content:) or ask_later"),
    rule(/\breset_messages!/, "chat.messages = []"),
    rule(/\bassume_exists:/, "assume_model_exists:"),
    rule(/\bwith_instructions\([^)]*replace:/, "with_instructions replaces by default; pass append: true to add"),
    rule(/\bresponse_format\b/, "OpenAI defaults to the Responses API: with_provider_options(text: { format: ... }), or config.openai_protocol = :chat_completions", :review),
    rule(/\.content\[["':]/, "structured output: response.parsed (content is now the JSON string)", :review),
    rule(/\bfinish_reason\s*==\s*["']/, "finish_reason is a Symbol (:stop, :max_tokens, :tool_calls, :content_filter)", :review),
    rule(/\bhalt\(/, "tools no longer halt; loop chat.step or use requires_approval", :review),

    # Tokens and cost
    rule(/\bRubyLLM::Tokens\.build\b/, "RubyLLM::Tokens.new(...)"),
    rule(/\bRubyLLM::Cost\.new\b/, "response.cost / message.cost (RubyLLM::Cost), or RubyLLM::Cost.from_h", :review),
    rule(/\b(?!ruby_llm_usages\b)\w+\.(input|output|cached|cache_creation|reasoning)_tokens\b/, "response.tokens.input / .output / .cache_read / .cache_write / .thinking (message token columns moved to ruby_llm_usages)", :review),
    rule(/\b(?:chat|user|team|model|record)\.total_cost\b|\bcost&\.(?:to_f|positive\?)|\bcost\.to_f\b/, "cost caches dropped: chat.cost / message.cost (RubyLLM::Cost#total) or .with_usage_cost", :review),
    rule(/counter_cache: :chats_count/, "models.chats_count dropped: count via RubyLLM::ActiveRecord::Model.with_usage_cost"),
    rule(/\bmessage\.model_id\b/, "message.model (String, from its usage)", :review),
    rule(/\b(?:chats|messages)\.sum\((?::total_cost|:cost)\)|\bsum\(&:(?:total_cost|cost)\)/, "cost columns dropped: sum ruby_llm_usages.total_cost, or .with_usage_cost", :review),
    rule(/SUM\((?:chats|users|models)\.total_cost\)|COALESCE\((?:input|output|cached|cache_creation)_tokens\b/, "SQL on dropped columns: aggregate ruby_llm_usages instead", :review),
    rule(/\bsortable :(?:total_cost|cost)\b/, "sort by usage_cost (with_usage_cost) instead of the dropped column", :review),
    rule(/\b(?:record|message|msg)\.cost\b(?![.&(])/, "message.cost is now a RubyLLM::Cost: use .total (or with_usage_cost for chats)", :review),
    rule(/\battribute :(?:cost|input_tokens|output_tokens|cached_tokens|cache_creation_tokens|tool_calls)\b/, "Madmin: these message columns moved; use :ruby_llm_usages / :ruby_llm_tool_calls",
      :review, only_in_files_matching: /class (?:Message|Chat)Resource\b/),

    # Tool calls moved to the gem's table
    rule(/\b(?:includes|preload|eager_load)\([^)]*(?<![\w])(?::|\b)tool_calls\b/, "association is now :ruby_llm_tool_calls"),
    rule(/\btool_calls\.each do \|/, "message.tool_calls is a Hash: tool_calls.each_value do |tool_call|"),

    # Tool DSL (only in RubyLLM::Tool subclasses; rake tasks use `desc` too)
    rule(/^\s*(desc|param|params_schema|provider_params)\b/, "Tool DSL: description / parameter / parameters_schema / provider_options", only_in_files_matching: TOOL_FILE),
    rule(/\bdesc:/, "tool parameter option: description:", only_in_files_matching: TOOL_FILE),
    rule(/\bRubyLLM::Schema\b/, "Schematist::Schema")
  ].freeze

  def initialize(root:, connection:)
    @root = Pathname(root)
    @connection = connection
  end

  def code_findings
    @code_findings ||= source_files.flat_map { |path| scan(path) }
  end

  # Only meaningful before migrating (1.x tables present); the upgrade migrations refuse these rows.
  def data_findings
    return [] unless table?(:models) && column?(:chats, :model_id)

    [
      empty_registry_finding,
      model_less_chats_finding,
      count_finding(:chats, "chats.model_id pointing at a missing model",
        "SELECT COUNT(*) FROM chats WHERE model_id IS NOT NULL AND model_id NOT IN (SELECT id FROM models)"),
      (count_finding(:tool_calls, "tool_calls without tool_call_id",
        "SELECT COUNT(*) FROM tool_calls WHERE tool_call_id IS NULL") if table?(:tool_calls)),
      (count_finding(:messages, "tool calls answered by more than one message",
        "SELECT COUNT(*) FROM (SELECT tool_call_id FROM messages WHERE tool_call_id IS NOT NULL " \
        "GROUP BY tool_call_id HAVING COUNT(*) > 1)") if column?(:messages, :tool_call_id))
    ].compact
  end

  def blockers? = (code_findings + data_findings).any? { _1.severity == :blocker }

  def report
    findings = code_findings + data_findings
    return "RubyLLM 2.0 upgrade check: nothing to fix." if findings.empty?

    lines = findings.sort_by { [ _1.severity == :blocker ? 0 : 1, _1.path, _1.line.to_i ] }.map do |f|
      "[#{f.severity}] #{[ f.path, f.line ].compact.join(':')}  #{f.code}\n          → #{f.fix}"
    end
    "RubyLLM 2.0 upgrade check: #{findings.count} finding(s)\n\n#{lines.join("\n")}"
  end

  private

  def source_files
    SCAN_GLOBS.flat_map { Dir.glob(_1, base: @root) }.uniq.reject { _1.match?(SKIP) }.sort
  end

  def scan(path)
    source = (@root / path).read
    source.each_line.with_index(1).flat_map do |text, line|
      next [] if text.lstrip.start_with?("#", "<%#")

      rule_findings(path, line, text, source) + error_constant_findings(path, line, text)
    end
  end

  def rule_findings(path, line, text, source)
    RULES.filter_map do |rule|
      next if rule.only_in_files_matching && !source.match?(rule.only_in_files_matching)
      match = text[rule.pattern] or next

      Finding.new(path:, line:, code: match.strip, fix: rule.fix, severity: rule.severity)
    end
  end

  def error_constant_findings(path, line, text)
    text.scan(/RubyLLM::\w*Error\b/).uniq.reject { RubyLLM.const_defined?(_1.delete_prefix("RubyLLM::")) }.map do |const|
      Finding.new(path:, line:, code: const, fix: "no such error class in RubyLLM 2.0", severity: :blocker)
    end
  end

  def count_finding(table, label, sql)
    count = @connection.select_value(sql).to_i
    return if count.zero?

    Finding.new(path: table.to_s, line: nil, code: "#{count} #{label}", fix: "repair before db:migrate", severity: :blocker)
  end

  # PrepareRubyLlmV2Data refuses to run without a registry row to attribute messages to.
  def empty_registry_finding
    return unless @connection.select_value("SELECT COUNT(*) FROM models").to_i.zero?

    Finding.new(path: "models", line: nil, code: "empty model registry",
      fix: "run `bin/rails ruby_llm:load_models` on the 1.x release before db:migrate", severity: :blocker)
  end

  # Informational: PrepareRubyLlmV2Data gives these chats Setting.default_model (or the most-used model).
  def model_less_chats_finding
    count = @connection.select_value("SELECT COUNT(*) FROM chats WHERE model_id IS NULL").to_i
    return if count.zero?

    Finding.new(path: "chats", line: nil, code: "#{count} chats without a model",
      fix: "db:migrate assigns Setting.default_model, falling back to the most-used model; set a default first to choose",
      severity: :review)
  end

  def table?(name) = @connection.table_exists?(name)
  def column?(table, name) = table?(table) && @connection.column_exists?(table, name)
end
