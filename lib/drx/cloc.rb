
module Drx

  # A wrapper around the 'cloc' library, which enables us to locate methods
  # in C source files.
  #
  # ObjInfo#locate_method() uses this module.
  module Cloc

    # Tells us whether the cloc library is installed and functioning.
    def self.available?
      @available ||= library_available? && !::Cloc::Database.versions.empty?
    end

    def self.library_available?
      @library_evailable ||= begin
        begin
          require 'cloc'
        rescue LoadError
          # The library is not installed.
          false
        else
          true
        end
      end
    end

    # Whether to actually use the cloc library.
    def self.use=(bool)
      @use = bool
    end

    def self.use?
      @use && available?
    end

    def self.db
      @db ||=
        if available?
          ::Cloc::Database.new(version)
        end
    end

    def self.lookup(object_name, method_name)
      db.lookup(object_name, method_name)
    end

    # Select the cloc database to use.
    def self.version=(version)
      @version = version
      @db = nil # so db() will load a new one.
    end

    def self.version
      @version ||=
        if available?
          ::Cloc::Database.default_version
        end
    end

    def self.versions
      if available?
        ::Cloc::Database.versions
      else
        []
      end
    end

  end

end
