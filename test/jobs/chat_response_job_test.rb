require "test_helper"

class ChatResponseJobTest < ActiveJob::TestCase
  setup do
    @chat = chats(:one)
  end

  test "streams each chunk into the assistant message currently being written" do
    chat = @chat
    placeholders = []
    # Mimics RubyLLM 2.0: an empty assistant row is persisted before streaming; a tool round-trip
    # creates a second assistant row for the final answer.
    chat.define_singleton_method(:ask) do |_content, **_opts, &block|
      placeholders << messages.create!(role: "assistant", content: "")
      block.call(RubyLLM::Chunk.new(role: :assistant, content: "Let me check"))
      messages.create!(role: "tool", content: "Sunny")
      placeholders << messages.create!(role: "assistant", content: "")
      block.call(RubyLLM::Chunk.new(role: :assistant, content: "It is sunny"))
      block.call(RubyLLM::Chunk.new(role: :assistant, content: nil))
    end

    targets = capture_appends { with_found_chat(chat) { ChatResponseJob.perform_now(chat.id, "Weather?") } }

    assert_equal [
      [ "message_#{placeholders[0].id}_content", "Let me check" ],
      [ "message_#{placeholders[1].id}_content", "It is sunny" ]
    ], targets
  end

  private

  def with_found_chat(chat)
    original = Chat.method(:find)
    Chat.define_singleton_method(:find) { |id| id == chat.id ? chat : original.call(id) }
    yield
  ensure
    Chat.define_singleton_method(:find, original)
  end

  def capture_appends
    appends = []
    original = Turbo::StreamsChannel.method(:broadcast_append_to)
    Turbo::StreamsChannel.singleton_class.define_method(:broadcast_append_to) do |*_streamables, **kwargs|
      appends << [ kwargs[:target], kwargs.dig(:locals, :content) ] if kwargs[:partial] == "messages/content"
    end
    yield
    appends
  ensure
    Turbo::StreamsChannel.singleton_class.define_method(:broadcast_append_to, original)
  end
end
