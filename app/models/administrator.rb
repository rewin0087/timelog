# A back-office account (separate from User). Everyone can view; create and edit are granted per account;
# a super admin has all access: delete, reveal masked data, and manage administrators.
class Administrator < ApplicationRecord
  has_secure_password
  has_many :admin_sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, :email_address, presence: true
  validates :email_address, uniqueness: true
  validates :password, length: { minimum: 10 }, allow_nil: true
  before_destroy :keep_one_super_admin
  validate :keep_one_super_admin_on_demote, on: :update

  ACCESS_LEVELS = {
    "view" => "View only",
    "create" => "View + create",
    "edit" => "View + edit",
    "create_edit" => "View + create + edit",
    "all" => "All access (super admin)"
  }.freeze

  def can?(action)
    case action
    when :view then true
    when :create then super_admin? || can_create?
    when :edit then super_admin? || can_edit?
    else super_admin? # :destroy, :reveal, :manage_admins
    end
  end

  def access_level
    return "all" if super_admin?
    { [ true, true ] => "create_edit", [ true, false ] => "create", [ false, true ] => "edit" }.fetch([ can_create?, can_edit? ], "view")
  end

  def access_level=(level)
    level = ACCESS_LEVELS.key?(level) ? level : "view"
    self.super_admin = level == "all"
    self.can_create = level.in?(%w[create create_edit all])
    self.can_edit = level.in?(%w[edit create_edit all])
  end

  def access_label = ACCESS_LEVELS.fetch(access_level)
  def initials = name.to_s.split.map(&:first).first(2).join.upcase

  private
    def last_super_admin? = super_admin_in_database && Administrator.where(super_admin: true).where.not(id: id).none?

    def keep_one_super_admin
      return unless last_super_admin?
      errors.add(:base, "The last super admin can't be removed")
      throw :abort
    end

    def keep_one_super_admin_on_demote
      errors.add(:access_level, "can't be lowered for the last super admin") if will_save_change_to_super_admin? && !super_admin? && last_super_admin?
    end
end
