# frozen_string_literal: true

# Shared attachment handling for controllers that accept file uploads
module Attachable
  extend ActiveSupport::Concern

  private

  def store_attachments_temporarily(attachments)
    return [] unless attachments.present?

    attachments.reject(&:blank?).map do |attachment|
      temp_dir = Rails.root.join("tmp", "uploads", SecureRandom.uuid)
      FileUtils.mkdir_p(temp_dir)
      safe_filename = File.basename(attachment.original_filename).gsub(/[^\w.\-]/, "_")
      temp_path = temp_dir.join(safe_filename)
      File.binwrite(temp_path, attachment.read)
      temp_path.to_s
    end
  end
end
