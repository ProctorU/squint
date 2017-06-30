require 'active_support/concern'

# Squint json, jsonb, hstore queries
module Squint
  extend ActiveSupport::Concern
  include ::ActiveRecord::QueryMethods

  module WhereMethods
    # Args may be passed to build_where like:
    #  build_where(jsonb_column: {key1: value1})
    #  build_where(jsonb_column: {key1: value1}, jsonb_column: {key2: value2})
    #  build_where(jsonb_column: {key1: value1}, regular_column: value)
    #  build_where(jsonb_column: {key1: value1}, association: {column: value))
    def build_where(*args)
      save_args = []
      reln = args.inject([]) do |memo, arg|
        if !save_args.empty?
          save_args << arg
          memo += super(save_args)
          save_args = []
        elsif arg.is_a?(Hash)
          arg.keys.each do |key|
            if arg[key].is_a?(Hash) && HASH_DATA_COLUMNS[key]
              memo << hash_field_reln(key => arg[key])
            else
              memo += super(key => arg[key])
            end
          end
        elsif arg.present?
          if arg.is_a? String
            save_args << arg
          else
            memo += super(arg)
          end
        end
        memo
      end
      reln += super(save_args) unless save_args.empty?
      reln
    end

    # hash_field_reln
    # return an Arel object with the appropriate query
    # Strings want to be a SQL Literal, other things can be
    # passed in bare to the eq or in operator
    def hash_field_reln(*args)
      temp_attr = args[0]
      contains_nil = false
      column_type = HASH_DATA_COLUMNS[args[0].keys.first]
      column_name_segments = []
      quote_char = '"'.freeze
      while  temp_attr.is_a?(Hash)
        attribute_sym = temp_attr.keys.first.to_sym
        column_name_segments << (quote_char + temp_attr.keys.first.to_s + quote_char)
        quote_char = '\''.freeze
        temp_attr = temp_attr[temp_attr.keys.first]
      end

      check_attr_missing = squint_storext_default?(temp_attr, attribute_sym)

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

      query_value = if [Array, NilClass].include?(temp_attr.class)
                      temp_attr
                    else  # strings or string-like things
                      Arel::Nodes::Quoted.new(temp_attr.to_s)
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

      reln = if query_value.is_a?(Array)
               arel_table[Arel::Nodes::SqlLiteral.new(attribute_selector)].in(query_value)
             else
               arel_table[Arel::Nodes::SqlLiteral.new(attribute_selector)].eq(query_value)
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
        reln = if column_type == 'hstore'.freeze
                 hstore_element_missing(column_name_segments, reln)
               else
                 jsonb_element_missing(column_name_segments, reln)
               end
      end
      reln
    end
  end

  included do |base|
    ar_reln_module = base::ActiveRecord_Relation
    ar_association_module = base::ActiveRecord_AssociationRelation

    # put together a list of columns in this model
    # that are hstore, json, or jsonb and will benefit from
    # searchability
    HASH_DATA_COLUMNS = base.columns_hash.keys.map do |col_name|
      if %w[hstore json jsonb].include?(base.columns_hash[col_name].sql_type)
        [col_name.to_sym, base.columns_hash[col_name].sql_type]
      end
    end.compact.to_h

    ar_reln_module.class_eval do
      prepend WhereMethods
    end

    ar_association_module.class_eval do
      prepend WhereMethods
    end

    def self.jsonb_element_missing(column_name_segments, reln)
      element = column_name_segments.pop
      attribute_hash_column = column_name_segments.join('->'.freeze)
      # Query generated is equals default or attribute present is null or equals false
      #    * Is null happens when the the whole column is null
      #    * equals false is when the column has jsonb data, but the key doesn't exist
      # ("posts"."storext_attributes"->>'is_awesome' = 'false' OR
      #   (("posts"."storext_attributes" ? 'is_awesome') IS NULL OR
      #    ("posts"."storext_attributes" ? 'is_awesome') = FALSE)
      # )
      Arel::Nodes::Grouping.new(
        reln.or(
          Arel::Nodes::Grouping.new(
            Arel::Nodes::Equality.new(
              Arel::Nodes::Grouping.new(
                Arel::Nodes::InfixOperation.new(
                  Arel::Nodes::SqlLiteral.new('?'),
                  arel_table[Arel::Nodes::SqlLiteral.new(attribute_hash_column)],
                  Arel::Nodes::SqlLiteral.new(element)
                )
              ), nil
            ).or(
              Arel::Nodes::Equality.new(
                Arel::Nodes::Grouping.new(
                  Arel::Nodes::InfixOperation.new(
                    Arel::Nodes::SqlLiteral.new('?'),
                    arel_table[Arel::Nodes::SqlLiteral.new(attribute_hash_column)],
                    Arel::Nodes::SqlLiteral.new(element)
                  )
                ), Arel::Nodes::False.new
              )
            )
          )
        )
      )
    end

    def self.squint_storext_default?(temp_attr, attribute_sym)
      return false unless respond_to?(:storext_definitions)
      if storext_definitions.keys.include?(attribute_sym) &&
         !storext_definitions[attribute_sym].dig(:opts, :default).nil? &&
         [temp_attr].compact.map(&:to_s).
           flatten.
           include?(storext_definitions[attribute_sym][:opts][:default].to_s)
        true
      end
    end

    def self.hstore_element_missing(column_name_segments, reln)
      element = column_name_segments.pop
      attribute_hash_column = column_name_segments.join('->'.freeze)
      # Query generated is equals default or attribute present is null or equals false
      #    * Is null happens the the column is null
      #    * equals false is when the column has jsonb data, but the key doesn't exist
      # ("posts"."storext_attributes"->>'is_awesome' = 'false' OR
      #   (exists("posts"."storext_attributes", 'is_awesome') IS NULL OR
      #    exists("posts"."storext_attributes", 'is_awesome') = FALSE)
      # )
      Arel::Nodes::Grouping.new(
        reln.or(
          Arel::Nodes::Grouping.new(
            Arel::Nodes::NamedFunction.new(
              "exist",
              [arel_table[Arel::Nodes::SqlLiteral.new(attribute_hash_column)],
               Arel::Nodes::SqlLiteral.new(element)]
            ).eq(Arel::Nodes::False.new)
          ).or(
            Arel::Nodes::Equality.new(
              Arel::Nodes::NamedFunction.new(
                "exist",
                [arel_table[Arel::Nodes::SqlLiteral.new(attribute_hash_column)],
                 Arel::Nodes::SqlLiteral.new(element)]
              ), nil
            )
          )
        )
      )
    end
  end
end
