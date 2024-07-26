class PutRequestSerializer < ActiveModel::Serializer
  include Utils::Formatting
  has_many :request_items, if: -> { show_items? }

  attributes :id, :distribution_center_id, :distribution_center, :request_id, :request_type, :status, :put_away_reason, :pick_up_reason, :assignee_name, :assignee_ids,
             :sequence, :completed_at, :created_at, :items_count, :not_found_items
  # attribute :request_items, if: :show_items?

  def distribution_center
    object.distribution_center&.code
  end
  
  def request_type
    object.request_type&.titleize
  end
  
  def put_away_reason
    object.put_away_reason&.titleize
  end
  
  def pick_up_reason
    object.pick_up_reason&.titleize
  end
  
  def status
    object.status&.titleize
  end
  
  def assignee_ids
    object.users.pluck(:id)
  end
  
  def assignee_name
    object.users.map(&:full_name).join(', ')
  end
  
  def completed_at
    format_ist_time(object.completed_at)
  end

  def created_at
    format_ist_time(object.created_at)
  end
  
  def items_count
    object.request_items.count
  end
  
  # def request_items
  #   object.request_items.map { |item| RequestItemSerializer.new(item) }
  # end
  
  def not_found_items
    object.request_items.status_not_found.count
  end
  
  def show_items?
    @instance_options[:show_items]
  end

end
