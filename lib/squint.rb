require 'active_support/concern'

# Squint json, jsonb, hstore queries
module Squint
  extend ActiveSupport::Concern
  if ActiveRecord::VERSION::STRING < '5'
    include ::ActiveRecord::QueryMethods
  end

  module WhereMethods
    # Args may be passed to build/build_where like:
    #  build_where(jsonb_column: {key1: value1})
    #  build_where(jsonb_column: {key1: value1}, jsonb_column: {key2: value2})
    #  build_where(jsonb_column: {key1: value1}, regular_column: value)
    #  build_where(jsonb_column: {key1: value1}, association: {column: value))
    if ActiveRecord::VERSION::STRING > '5'
      method_name = :build
    elsif ActiveRecord::VERSION::STRING < '5'
      method_name = :build_where
    end
    send :define_method, method_name do |*args|
      # For Rails 5, we end up monkey patching WhereClauseFactory for everyone
      # so need to return super if our methods aren't on the AR class
      # doesn't hurt for 4.2.x either
      return super(*args) unless klass.respond_to?(:squint_hash_field_reln)
      save_args = []
      reln = args.inject([]) do |memo, arg|
        if arg.is_a?(Hash)
          arg.keys.each do |key|
            if arg[key].is_a?(Hash) && HASH_DATA_COLUMNS[key]
              memo << klass.squint_hash_field_reln(key => arg[key])
            else
              save_args << {  key => arg[key] }
            end
          end
        elsif arg.present?
          save_args << arg
        end
        memo
      end
      if ActiveRecord::VERSION::STRING > '5'
        reln = ActiveRecord::Relation::WhereClause.new(reln, [])
        save_args << [] if save_args.size == 1
      end
      reln += super(*save_args) unless save_args.empty?
      reln
    end
  end

  included do |base|
    if ActiveRecord::VERSION::STRING < '5'
      ar_reln_module = base::ActiveRecord_Relation
      ar_association_module = base::ActiveRecord_AssociationRelation
    elsif ActiveRecord::VERSION::STRING > '5.1'
      # ActiveRecord_Relation is now a private_constant in 5.1.x
      ar_reln_module = base.relation_delegate_class(ActiveRecord::Relation)::WhereClauseFactory
      ar_association_module = nil
    elsif ActiveRecord::VERSION::STRING > '5.0'
      ar_reln_module = base::ActiveRecord_Relation::WhereClauseFactory
      ar_association_module = nil
      # ar_association_module = base::ActiveRecord_AssociationRelation
    end

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

    ar_association_module.try(:class_eval) do
      prepend WhereMethods
    end

    # squint_hash_field_reln
    # return an Arel object with the appropriate query
    # Strings want to be a SQL Literal, other things can be
    # passed in bare to the eq or in operator
    def self.squint_hash_field_reln(*args)
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
                 squint_hstore_element_missing(column_name_segments, reln)
               else
                 squint_jsonb_element_missing(column_name_segments, reln)
               end
      end
      reln
    end

    def self.squint_storext_default?(temp_attr, attribute_sym)
      return false unless respond_to?(:storext_definitions)
      if storext_definitions.keys.include?(attribute_sym) &&
         !(storext_definitions[attribute_sym][:opts] &&
           storext_definitions[attribute_sym][:opts][:default]).nil? &&
         [temp_attr].compact.map(&:to_s).
           flatten.
           include?(storext_definitions[attribute_sym][:opts][:default].to_s)
        true
      end
    end

    def self.squint_hstore_element_exists(element, attribute_hash_column, value)
      Arel::Nodes::Equality.new(
        Arel::Nodes::NamedFunction.new(
          "exist",
          [arel_table[Arel::Nodes::SqlLiteral.new(attribute_hash_column)],
           Arel::Nodes::SqlLiteral.new(element)]
        ), value
      )
    end

    def self.squint_hstore_element_missing(column_name_segments, reln)
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
            squint_hstore_element_exists(element, attribute_hash_column, Arel::Nodes::False.new)
          ).or(
            squint_hstore_element_exists(element, attribute_hash_column, nil)
          )
        )
      )
    end

    def self.squint_jsonb_element_equality(element, attribute_hash_column, value)
      Arel::Nodes::Equality.new(
        Arel::Nodes::Grouping.new(
          Arel::Nodes::InfixOperation.new(
            Arel::Nodes::SqlLiteral.new('?'),
            arel_table[Arel::Nodes::SqlLiteral.new(attribute_hash_column)],
            Arel::Nodes::SqlLiteral.new(element)
          )
        ), value
      )
    end

    def self.squint_jsonb_element_missing(column_name_segments, reln)
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
            squint_jsonb_element_equality(element, attribute_hash_column, nil).or(
              squint_jsonb_element_equality(element, attribute_hash_column, Arel::Nodes::False.new)
            )
          )
        )
      )
    end
  end
end
