require "tmpdir"
require "json"
require "fileutils"
require "logger"
require "open3"
require "bundler/cli"

require "rails/assets/utils"
require "rails/assets/builder"
require "rails/assets/file_store"

module Rails
  module Assets
    class BuildError < Exception; end

    class Convert
      include Utils

      attr_accessor :log, :build_dir, :opts, :component

      def initialize(component)
        @component = component
        raise BuildError.new("Empty component name") if component.name == ""
      end

      def log
        @log ||= begin
          log = Logger.new(opts[:io] || STDOUT)
          log.formatter = proc { |severity, datetime, progname, msg|
            "#{severity.to_s.rjust(5)} - #{msg}\n"
          }
          log
        end
      end

      def index
        @index ||= Index.new
      end

      def file_store
        @file_store ||= FileStore.new(log)
      end

      def convert!(opts = {})
        @opts = opts

        if opts[:debug]
          dir = "/tmp/build"
          FileUtils.rm_rf(dir)
          FileUtils.mkdir_p(dir)
          build_in_dir(dir)
        else
          Dir.mktmpdir do |dir|
            build_in_dir(dir)
          end
        end
      end

      def build_in_dir(dir)
        log.info "Building package #{component.full} in #{dir}"
        @build_dir = dir

        bower_install

        new_components = Dir[File.join(build_dir, "bower_components", "*")].map do |f|
          Builder.new(build_dir, File.basename(f), log).build!
        end.compact

        # This must happen after every component build succeed
        new_components.each do |component|
          log.info "New gem #{component.gem_name} built in #{component.tmpfile}"
          file_store.save(component)
          index.save(component)
        end
      end

      def bower_install
        sh build_dir, BOWER_BIN, "install", component.full
      end
    end
  end
end
