# frozen_string_literal: true
# rubocop:todo all

module Mongoid
  module Fields
    class Standard
      extend Forwardable

      # Defines the behavior for defined fields in the document.
      # Set readers for the instance variables.
      attr_accessor :default_val, :label, :name, :options

      def_delegators :type, :demongoize, :evolve, :mongoize

      # Adds the atomic changes for this type of resizable field.
      #
      # @example Add the atomic changes.
      # field.add_atomic_changes(doc, "key", {}, [], [])
      #
      # @param [ Document ] document The document to add to.
      # @param [ String ] name The name of the field.
      # @param [ String ] key The atomic location of the field.
      # @param [ Hash ] mods The current modifications.
      # @param [ Array ] new The new elements to add.
      # @param [ Array ] old The old elements getting removed.
      def add_atomic_changes(document, name, key, mods, new, old)
        mods[key] = new
      end

      # Evaluate the default value and return it. Will handle the
      # serialization, proc calls, and duplication if necessary.
      #
      # @example Evaluate the default value.
      #   field.eval_default(document)
      #
      # @param [ Document ] doc The document the field belongs to.
      #
      # @return [ Object ] The serialized default value.
      def eval_default(doc)
        if fields = doc.__selected_fields
          evaluated_default(doc) if included?(fields)
        else
          evaluated_default(doc)
        end
      end

      # Is this field a foreign key?
      #
      # @example Is the field a foreign key?
      #   field.foreign_key?
      #
      # @return [ true | false ] If the field is a foreign key.
      def foreign_key?
        false
      end

      # Create the new field with a name and optional additional options.
      #
      # @example Create the new field.
      #   Field.new(:name, :type => String)
      #
      # @param [ Hash ] options The field options.
      #
      # @option options [ Class ] :type The class of the field.
      # @option options [ Object ] :default The default value for the field.
      # @option options [ String ] :label The field's label.
      def initialize(name, options = {})
        @name = name
        @options = options
        @label = options[:label]
        @default_val = options[:default]

        # @todo: Durran, change API in 4.0 to take the class as a parameter.
        # This is here temporarily to address #2529 without changing the
        # constructor signature.
        if default_val.respond_to?(:call)
          define_default_method(options[:klass])
        end
      end

      # Does this field do lazy default evaluation?
      #
      # @example Is the field lazy?
      #   field.lazy?
      #
      # @return [ true | false ] If the field is lazy.
      def lazy?
        false
      end

      # Is the field localized or not?
      #
      # @example Is the field localized?
      #   field.localized?
      #
      # @return [ true | false ] If the field is localized.
      def localized?
        false
      end

      # Is the localized field enforcing values to be present?
      #
      # @example Is the localized field enforcing values to be present?
      #   field.localize_present?
      #
      # @return [ true | false ] If the field enforces present.
      def localize_present?
        false
      end

      # Get the metadata for the field if its a foreign key.
      #
      # @example Get the metadata.
      #   field.metadata
      #
      # @return [ Metadata ] The association metadata.
      def association
        @association ||= options[:association]
      end

      # Is the field a BSON::ObjectId?
      #
      # @example Is the field a BSON::ObjectId?
      #   field.object_id_field?
      #
      # @return [ true | false ] If the field is a BSON::ObjectId.
      def object_id_field?
        @object_id_field ||= (type == BSON::ObjectId)
      end

      # Does the field pre-process its default value?
      #
      # @example Does the field pre-process the default?
      #   field.pre_processed?
      #
      # @return [ true | false ] If the field's default is pre-processed.
      def pre_processed?
        @pre_processed ||=
          (options[:pre_processed] || (default_val && !default_val.is_a?(::Proc)))
      end

      # Get the type of this field - inferred from the class name.
      #
      # @example Get the type.
      #   field.type
      #
      # @return [ Class ] The name of the class.
      def type
        @type ||= options[:type] || Object
      end

      private

      # Get the name of the default method for this field.
      #
      # @api private
      #
      # @example Get the default name.
      #   field.default_name
      #
      # @return [ String ] The method name.
      def default_name
        @default_name ||= "__#{name}_default__"
      end

      # Define the method for getting the default on the document.
      #
      # @api private
      #
      # @example Define the method.
      #   field.define_default_method(doc)
      #
      # @note Ruby's instance_exec was just too slow.
      #
      # @param [ Class | Module ] object The class or module the field is
      #   defined on.
      def define_default_method(object)
        object.__send__(:define_method, default_name, default_val)
      end

      # Is the field included in the fields that were returned from the
      # database? We can apply the default if:
      #   1. The field is included in an only limitation (field: 1)
      #   2. The field is not excluded in a without limitation (field: 0)
      #
      # @example Is the field included?
      #   field.included?(fields)
      #
      # @param [ Hash ] fields The field limitations.
      #
      # @return [ true | false ] If the field was included.
      def included?(fields)
        (fields.values.first == 1 && fields[name.to_s] == 1) ||
          (fields.values.first == 0 && !fields.has_key?(name.to_s))
      end

      # Get the evaluated default.
      #
      # @example Get the evaluated default.
      #   field.evaluated_default.
      #
      # @param [ Document ] doc The doc being applied to.
      #
      # @return [ Object ] The default value.
      def evaluated_default(doc)
        if default_val.respond_to?(:call)
          evaluate_default_proc(doc)
        else
          serialize_default(default_val.__deep_copy__)
        end
      end

      # Evaluate the default proc. In some cases we need to instance exec,
      # in others we don't.
      #
      # @example Eval the default proc.
      #   field.evaluate_default_proc(band)
      #
      # @param [ Document ] doc The document.
      #
      # @return [ Object ] The called proc.
      def evaluate_default_proc(doc)
        serialize_default(doc.__send__(default_name))
      end

      # This is used when default values need to be serialized. Most of the
      # time just return the object.
      #
      # @api private
      #
      # @example Serialize the default value.
      #   field.serialize_default(obj)
      #
      # @param [ Object ] object The default.
      #
      # @return [ Object ] The serialized default.
      def serialize_default(object)
        mongoize(object)
      end
    end
  end
end
