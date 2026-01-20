module JSONAPI

  # A tree structure representing the resource structure of the requested resource(s). This is an intermediate structure
  # used to keep track of the resources, by identity, found at different included relationships. It will be flattened and
  # the resource instances will be fetched from the cache or the record store.
  class ResourceIdTree

    attr_reader :fragments, :related_resource_id_trees

    # Gets the related Resource Id Tree for a relationship, and creates it first if it does not exist
    #
    # @param relationship [JSONAPI::Relationship]
    #
    # @return [JSONAPI::RelatedResourceIdTree] the new or existing resource id tree for the requested relationship
    def fetch_related_resource_id_tree(relationship)
      relationship_name = relationship.name.to_sym
      @related_resource_id_trees[relationship_name] ||= RelatedResourceIdTree.new(relationship, self)
    end

    private

    def init_included_relationships(fragment, include_related)
      include_related && include_related.each_key do |relationship_name|
        fragment.initialize_related(relationship_name)
      end
    end
  end

  class PrimaryResourceIdTree < ResourceIdTree

    # Creates a PrimaryResourceIdTree with no resources and no related ResourceIdTrees
    def initialize
      @fragments ||= {}
      @related_resource_id_trees ||= {}
    end

    # Adds each Resource Fragment to the Resources hash
    #
    # @param fragments [Hash]
    # @param include_related [Hash]
    #
    # @return [null]
    def add_resource_fragments(fragments, include_related)
      fragments.each_value do |fragment|
        add_resource_fragment(fragment, include_related)
      end
    end

    # Adds a Resource Fragment to the Resources hash
    #
    # @param fragment [JSONAPI::ResourceFragment]
    # @param include_related [Hash]
    #
    # @return [null]
    def add_resource_fragment(fragment, include_related)
      fragment.primary = true

      init_included_relationships(fragment, include_related)

      @fragments[fragment.identity] = fragment
    end
  end

  class RelatedResourceIdTree < ResourceIdTree

    attr_reader :parent_relationship, :source_resource_id_tree

    # Creates a RelatedResourceIdTree with no resources and no related ResourceIdTrees. A connection to the parent
    # ResourceIdTree is maintained.
    #
    # @param parent_relationship [JSONAPI::Relationship]
    # @param source_resource_id_tree [JSONAPI::ResourceIdTree]
    #
    # @return [JSONAPI::RelatedResourceIdTree] the new or existing resource id tree for the requested relationship
    def initialize(parent_relationship, source_resource_id_tree)
      @fragments ||= {}
      @related_resource_id_trees ||= {}

      @parent_relationship = parent_relationship
      @parent_relationship_name = parent_relationship.name.to_sym
      @source_resource_id_tree = source_resource_id_tree
    end

    # Adds each Resource Fragment to the Resources hash
    #
    # @param fragments [Hash]
    # @param include_related [Hash]
    #
    # @return [null]
    def add_resource_fragments(fragments, include_related)
      fragments.each_value do |fragment|
        add_resource_fragment(fragment, include_related)
      end
    end

    # Adds a Resource Fragment to the fragments hash
    #
    # @param fragment [JSONAPI::ResourceFragment]
    # @param include_related [Hash]
    #
    # @return [null]
    def add_resource_fragment(fragment, include_related)
      init_included_relationships(fragment, include_related)

      fragment.related_from.each do |rid|
        @source_resource_id_tree.fragments[rid].add_related_identity(parent_relationship.name, fragment.identity)
      end

      @fragments[fragment.identity] = fragment
    end
  end
end