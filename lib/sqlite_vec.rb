# frozen_string_literal: true

# SqliteVec exposes a +.to_path+ shim that Rails' SQLite3 adapter
# accepts in +config/database.yml+'s +extensions:+ array. We return the
# path to the vendored sqlite-vec loadable extension that matches the
# host OS + CPU.
#
# This file is required from +config/application.rb+ so the constant
# is defined before Rails evaluates +database.yml+.
module SqliteVec
  # vec0 virtual tables create several "shadow" tables to hold the
  # actual vector chunks, rowid map, and metadata. These are internal
  # to the virtual table and recreated automatically on CREATE, so the
  # schema dumper should ignore them. Some of them also have columns
  # without a type (e.g. +rowid PRIMARY KEY+) which Rails 8 can't
  # parse, so we must exclude them or the dumper crashes.
  SHADOW_TABLE_SUFFIXES = %w[
    _chunks
    _rowids
    _info
    _vector_chunks\d+
    _metadatachunks\d+
    _metadatatext\d+
    _auxiliary
  ].freeze

  SHADOW_TABLE_REGEX = /(#{SHADOW_TABLE_SUFFIXES.join('|')})\z/.freeze

  class << self
    def to_path
      @to_path ||= compute_path
    end

    private

    def compute_path
      base = File.expand_path("../vendor/sqlite-vec", __dir__)
      case RbConfig::CONFIG["host_os"]
      when /darwin/
        File.join(base, "darwin-arm64", "vec0.dylib")
      when /linux/
        if RbConfig::CONFIG["host_cpu"].match?(/aarch64|arm64/)
          File.join(base, "linux-aarch64", "vec0.so")
        else
          File.join(base, "linux-x86_64", "vec0.so")
        end
      end
    end
  end
end
