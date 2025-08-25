# frozen_string_literal: true

require "open3"
require "pathname"

module Kindling
  module IndexBackends
    module_function

    def available?
      find_fd || find_rg
    end

    def find_fd
      @fd ||= which("fd") || which("fdfind") # Debian/Ubuntu may name it fdfind
    end

    def find_rg
      return @rg if defined?(@rg)

      # Check standard PATH first
      @rg = which("rg") || which("ripgrep")
      return @rg if @rg

      # Check common installation locations including Claude Code's bundled ripgrep
      common_paths = [
        "/Users/#{ENV["USER"]}/.claude/local/node_modules/@anthropic-ai/claude-code/vendor/ripgrep/arm64-darwin/rg",
        "/usr/local/bin/rg",
        "/opt/homebrew/bin/rg"
      ]

      common_paths.each do |p|
        if File.executable?(p) && !File.directory?(p)
          @rg = p
          return @rg
        end
      end

      @rg = nil
    end

    def run_fd(root, respect_gitignore: true)
      bin = find_fd
      return nil unless bin
      # -t f (files), -H (hidden), --follow symlinks
      cmd = [bin, "-t", "f", "-H", "--follow", "--color", "never", "--print0"]

      cmd << if respect_gitignore
        # --no-require-git: respect .gitignore even outside git repos
        "--no-require-git"
      else
        # -I: ignore .gitignore files
        "-I"
      end

      # Add explicit ignores for common files and directories including .git and vendor
      cmd.concat(["-E", ".git", "-E", ".DS_Store", "-E", "*.pyc", "-E", "__pycache__",
        "-E", "node_modules", "-E", "vendor", "-E", "tmp", "-E", "log", "-E", ".bundle",
        "-E", "coverage", "-E", "build", "-E", "dist", "."])
      run_streaming(root, cmd, nul_sep: true)
    end

    def run_rg(root, respect_gitignore: true)
      bin = find_rg
      return nil unless bin
      # Include hidden, follow symlinks, exclude common patterns
      cmd = [bin, "--files", "--hidden", "--follow", "--color", "never"]

      if !respect_gitignore
        # -u: Don't respect .gitignore files
        cmd << "-u"
      end

      cmd.concat(["--iglob", "!.git", "--iglob", "!.DS_Store", "--iglob", "!*.pyc",
        "--iglob", "!__pycache__", "--iglob", "!node_modules", "--iglob", "!vendor",
        "--iglob", "!tmp", "--iglob", "!log", "--iglob", "!.bundle", "--iglob", "!coverage",
        "--iglob", "!build", "--iglob", "!dist", "-0"])
      run_streaming(root, cmd, nul_sep: true)
    end

    # Yields relative paths as they are produced
    def run_streaming(root, cmd, nul_sep:)
      sep = nul_sep ? "\x00" : "\n"
      Enumerator.new do |y|
        Open3.popen3({}, *cmd, chdir: root) do |stdin, stdout, stderr, wait_thr|
          stdin.close # We don't need stdin
          buffer = +""
          begin
            while (chunk = stdout.read(4096))
              buffer << chunk
              while (idx = buffer.index(sep))
                rel = buffer[0...idx]
                y << normalize_rel(root, rel) unless rel.empty?
                buffer = buffer[(idx + sep.length)..] || ""
              end
            end
            # Process any remaining data
            y << normalize_rel(root, buffer) unless buffer.empty?
          ensure
            err = begin
              stderr.read
            rescue
              ""
            end
            Logging.debug("index backend stderr: #{err}") unless err.nil? || err.empty?
          end
        end
      end
    rescue => e
      Logging.warn("Backend failed #{cmd.join(" ")}: #{e.message}")
      nil
    end

    def normalize_rel(root, path)
      # Remove leading ./ if present
      path = path.sub(/^\.\//, "")
      p = Pathname.new(path)
      return p.relative_path_from(Pathname.new(root)).to_s if p.absolute?
      path
    end

    def which(cmd)
      exts = ENV["PATHEXT"] ? ENV["PATHEXT"].split(";") : [""]
      ENV["PATH"].to_s.split(File::PATH_SEPARATOR).each do |p|
        exts.each do |e|
          f = File.join(p, "#{cmd}#{e}")
          return f if File.executable?(f) && !File.directory?(f)
        end
      end
      nil
    end
  end
end
