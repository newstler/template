# frozen_string_literal: true

# SqliteVec exposes a +.to_path+ shim that Rails' SQLite3 adapter
# accepts in +config/database.yml+'s +extensions:+ array. We return the
# path to the vendored sqlite-vec loadable extension that matches the
# host OS + CPU.
#
# This file is required from +config/application.rb+ so the constant
# is defined before Rails evaluates +database.yml+.
module SqliteVec
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
