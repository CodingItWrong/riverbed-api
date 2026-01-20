module JSONAPI
  class Processor
    include Callbacks
    define_jsonapi_resources_callbacks :find,
                                       :show,
                                       :show_relationship,
                                       :show_related_resource,
                                       :show_related_resources,
                                       :create_resource,
                                       :remove_resource,
                                       :replace_fields,
                                       :replace_to_one_relationship,
                                       :replace_polymorphic_to_one_relationship,
                                       :create_to_many_relationships,
                                       :replace_to_many_relationships,
                                       :remove_to_many_relationships,
                                       :remove_to_one_relationship,
                                       :operation

    attr_reader :resource_klass, :operation_type, :params, :context, :result, :result_options

    def initialize(resource_klass, operation_type, params)
      @resource_klass = resource_klass
      @operation_type = operation_type
      @params = params
      @context = params[:context]
      @result = nil
      @result_options = {}
    end

    def process
      run_callbacks :operation do
        run_callbacks operation_type do
          @result = send(operation_type)
        end
      end

    rescue JSONAPI::Exceptions::Error => e
      @result = JSONAPI::ErrorsOperationResult.new(e.errors[0].code, e.errors)
    end

    def find
      filters = params[:filters]
      include_directives = params[:include_directives]
      sort_criteria = params[:sort_criteria]
      paginator = params[:paginator]
      fields = params[:fields]
      serializer = params[:serializer]

      verified_filters = resource_klass.verify_filters(filters, context)

      find_options = {
        context: context,
        sort_criteria: sort_criteria,
        paginator: paginator,
        fields: fields,
        filters: verified_filters,
        include_directives: include_directives
      }

      resource_set = find_resource_set(resource_klass,
                                       include_directives,
                                       find_options)

      resource_set.populate!(serializer, context, find_options)

      page_options = result_options
      if (top_level_meta_include_record_count || (paginator && paginator.requires_record_count))
        page_options[:record_count] = resource_klass.count(verified_filters,
                                                           context: context,
                                                           include_directives: include_directives)
      end

      if (top_level_meta_include_page_count && paginator && page_options[:record_count])
        page_options[:page_count] = paginator ? paginator.calculate_page_count(page_options[:record_count]) : 1
      end

      if JSONAPI.configuration.top_level_links_include_pagination && paginator
        page_options[:pagination_params] = paginator.links_page_params(page_options.merge(fetched_resources: resource_set))
      end

      return JSONAPI::ResourcesSetOperationResult.new(:ok, resource_set, page_options)
    end

    def show
      include_directives = params[:include_directives]
      fields = params[:fields]
      id = params[:id]
      serializer = params[:serializer]

      key = resource_klass.verify_key(id, context)

      find_options = {
        context: context,
        fields: fields,
        filters: { resource_klass._primary_key => key },
        include_directives: include_directives
      }

      resource_set = find_resource_set(resource_klass,
                                       include_directives,
                                       find_options)

      fail JSONAPI::Exceptions::RecordNotFound.new(id) if resource_set.resource_klasses.empty?
      resource_set.populate!(serializer, context, find_options)

      return JSONAPI::ResourceSetOperationResult.new(:ok, resource_set, result_options)
    end

    def show_relationship
      parent_key = params[:parent_key]
      relationship_type = params[:relationship_type].to_sym
      paginator = params[:paginator]
      sort_criteria = params[:sort_criteria]
      include_directives = params[:include_directives]
      fields = params[:fields]

      parent_resource = resource_klass.find_by_key(parent_key, context: context)

      find_options = {
          context: context,
          sort_criteria: sort_criteria,
          paginator: paginator,
          fields: fields,
          include_directives: include_directives
      }

      resource_id_tree = find_related_resource_id_tree(resource_klass,
                                                       JSONAPI::ResourceIdentity.new(resource_klass, parent_key),
                                                       relationship_type,
                                                       find_options,
                                                       nil)

      return JSONAPI::RelationshipOperationResult.new(:ok,
                                                      parent_resource,
                                                      resource_klass._relationship(relationship_type),
                                                      resource_id_tree.fragments.keys,
                                                      result_options)
    end

    def show_related_resource
      include_directives = params[:include_directives]
      source_klass = params[:source_klass]
      source_id = params[:source_id]
      relationship_type = params[:relationship_type]
      serializer = params[:serializer]
      fields = params[:fields]

      find_options = {
          context: context,
          fields: fields,
          filters: {},
          include_directives: include_directives
      }

      source_resource = source_klass.find_by_key(source_id, context: context, fields: fields)

      resource_set = find_related_resource_set(source_resource,
                                               relationship_type,
                                               include_directives,
                                               find_options)

      resource_set.populate!(serializer, context, find_options)

      return JSONAPI::ResourceSetOperationResult.new(:ok, resource_set, result_options)
    end

    def show_related_resources
      source_klass = params[:source_klass]
      source_id = params[:source_id]
      relationship_type = params[:relationship_type]
      filters = params[:filters]
      sort_criteria = params[:sort_criteria]
      paginator = params[:paginator]
      fields = params[:fields]
      include_directives = params[:include_directives]
      serializer = params[:serializer]

      verified_filters = resource_klass.verify_filters(filters, context)

      find_options = {
        filters:  verified_filters,
        sort_criteria: sort_criteria,
        paginator: paginator,
        fields: fields,
        context: context,
        include_directives: include_directives
      }

      source_resource = source_klass.find_by_key(source_id, context: context, fields: fields)

      resource_set = find_related_resource_set(source_resource,
                                               relationship_type,
                                               include_directives,
                                               find_options)

      resource_set.populate!(serializer, context, find_options)

      opts = result_options
      if ((top_level_meta_include_record_count) ||
          (paginator && paginator.requires_record_count) ||
          (top_level_meta_include_page_count))

        opts[:record_count] = source_resource.class.count_related(
            source_resource.identity,
            relationship_type,
            find_options)
      end

      if (top_level_meta_include_page_count && opts[:record_count])
        opts[:page_count] = paginator.calculate_page_count(opts[:record_count])
      end

      opts[:pagination_params] = if paginator && JSONAPI.configuration.top_level_links_include_pagination
                                   page_options = {}
                                   page_options[:record_count] = opts[:record_count] if paginator.requires_record_count
                                   paginator.links_page_params(page_options.merge(fetched_resources: resource_set))
                                 else
                                   {}
                                 end

      return JSONAPI::RelatedResourcesSetOperationResult.new(:ok,
                                                             source_resource,
                                                             relationship_type,
                                                             resource_set,
                                                             opts)
    end

    def create_resource
      include_directives = params[:include_directives]
      fields = params[:fields]
      serializer = params[:serializer]

      data = params[:data]
      resource = resource_klass.create(context)
      result = resource.replace_fields(data)

      find_options = {
          context: context,
          fields: fields,
          filters: { resource_klass._primary_key => resource.id },
          include_directives: include_directives
      }

      resource_set = find_resource_set(resource_klass,
                                       include_directives,
                                       find_options)

      resource_set.populate!(serializer, context, find_options)

      return JSONAPI::ResourceSetOperationResult.new((result == :completed ? :created : :accepted), resource_set, result_options)
    end

    def remove_resource
      resource_id = params[:resource_id]

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.remove

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted, result_options)
    end

    def replace_fields
      resource_id = params[:resource_id]
      include_directives = params[:include_directives]
      fields = params[:fields]
      serializer = params[:serializer]

      data = params[:data]

      resource = resource_klass.find_by_key(resource_id, context: context)

      result = resource.replace_fields(data)

      find_options = {
          context: context,
          fields: fields,
          filters: { resource_klass._primary_key => resource.id },
          include_directives: include_directives
      }

      resource_set = find_resource_set(resource_klass,
                                       include_directives,
                                       find_options)

      resource_set.populate!(serializer, context, find_options)

      return JSONAPI::ResourceSetOperationResult.new((result == :completed ? :ok : :accepted), resource_set, result_options)
    end

    def replace_to_one_relationship
      resource_id = params[:resource_id]
      relationship_type = params[:relationship_type].to_sym
      key_value = params[:key_value]

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.replace_to_one_link(relationship_type, key_value)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted, result_options)
    end

    def replace_polymorphic_to_one_relationship
      resource_id = params[:resource_id]
      relationship_type = params[:relationship_type].to_sym
      key_value = params[:key_value]
      key_type = params[:key_type]

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.replace_polymorphic_to_one_link(relationship_type, key_value, key_type)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted, result_options)
    end

    def create_to_many_relationships
      resource_id = params[:resource_id]
      relationship_type = params[:relationship_type].to_sym
      data = params[:data]

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.create_to_many_links(relationship_type, data)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted, result_options)
    end

    def replace_to_many_relationships
      resource_id = params[:resource_id]
      relationship_type = params[:relationship_type].to_sym
      data = params.fetch(:data)

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.replace_to_many_links(relationship_type, data)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted, result_options)
    end

    def remove_to_many_relationships
      resource_id = params[:resource_id]
      relationship_type = params[:relationship_type].to_sym
      associated_keys = params[:associated_keys]

      resource = resource_klass.find_by_key(resource_id, context: context)

      complete = true
      associated_keys.each do |key|
        result = resource.remove_to_many_link(relationship_type, key)
        if complete && result != :completed
          complete = false
        end
      end
      return JSONAPI::OperationResult.new(complete ? :no_content : :accepted, result_options)
    end

    def remove_to_one_relationship
      resource_id = params[:resource_id]
      relationship_type = params[:relationship_type].to_sym

      resource = resource_klass.find_by_key(resource_id, context: context)
      result = resource.remove_to_one_link(relationship_type)

      return JSONAPI::OperationResult.new(result == :completed ? :no_content : :accepted, result_options)
    end

    def result_options
      options = {}
      options[:warnings] = params[:warnings] if params[:warnings]
      options
    end

    def find_resource_set(resource_klass, include_directives, options)
      include_related = include_directives.include_directives[:include_related] if include_directives

      resource_id_tree = find_resource_id_tree(resource_klass, options, include_related)

      JSONAPI::ResourceSet.new(resource_id_tree)
    end

    def find_related_resource_set(resource, relationship_name, include_directives, options)
      include_related = include_directives.include_directives[:include_related] if include_directives

      resource_id_tree = find_resource_id_tree_from_resource_relationship(resource, relationship_name, options, include_related)

      JSONAPI::ResourceSet.new(resource_id_tree)
    end

    def top_level_meta_include_record_count
      JSONAPI.configuration.top_level_meta_include_record_count
    end

    def top_level_meta_include_page_count
      JSONAPI.configuration.top_level_meta_include_page_count
    end

    private
    def find_related_resource_id_tree(resource_klass, source_id, relationship_name, find_options, include_related)
      options = find_options.except(:include_directives)
      options[:cache] = resource_klass.caching?

      fragments = resource_klass.find_included_fragments([source_id], relationship_name, options)

      primary_resource_id_tree = PrimaryResourceIdTree.new
      primary_resource_id_tree.add_resource_fragments(fragments, include_related)

      load_included(resource_klass, primary_resource_id_tree, include_related, options)

      primary_resource_id_tree
    end

    def find_resource_id_tree(resource_klass, find_options, include_related)
      options = find_options
      options[:cache] = resource_klass.caching?

      fragments = resource_klass.find_fragments(find_options[:filters], options)

      primary_resource_id_tree = PrimaryResourceIdTree.new
      primary_resource_id_tree.add_resource_fragments(fragments, include_related)

      load_included(resource_klass, primary_resource_id_tree, include_related, options)

      primary_resource_id_tree
    end

    def find_resource_id_tree_from_resource_relationship(resource, relationship_name, find_options, include_related)
      relationship = resource.class._relationship(relationship_name)

      options = find_options.except(:include_directives)
      options[:cache] = relationship.resource_klass.caching?

      fragments = resource.class.find_related_fragments([resource.identity], relationship_name, options)

      primary_resource_id_tree = PrimaryResourceIdTree.new
      primary_resource_id_tree.add_resource_fragments(fragments, include_related)

      load_included(resource_klass, primary_resource_id_tree, include_related, options)

      primary_resource_id_tree
    end

    def load_included(resource_klass, source_resource_id_tree, include_related, options)
      source_rids = source_resource_id_tree.fragments.keys

      include_related.try(:each_key) do |key|
        relationship = resource_klass._relationship(key)
        relationship_name = relationship.name.to_sym

        find_related_resource_options = options.except(:filters, :sort_criteria, :paginator)
        find_related_resource_options[:sort_criteria] = relationship.resource_klass.default_sort
        find_related_resource_options[:cache] = resource_klass.caching?

        related_fragments = resource_klass.find_included_fragments(
          source_rids, relationship_name, find_related_resource_options
        )

        related_resource_id_tree = source_resource_id_tree.fetch_related_resource_id_tree(relationship)
        related_resource_id_tree.add_resource_fragments(related_fragments, include_related[key][include_related])

        # Now recursively get the related resources for the currently found resources
        load_included(relationship.resource_klass,
                      related_resource_id_tree,
                      include_related[relationship_name][:include_related],
                      options)
      end
    end
  end
end
