
module Drx

  module Cloc

    def self.available?
      @available ||= begin
        begin
          require 'cloc'
        rescue LoadError
          # The gem isn't installed.
          false
        else
          true
        end
      end
    end

    def self.db
      @db ||= begin
        if available?
          ::Cloc::Database.new(version).data
        else
          nil
        end
      end
    end

    def self.lookup(object_name, method_name)
      if db[object_name] and db[object_name][method_name]
        return db[object_name][method_name]
      end
    end

    def self.version=(version)
      @version = version
      @db = nil # so db() will load a new one.
    end

    def self.version
      @version ||= begin
        if available?
          ::Cloc::Database.default_version
        end
      end
    end

    def self.versions
      ::Cloc::Database.versions
    end

  end

end
