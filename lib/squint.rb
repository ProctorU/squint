require 'active_support/concern'
module Squint
  extend ActiveSupport::Concern
  include ::ActiveRecord::QueryMethods
  included do |base|
    #
    # This bit of code inserts a SHIM module between Squint
    # and the base so that the base can override these  methods if needed
    # You can see where the shim module shows up with
    # Post.ancestors
    # shamefully copied from http://thepugautomatic.com/2013/07/dsom/
    #
    if const_defined?(:Squint,_search_ancestors = false)
      mod = const_get(:Squint)
    else
      mod = const_set(:Squint,Module.new)
      include mod
    end

    ar_reln_module = base::ActiveRecord_Relation

    # put together a list of columns in this model
    # that are hstore, json, or jsonb and will benefit from
    # searchability
    HASH_DATA_COLUMNS = base.columns_hash.keys.collect {|col_name|
      if %w( hstore json jsonb ).include?(base.columns_hash[col_name].sql_type)
        [col_name.to_sym,base.columns_hash[col_name].sql_type]
      else
        nil
      end
    }.compact.to_h

    # Args may be passed to build_where like:
    #  build_where(jsonb_column: {key1: value1})
    #  build_where(jsonb_column: {key1: value1}, jsonb_column: {key2: value2})
    #  build_where(jsonb_column: {key1: value1}, regular_column: value)
    #  build_where(jsonb_column: {key1: value1}, association: {column: value))
    ar_reln_module.send :define_method, :build_where do |*args|
      return_value = []
      args.each do |arg|
        if arg.is_a?(Hash)
          arg.keys.each do |key|
            if arg[key].is_a?(Hash) && HASH_DATA_COLUMNS[key]
              return_value << hash_field_reln(*[key => arg[key]])
            else
              return_value += super(key => arg[key])
            end
          end
        elsif !arg.empty?
          return_value += super(arg)
        end
      end
      return_value
    end

    # hash_field_reln
    # return an Arel object with the appropriate query
    # Strings want to be a SQL Literal, other things can be
    # passed in bare to the eq or in operator
    ar_reln_module.send :define_method, :hash_field_reln do |*args|
      temp_attr = args[0]
      check_attr_missing = false
      contains_nil = false
      column_type = HASH_DATA_COLUMNS[args[0].keys.first]
      column_name_segments = []
      quote_char = '"'.freeze
      while(temp_attr.is_a?(Hash))
        attribute_sym = temp_attr.keys.first.to_sym
        column_name_segments << (quote_char + temp_attr.keys.first.to_s + quote_char)
        quote_char = '\''.freeze
        temp_attr = temp_attr[temp_attr.keys.first]
      end

      if respond_to?(:storext_definitions)
        if storext_definitions.keys.include?(attribute_sym) &&
           !storext_definitions[attribute_sym].dig(:opts,:default).nil? &&
           [temp_attr].compact.map(&:to_s).
             flatten.
             include?(storext_definitions[attribute_sym][:opts][:default].to_s)
          check_attr_missing = true
        end
      end

      # Check for nil in array
      if temp_attr.is_a? Array
        contains_nil = temp_attr.include?(nil)
        # remove the nil from the array - we'll handle that later
        temp_attr.compact!
        # if the Array is now just 1 element, it doesn't need to be
        # an Array any longer
        temp_attr = temp_attr[0] if temp_attr.size == 1
      end

      if temp_attr.is_a? Array
        temp_attr = temp_attr.map(&:to_s)
      elsif ![FalseClass, TrueClass, NilClass].include?(temp_attr.class)
        temp_attr = temp_attr.to_s
      end

      if [Array, NilClass].include?(temp_attr.class)
        query_value = temp_attr
      else  # strings or string-like things
        query_value = Arel::Nodes::Quoted.new(temp_attr.to_s)
      end
      # column_name_segments[0] = column_name_segments[0]
      attribute_selector = column_name_segments.join('->'.freeze)

      # JSON(B) data needs to have the last accessor be ->> instead of
      # -> .   The ->> returns the data as text instead of jsonb.
      # hstore columns generally don't have nested keys / hashes
      # Possibly need to raise an error if the hash for an hstore
      # column references nested arrays?
      unless column_type == 'hstore'.freeze
        attribute_selector[attribute_selector.rindex('>'.freeze)] = '>>'.freeze
      end

      if query_value.is_a?(Array)
        reln = arel_table[Arel::Nodes::SqlLiteral.new(attribute_selector)].in(query_value)
      else
        reln = arel_table[Arel::Nodes::SqlLiteral.new(attribute_selector)].eq(query_value)
      end

      # If a nil is present in an Array, need add a specific IS NULL comparison
      if contains_nil
        reln = Arel::Nodes::Grouping.new(
          reln.or(arel_table[Arel::Nodes::SqlLiteral.new(attribute_selector)].eq(nil))
        )
      end

      # check_attr_missing for StoreXT attributes where the default is
      # specified as a query value
      if check_attr_missing
        if column_type == 'hstore'.freeze
          reln = self.hstore_element_missing(column_name_segments, reln)
        else
          reln = self.jsonb_element_missing(column_name_segments, reln)
        end
      end
      reln
    end

    def self.jsonb_element_missing(column_name_segments,reln)
      element = column_name_segments.pop
      attribute_hash_column = column_name_segments.join('->'.freeze)
      # Query generated is equals default or attribute present is null or equals false
      #    * Is null happens the the column is null
      #    * equals false is when the column has jsonb data, but the key doesn't exist
      # ("posts"."storext_attributes"->>'is_awesome' = 'false' OR
      #   (("posts"."storext_attributes" ? 'is_awesome') IS NULL OR
      #    ("posts"."storext_attributes" ? 'is_awesome') = FALSE)
      # )
      reln = Arel::Nodes::Grouping.new(
        reln.or(
          Arel::Nodes::Grouping.new(
            Arel::Nodes::Equality.new(
              Arel::Nodes::Grouping.new(
                Arel::Nodes::InfixOperation.new(Arel::Nodes::SqlLiteral.new('?'),
                                                arel_table[Arel::Nodes::SqlLiteral.new(attribute_hash_column)],
                                                Arel::Nodes::SqlLiteral.new(element))),nil).or(
              Arel::Nodes::Equality.new(
                Arel::Nodes::Grouping.new(
                  Arel::Nodes::InfixOperation.new(Arel::Nodes::SqlLiteral.new('?'),
                                                  arel_table[Arel::Nodes::SqlLiteral.new(attribute_hash_column)],
                                                  Arel::Nodes::SqlLiteral.new(element))),Arel::Nodes::False.new))
          )
        )
      )
    end

    def self.hstore_element_missing(column_name_segments,reln)
      element = column_name_segments.pop
      attribute_hash_column = column_name_segments.join('->'.freeze)
      # Query generated is equals default or attribute present is null or equals false
      #    * Is null happens the the column is null
      #    * equals false is when the column has jsonb data, but the key doesn't exist
      # ("posts"."storext_attributes"->>'is_awesome' = 'false' OR
      #   (exists("posts"."storext_attributes", 'is_awesome') IS NULL OR
      #    exists("posts"."storext_attributes", 'is_awesome') = FALSE)
      # )
      reln = Arel::Nodes::Grouping.new(
        reln.or(
          Arel::Nodes::Grouping.new(
            Arel::Nodes::NamedFunction.new("exist",[arel_table[Arel::Nodes::SqlLiteral.new(attribute_hash_column)],
                                                    Arel::Nodes::SqlLiteral.new(element)]).eq(Arel::Nodes::False.new)).or(
            Arel::Nodes::Equality.new(
              Arel::Nodes::NamedFunction.new("exist",[arel_table[Arel::Nodes::SqlLiteral.new(attribute_hash_column)],
                                                      Arel::Nodes::SqlLiteral.new(element)]),nil)
          )
        )
      )
    end
  end
end
