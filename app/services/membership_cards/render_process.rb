# frozen_string_literal: true

require 'open3'
require 'json'

module MembershipCards
  # Runs one card render in a fresh Ruby process (bin/render-membership-card)
  # and returns the PNG bytes it writes to stdout.
  #
  # Why a process per card: Pango fixes its font list at the first text call
  # of a process (see FontRegistry). A long-lived Passenger or Resque worker
  # that has ever drawn text could never pick up a font uploaded afterwards,
  # and a card that needs two font files would lose the second one. A child
  # process registers exactly the fonts this card needs, renders, and exits.
  # The cost is roughly half a second of Ruby start-up, on an admin action.
  class RenderProcess
    SCRIPT = 'bin/render-membership-card'
    TIMEOUT_SECONDS = 60

    def self.run(inputs, root: Rails.root, logger: Rails.logger)
      new(root: root, logger: logger).run(inputs)
    end

    def initialize(root:, logger:)
      @root = Pathname(root)
      @logger = logger
    end

    # inputs: a Renderer::Inputs (or any #to_h of its fields). Font entries are
    # Font structs; they travel as {path:, pango_family:}.
    def run(inputs)
      payload = JSON.generate(serialise(inputs))
      stdout, stderr, status = capture(payload)
      stderr.each_line { |line| @logger&.warn("[MembershipCards] render child: #{line.strip}") }
      raise RenderError, "card render failed: #{stderr.lines.last&.strip || "exit #{status.exitstatus}"}" unless status.success?
      raise RenderError, 'card render produced no output' if stdout.empty?

      stdout
    end

    private

    def serialise(inputs)
      inputs.to_h.transform_values { |value| value.is_a?(Font) ? value.to_h : value }
    end

    def capture(payload)
      env = { 'BUNDLE_GEMFILE' => @root.join('Gemfile').to_s }
      Open3.popen3(env, RbConfig.ruby, @root.join(SCRIPT).to_s, chdir: @root.to_s) do |stdin, stdout, stderr, wait|
        stdin.binmode
        stdin.write(payload)
        stdin.close
        out_reader = Thread.new { stdout.binmode.read }
        err_reader = Thread.new { stderr.read }
        status = wait_with_timeout(wait)
        [out_reader.value, err_reader.value, status]
      end
    end

    def wait_with_timeout(wait)
      wait.join(TIMEOUT_SECONDS) or begin
        Process.kill('KILL', wait.pid)
        raise RenderError, "card render timed out after #{TIMEOUT_SECONDS}s"
      end
      wait.value
    end
  end
end
