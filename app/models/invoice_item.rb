# An extra line on an invoice besides the hours charge, e.g. a reimbursement or an equipment allowance.
class InvoiceItem < ApplicationRecord
  belongs_to :invoice, inverse_of: :items

  validates :description, presence: true, length: { maximum: 60 }
  validates :quantity, numericality: { greater_than: 0, less_than: 100_000 }
  validates :rate, numericality: { greater_than_or_equal_to: 0, less_than: 10_000_000_000 }

  def amount = (quantity * rate).round(2)
end
