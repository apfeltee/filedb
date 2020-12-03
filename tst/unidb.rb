

require "logger"
require "json"
require "sequel"


module UniversalStore
  module Flavors
    class StoreDefault

      attr_accessor :handle

      def initialize(outputfile, *args, **kwargs)
        @outputfile = outputfile
        @inargs = args
        @inkwargs = kwargs
        @handle = nil
        @dbschema = {}
        @dbtable = nil
      end

      def _orvalue(keyname, val)
        if (val == nil) && (not @dbschema.empty?) then
          case @dbschema[keyname]
            when String then
              return ""
            when Numeric then
              return 0
            when Hash then
              return Hash.new
            when Array then
              return Array.new
          end
        end
        #$stderr.puts("_orvalue: returning as-is?")
        return val
      end

      def _repr(keyname, val)
        if not @dbschema.empty? then
          #$stderr.printf("dbschema[%p] = %p (%s)\n", keyname, @dbschema[keyname], @dbschema[keyname].class.name)
          case @dbschema[keyname].name
            when "String" then
              #$stderr.printf("  -- dumping string?\n")
              return val.dump
            when "Array", "Hash" then
              #$stderr.printf("  -- dumping %s?\n", val.class.name)
              return val.inspect
            when "Object", "Class", "Module" then
              #$stderr.printf("  -- to_s'ing %s?\n", val.class.name)
              return val.to_s
          end
        end
        #$stderr.puts("  -- returning as-is?")
        return val
      end

      def schema(tbname, **kw)
        @dbtable = tbname.to_sym
        @dbschema = kw
      end

      def setup
        raise ArgumentError, "#{self.class.name}#setup is not implemented"
      end

      def finish
      end

      def insert(kvhash)
        raise ArgumentError, "#{self.class.name}#insert is not implemented"
      end
    end

    class StoreText < StoreDefault
      def setup
        @headerdefined = false
        @separator = "\t"
        @newline = "\n"
        @typespec = {}
        @handle = File.open(@outputfile, "wb")
      end

      def finish
        @handle.close
      end

      def _genheader
        if @dbschema.empty? then
          raise ArgumentError, "StoreText requires a schema"
        end
        idx = 0
        @dbschema.each do |name, typ|
          @handle.write(name)
          if ((idx + 1) != @dbschema.length) then
            @handle.write(@separator)
          end
          idx += 1
        end
        @handle.write(@newline)
        @handle.flush
        @headerdefined = true
      end

      def insert(kvhash)
        if (@headerdefined == false) then
          _genheader
        end
        idx = 0
        kvhash.each do |k, v|
          @handle.write(_repr(k, _orvalue(k, v)))
          if ((idx+1) != kvhash.length) then
            @handle.write(@separator)
          end
          idx += 1
        end
        @handle.write(@newline)
      end
    end

    class StoreJSON < StoreDefault


      def setup
        @handle = File.open(@outputfile, "wb")
        @hdrdefined = false
        @ftrdefined = false
      end

      def finish
        if (@ftrdefined == false) then
          _genfoot
        end
      end

=begin
        {
          "schema": [
            "foo": "String",
            "blah": Numeric,
            ...
          ]
=end
      def _genhead
        @handle.puts("{")
        @handle.printf("%p: %s,", "schema", JSON.pretty_generate(@dbschema))
        @handle.printf("%p: [\n", "data")
        @hdrdefined = true
      end

      def _genfoot
        @handle.puts("]}")
        @ftrdefined = true
      end

      def insert(kvhash)
        if (@hdrdefined == false) then
          _genhead
        end
        #kvhash.each.with_index do |pair, idx|
        #  
        #end
        @handle.printf("%s,\n", JSON.pretty_generate(kvhash))
      end
        
    end

    class StoreSQLite < StoreDefault
      def setup
        @tabledefined = false
        @handle = Sequel.sqlite(@outputfile, loggers: [Logger.new($stderr)]) #, *@inargs, *@inkwargs)
      end

      def _gentable
        if @dbschema.empty? then
          raise ArgumentError, "StoreSqlite requires a schema"
        end
        p @dbtable
        if @dbtable.nil? then
          raise ArgumentError, "StoreSqlite requires a tablename"
        end
        otab = @dbschema
        @handle.create_table? @dbtable do
          primary_key :index
          otab.each do |keyname, type|
            send(type.name, keyname)
          end
        end
        @tabledefined = true
      end

      def insert(kvhash)
        if (@tabledefined == false) then
          _gentable
        end
        v = kvhash.map{|k, v| [k, _orvalue(k, v)] }.to_h
        #$stderr.printf("sqlite::insert: v=%p\n", v)
        @handle[@dbtable].insert(v)
      end
    end
  end

  class Database
    def initialize(flavor, outputfile)
      @flavor = flavor
      @outputfile = outputfile
      @realdb = _initrealdb
    end

    def _initrealdb
      case @flavor.downcase
        when "sqlite" then
          return Flavors::StoreSQLite.new(@outputfile)
        when "txt", "text", "tsv" then
          return Flavors::StoreText.new(@outputfile)
        when "js", "json" then
          return Flavors::StoreJSON.new(@outputfile)
        else
          raise ArgumentError, sprintf("database flavor %p is not (yet) implemented", @flavor)
      end
    end

    def setup
      @realdb.setup
    end

    def finish
      @realdb.finish
    end

    def schema(name, **kw)
      @realdb.schema(name, **kw)
    end

    def insert(kvhash)
      @realdb.insert(kvhash)
    end

    def self.open(flavor, outputfile, &b)
      db = Database.new(flavor, outputfile)
      db.setup
      begin
        b.call(db)
      ensure
        db.finish
      end
    end
  end
end

# ---------------

begin
  items = []
  ENV.each do |k, v|
    items.push({key: k, value: v, vlength: v.length})
  end

  UniversalStore::Database.open("json", "out.db") do |udb|
    udb.schema("envvals", key: String, value: String, vlength: Numeric)
    items.each do |item|
      udb.insert(item)
    end
  end
end

