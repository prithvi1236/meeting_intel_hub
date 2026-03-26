module UuidPrimaryKey
  extend ActiveSupport::Concern

  included do
    before_create :assign_uuid_if_needed
  end

  private
    def assign_uuid_if_needed
      self.id = SecureRandom.uuid if id.blank?
    end
end
