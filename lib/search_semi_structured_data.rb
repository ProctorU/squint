require 'active_support/concern'
module SearchSemiStructuredData
  extend ActiveSupport::Concern
  include ::ActiveRecord::QueryMethods
  included do |base|
    #
    # This bit of code inserts a SHIM module between SearchSemiStructuredData
    # and the base so that the base can override these  methods if needed
    # You can see where the shim module shows up with
    # Post.ancestors
    # shamefully copied from http://thepugautomatic.com/2013/07/dsom/
    #
    if const_defined?(:SearchSemiStructuredDataMod,_search_ancestors = false)
      mod = const_get(:SearchSemiStructuredDataMod)
    else
      mod = const_set(:SearchSemiStructuredDataMod,Module.new)
      include mod
    end

    ar_reln_module = base::ActiveRecord_Relation

    # put together a list of columns in this model
    # that are hstore, json, or jsonb and will benefit from
    # searchability
    STRUCTURED_DATA_COLUMNS = base.columns_hash.keys.collect {|col_name|
      if(%w( hstore json jsonb ).include?(base.columns_hash[col_name].sql_type))
        [col_name.to_sym,base.columns_hash[col_name].sql_type]
      else
        nil
      end
    }.compact.to_h

    ar_reln_module.send :define_method, :build_where do |*args|
      if(args[0].is_a?(Hash) &&
         STRUCTURED_DATA_COLUMNS[args[0].keys.first] &&
         args[0][args[0].keys.first].is_a?(Hash))
        [hash_field_reln(*args)]
      else
        super(*args)
      end
    end

    # hash_field_reln
    # return an Arel object with the appropriate query
    # Strings want to be a SQL Literal, other things can be
    # passed in bare to the eq or in operator
    ar_reln_module.send :define_method, :hash_field_reln do |*args|
      temp_attr = args[0]
      column_type = STRUCTURED_DATA_COLUMNS[args[0].keys.first]
      column_name_segments = []
      quote_char = '"'.freeze
      while(temp_attr.is_a?(Hash))
        column_name_segments << (quote_char + temp_attr.keys.first.to_s + quote_char)
        quote_char = '\''.freeze
        temp_attr = temp_attr[temp_attr.keys.first]
      end
      query_value = temp_attr
      if [FalseClass, TrueClass, Array, NilClass].include?(temp_attr.class )
        query_value = temp_attr
      else  # strings or string-like things
        query_value = Arel::Nodes::Quoted.new(temp_attr)
      end
      column_name_segments[0] = column_name_segments[0]
      hfa = column_name_segments.join('->'.freeze)

      # JSON(B) data needs to have the last accessor be ->> instead of
      # -> .   The ->> returns the data as text instead of jsonb.
      # hstore columns generally don't have nested keys / hashes
      # Possibly need to raise an error if the hash for an hstore
      # column references nested arrays?
      hfa[hfa.rindex('>'.freeze)] = '>>'.freeze unless column_type == 'hstore'.freeze

      if(query_value.is_a? Array)
        reln = arel_table[Arel::Nodes::SqlLiteral.new(hfa)].in(query_value)
      else
        reln = arel_table[Arel::Nodes::SqlLiteral.new(hfa)].eq(query_value)
      end
      reln
    end
  end
end
