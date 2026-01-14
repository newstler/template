class ChatResponseJob < ApplicationJob
  def perform(chat_id, content, attachment_paths = [])
    chat = Chat.find(chat_id)

    # Build the ask options
    ask_options = {}
    ask_options[:with] = attachment_paths if attachment_paths.present?

    chat.ask(content, **ask_options) do |chunk|
      if chunk.content && !chunk.content.blank?
        message = chat.messages.last
        message.broadcast_append_chunk(chunk.content)
      end
    end
  ensure
    # Clean up temporary files after processing
    cleanup_temp_files(attachment_paths) if attachment_paths.present?
  end

  private

  def cleanup_temp_files(paths)
    paths.each do |path|
      next unless File.exist?(path)
      File.delete(path)
      # Also remove the parent directory if empty
      parent_dir = File.dirname(path)
      FileUtils.rmdir(parent_dir) if Dir.empty?(parent_dir)
    rescue StandardError => e
      Rails.logger.warn "Failed to clean up temp file #{path}: #{e.message}"
    end
  end
end