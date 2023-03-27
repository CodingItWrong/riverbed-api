class BelongsToUserValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if value.user != record.user
      record.errors.add(attribute, "not found")
    end
  end
end
