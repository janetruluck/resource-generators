# include inflectors for some nice methods
require "active_support/inflector"

class Resource < Thor::Group
  include Thor::Actions

  # Define arguments and options
  argument :name
  class_option :public_attributes, type: :array,  :aliases => "-p", desc: "Public attributes for the resource in form type:attribute"
  class_option :admin_attributes,  type: :array,  :aliases => "-a", desc: "Admin attributes for the resource in form type:attribute"
  class_option :other_attributes,  type: :array,  :aliases => "-n", desc: "Other attributes for the resource in form type:attribute" 
  class_option :validate_presence, type: :array,  :aliases => "-v", desc: "Fields to validate presence on (will also add null: false to the migration"
  class_option :validate_unique,   type: :array,  :aliases => "-u", desc: "Fields to validate uniqueness on (will also add unique: true to the migration"
  class_option :belongs_to,        type: :array,  :aliases => "-b", desc: "belongs_to relationships for the resource"
  class_option :has_one,           type: :array,  :aliases => "-o", desc: "has_one relationships for the resource" 
  class_option :has_many,          type: :array,  :aliases => "-h", desc: "has_many relationships for the resource" 
  class_option :has_many_through,  type: :array,  :aliases => "-t", desc: "has_many through relationships in form related_model:through"
  class_option :acts_as_list,      type: :array,  :aliases => "-l", desc: "Acts as list scopes"
  class_option :with_entity,       type: :boolean,                  desc: "Add a Grape::Entity to the model"
  class_option :paper_trail,       type: :boolean,                  desc: "Add versioning via PaperTrail"
  class_option :use_uuid,          type: :boolean,                  desc: "Use UUIDs for the id of the resource instead of integers"

  def self.source_root
    File.dirname(__FILE__)
  end

  def create_migration_file
    @timestamp = Time.now.strftime("%Y%m%d%H%M%S")
    template('templates/migration.tt', "db/migrate/#{@timestamp}_#{safe_name.pluralize}.rb")
  end

  def create_version_migration_file
    sleep 1 # necessary since they sometimes run too fast causing duplicate timestamps
    if options[:paper_trail]
      @timestamp = Time.now.strftime("%Y%m%d%H%M%S")
      template('templates/migration_version.tt', "db/migrate/#{@timestamp}_#{safe_name}_versions.rb")
    else
      say "skipping... no versioning for this one"
    end
  end

  def create_model_file
    template('templates/model.tt', "app/models/#{safe_name}.rb")
  end

  def create_model_version_file
    if options[:paper_trail]
      template('templates/model_version.tt', "app/versions/#{safe_name}_version.rb")
    else
      say "skipping... no versioning for this one"
    end
  end

  def create_test_file
    template('templates/spec.tt', "spec/models/#{safe_name}_spec.rb")
  end

  def create_factory_file
    template('templates/factory.tt', "spec/factories/#{safe_name}_factory.rb")
  end

  private
  def class_name
    name.singularize.camelize 
  end

  def safe_name
    name.singularize.downcase.underscore
  end

  def parse_attributes_for_migration(attributes)
    migration_lines = Array.new
    attributes.each do |current_attribute|
      migration_lines.push(migration_definition_for_attribute(current_attribute))
    end
    migration_lines.join("\n\t\t\t")
  end

  def parse_attributes_for_factory(attributes)
    if attributes
      factory_definition = Array.new
      attributes.each do |current_attribute|
        factory_definition.push(field_definition_for_attribute(current_attribute))
      end
      factory_definition.join("\n\t\t")
    end
  end

  def migration_definition_for_attribute(current_attribute)
    type, attribute = current_attribute.split(":")
    migration_line = "t.#{type.downcase} :#{attribute.downcase.underscore}"
    if type == "boolean"
      migration_line << ", null: false, default: false" 
    else
      migration_line << ", null: false"  if validate_presence_of?(attribute) 
      migration_line << ", unique: true" if validate_uniqueness_of?(attribute)
    end
    migration_line
  end

  def field_definition_for_attribute(current_attribute)
    type, attribute = current_attribute.split(":")
    case type
    when "uuid"
      next
    when "string"
      %Q{sequence(:#{attribute.downcase.underscore}) {|n| "\#{Faker::Lorem.sentence} \#{n}" }}
    when "boolean"
      "#{attribute.downcase.underscore} true"
    when "text"
      %Q{sequence(:#{attribute.downcase.underscore}) {|n| "\#{Faker::Lorem.paragraph} \#{n}" }}
    when "int"
      "#{attribute.downcase.underscore} Faker::Number.number(5)"
    else
      %Q{#{attribute.downcase.underscore} "Change ME!"}
    end
  end

  def validate_presence_of?(attribute)
    options[:validate_presence] && options[:validate_presence].include?(attribute)  
  end

  def validate_uniqueness_of?(attribute)
    options[:validate_uniqueness] && options[:validate_uniqueness].include?(attribute)  
  end

end