class Character < ApplicationRecord
  self.abstract_class = true
  
  def self.table_name_prefix
    'character_'
  end

  belongs_to :level
end
