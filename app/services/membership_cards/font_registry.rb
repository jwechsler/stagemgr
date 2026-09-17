# frozen_string_literal: true

require 'ffi'

module MembershipCards
  # Makes uploaded font files visible to Pango, by family name, for the life of
  # the current process.
  #
  # Pango builds its font map the first time libvips renders text and never
  # rebuilds it, so a font has to be registered BEFORE that first call or it is
  # invisible until the process exits. libvips' own `fontfile:` option suffers
  # the same limit -- only the first file handed to it in a process ever takes
  # effect -- which is why the renderer does not use it. RenderProcess spawns a
  # fresh process per card so this ordering always holds.
  #
  # The registration call is platform-specific: Homebrew's Pango on macOS
  # uses CoreText, Debian/Ubuntu's uses fontconfig. Both are process-scoped and
  # leave the system's font directories untouched.
  module FontRegistry
    class RegistrationFailed < RenderError; end

    CORETEXT_SCOPE_PROCESS = 1

    class << self
      # Registers each path; ignores nil entries (fallback fonts have no file).
      def register(paths)
        paths.compact.uniq.each { |path| register_one(path) }
      end

      def macos?
        RUBY_PLATFORM.include?('darwin')
      end

      private

      def register_one(path)
        raise RegistrationFailed, "font file missing: #{path}" unless File.exist?(path)

        ok = macos? ? core_text_registered?(path) : fontconfig_registered?(path)
        raise RegistrationFailed, "#{path}: the font system refused the file" unless ok
      end

      def fontconfig_registered?(path)
        fontconfig.FcConfigAppFontAddFile(nil, path) == 1
      end

      def core_text_registered?(path)
        absolute = File.expand_path(path)
        buffer = FFI::MemoryPointer.from_string(absolute)
        url = core_text.CFURLCreateFromFileSystemRepresentation(nil, buffer, absolute.bytesize, false)
        raise RegistrationFailed, "#{path}: could not build a file URL" if url.null?

        core_text.CTFontManagerRegisterFontsForURL(url, CORETEXT_SCOPE_PROCESS, nil)
      end

      # Bound lazily so loading this file on Linux never looks for CoreText and
      # vice versa.
      def fontconfig
        @fontconfig ||= Module.new do
          extend FFI::Library

          ffi_lib %w[fontconfig libfontconfig.so.1 libfontconfig.1.dylib
                     /opt/homebrew/lib/libfontconfig.1.dylib /usr/local/lib/libfontconfig.1.dylib]
          attach_function :FcConfigAppFontAddFile, %i[pointer string], :int
        end
      end

      def core_text
        @core_text ||= Module.new do
          extend FFI::Library

          ffi_lib '/System/Library/Frameworks/CoreText.framework/CoreText',
                  '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation'
          attach_function :CFURLCreateFromFileSystemRepresentation, %i[pointer pointer long bool], :pointer
          attach_function :CTFontManagerRegisterFontsForURL, %i[pointer int pointer], :bool
        end
      end
    end
  end
end
