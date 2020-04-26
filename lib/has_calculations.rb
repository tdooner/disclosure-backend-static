module HasCalculations
  extend ActiveSupport::Concern

  def calculation(name)
    @_calculations_cache ||= calculations.index_by(&:name)
    @_calculations_cache[name.to_s].try(:value)
  end

  def save_calculation(name, value)
    calculations
      .where(name: name)
      .first_or_create
      .update(value: value)
  end

  included do
    has_many :calculations, as: :subject
  end
end
