# frozen_string_literal: true

module Setup
  # Line-oriented reader/writer for a dotenv file.
  #
  # Deliberately not a parse-and-reserialize: .env is heavily commented and
  # hand-maintained, and rewriting it wholesale would throw those comments away.
  # Only the single line being changed is touched.
  #
  # Last assignment wins, for both reading and writing — that is what dotenv and
  # docker compose do with a duplicated key, and a helper that disagreed with
  # them would report (or edit) a value the app never sees.
  #
  # lib/tasks is autoloader-ignored, so callers `require_relative` this file.
  class EnvFile
    # What may appear on the right-hand side of an assignment. Anything else —
    # a newline, a `$`, a backtick — could change the meaning of the file or of
    # a shell that sources it, so it is refused rather than escaped.
    SAFE_VALUE = %r{\A[\w.\-+=:/@]*\z}

    class UnsafeValue < ArgumentError; end

    attr_reader :path

    def initialize(path)
      @path = path.to_s
    end

    def exist?
      File.exist?(path)
    end

    # The effective value of +key+, or nil when it is absent, commented out or
    # assigned an empty value. Blank is treated as unset, the same way
    # AppSecrets treats a blank environment variable. Surrounding quotes are
    # stripped, as dotenv does.
    def [](key)
      matcher = assignment_pattern(key)
      match = lines.reverse_each.find { |line| matcher.match?(line.chomp) }
      return nil if match.nil?

      unquote(matcher.match(match.chomp)[1].strip).presence
    end

    # Replaces the last assignment of +key+, appending one if there is none.
    # Creates the file when it does not exist yet.
    def []=(key, value)
      raise UnsafeValue, unsafe_message(key, value) unless SAFE_VALUE.match?(value.to_s)

      matcher = assignment_pattern(key)
      source = lines
      index = source.rindex { |line| matcher.match?(line.chomp) }

      if index
        source[index] = "#{key}=#{value}\n"
      else
        source << "\n" if source.any? && !source.last.end_with?("\n")
        source << "#{key}=#{value}\n"
      end

      File.write(path, source.join)
    end

    private

    def lines
      exist? ? File.readlines(path) : []
    end

    # Ignores commented-out assignments; tolerates a leading `export`.
    def assignment_pattern(key)
      /\A\s*(?:export\s+)?#{Regexp.escape(key.to_s)}\s*=\s*(.*)\z/
    end

    def unquote(value)
      return value unless value.length >= 2

      quoted = %w[" '].any? { |quote| value.start_with?(quote) && value.end_with?(quote) }
      quoted ? value[1..-2] : value
    end

    def unsafe_message(key, value)
      "refusing to write #{key} to #{path}: the value contains characters that are unsafe in a " \
        "dotenv file (allowed: letters, digits, . - + = : / @ _). Got #{value.to_s.inspect}."
    end
  end
end
