require "test_helper"
require "ruby_llm_upgrade_check"

class RubyLlmUpgradeCheckTest < ActiveSupport::TestCase
  setup { @root = Pathname(Dir.mktmpdir) }
  teardown { FileUtils.rm_rf(@root) }

  test "flags removed chat APIs with their replacement" do
    write "app/models/concerns/summaries.rb", <<~RUBY
      chat = RubyLLM.chat(model: m).with_params(store: false)
      provider = RubyLLM::Models.find(model_id).provider
    RUBY

    findings = check.code_findings.map { [ _1.path, _1.line, _1.fix ] }

    assert_includes findings, [ "app/models/concerns/summaries.rb", 1, "with_provider_options(...)" ]
    assert_includes findings, [ "app/models/concerns/summaries.rb", 2, "RubyLLM.models.find(id, provider: ...)" ]
  end

  test "flags the deleted app Model class but not the gem class" do
    write "app/models/post.rb", "Model.resolve(id)\nRubyLLM::ActiveRecord::Model.enabled\n"

    assert_equal [ 1 ], check.code_findings.map(&:line)
  end

  test "flags RubyLLM error classes that no longer exist" do
    write "app/jobs/a_job.rb", "retry_on RubyLLM::RateLimitError, RubyLLM::NoSuchThingError\n"

    assert_equal [ "RubyLLM::NoSuchThingError" ], check.code_findings.map(&:code)
  end

  test "flags token readers that moved to response.tokens" do
    write "app/jobs/b_job.rb", "count = response.input_tokens\n"

    assert_equal [ :review ], check.code_findings.map(&:severity)
  end

  test "flags 1.x cost, token and tool-call patterns the upgrade had to change" do
    lines = [
      %(@chat = chats.includes(messages: [ :tool_calls, :attachments ]).find(id)),
      %(super.includes(:model, :tool_calls, chat: :messages)),
      %(<% message.tool_calls.each do |tool_call| %>),
      %(chats.sum(:total_cost)),
      %(chat.messages.sum(:cost)),
      %(<% cost = record.chats.sum(&:total_cost) %>),
      %(.order(Arel.sql("SUM(chats.total_cost) DESC"))),
      %(Message.sum("COALESCE(input_tokens, 0) + COALESCE(cached_tokens, 0)")),
      %(<th><%= sortable :total_cost, t(".col_cost") %></th>),
      %(<td><%= format_cost(record.cost || 0) %></td>)
    ]
    write "app/mixed.html.erb", lines.join("\n") + "\n"
    write "app/madmin/resources/message_resource.rb", "class MessageResource < Madmin::Resource\n  attribute :input_tokens\n  attribute :cost\nend\n"
    write "app/madmin/resources/ai_cost_resource.rb", "class AiCostResource < Madmin::Resource\n  attribute :input_tokens\nend\n"

    flagged = check.code_findings.group_by(&:path).transform_values { |fs| fs.map(&:line).uniq }

    assert_equal (1..lines.size).to_a, flagged["app/mixed.html.erb"]
    assert_equal [ 2, 3 ], flagged["app/madmin/resources/message_resource.rb"]
    assert_nil flagged["app/madmin/resources/ai_cost_resource.rb"]
  end

  test "ignores comments, db/, vendor/ and tests" do
    write "app/models/c.rb", "# Model.find_by(1) used to live here\n"
    write "db/migrate/1_x.rb", "Model.find_by(1)\n"
    write "vendor/x.rb", "with_params(a: 1)\n"
    write "test/x_test.rb", "Model.find_by(1)\n"

    assert_empty check.code_findings
  end

  test "reports blockers and exits non-zero only when there are some" do
    write "app/models/d.rb", "acts_as_model\n"

    assert check.blockers?
    assert_match "acts_as_model", check.report
  end

  test "reports nothing to fix on a clean app" do
    write "app/models/e.rb", "RubyLLM.chat(model: Setting.default_model).ask(prompt)\n"

    assert_not check.blockers?
    assert_equal "RubyLLM 2.0 upgrade check: nothing to fix.", check.report
  end

  test "flags data the upgrade migrations would refuse, on a 1.x schema" do
    connection = ActiveRecord::Base.connection
    connection.create_table(:models, id: :string, force: true) { |t| t.string :model_id }
    connection.add_column(:chats, :model_id, :string)
    connection.execute("INSERT INTO models (id, model_id) VALUES ('m1', 'gpt-4')")
    connection.execute("UPDATE chats SET model_id = 'missing-model-row'")

    data = check.data_findings

    assert_equal [ [ "chats", :blocker ] ], data.map { [ _1.path, _1.severity ] }
    assert_match "missing model", data.first.code
  ensure
    connection.remove_column(:chats, :model_id) if connection.column_exists?(:chats, :model_id)
    connection.drop_table(:models, if_exists: true)
  end

  test "flags an empty model registry and notes chats that will get a fallback model" do
    connection = ActiveRecord::Base.connection
    connection.create_table(:models, id: :string, force: true) { |t| t.string :model_id }
    connection.add_column(:chats, :model_id, :string)

    blocker = check.data_findings.find { _1.path == "models" }
    assert_equal :blocker, blocker&.severity
    assert_match "ruby_llm:load_models", blocker.fix

    connection.execute("INSERT INTO models (id, model_id) VALUES ('m1', 'gpt-4')")
    note = RubyLlmUpgradeCheck.new(root: @root, connection: connection).data_findings.find { _1.path == "chats" }
    assert_equal :review, note&.severity
    assert_match "chats without a model", note.code
  ensure
    connection.remove_column(:chats, :model_id) if connection.column_exists?(:chats, :model_id)
    connection.drop_table(:models, if_exists: true)
  end

  test "the upgraded template itself is clean" do
    template = RubyLlmUpgradeCheck.new(root: Rails.root, connection: ActiveRecord::Base.connection)

    assert_empty template.code_findings, template.report
    assert_empty template.data_findings, template.report
  end

  private

  def check = RubyLlmUpgradeCheck.new(root: @root, connection: ActiveRecord::Base.connection)

  def write(path, body)
    (@root / path).dirname.mkpath
    (@root / path).write(body)
  end
end
