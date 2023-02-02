module Weaponizable
  extend ActiveSupport::Concern

  included do
    has_many :weapons, class_name: 'Weaponizable::Weapon',
             as: :weaponizable, inverse_of: :weaponizable
  end

  def self.table_name_prefix
    'weaponizable_'
  end
end