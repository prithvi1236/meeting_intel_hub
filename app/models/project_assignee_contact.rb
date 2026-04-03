# frozen_string_literal: true

class ProjectAssigneeContact < ApplicationRecord
  attr_accessor :aliases_text

  belongs_to :project

  normalizes :assignee_name_normalized, with: ->(n) { n.to_s.downcase.strip }
  normalizes :default_email, with: ->(e) { e.to_s.strip }

  validates :assignee_name_normalized, presence: true
  validates :default_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :assignee_name_normalized, uniqueness: { scope: :project_id }

  before_validation :normalize_aliases_list

  # Returns all normalized strings to match against (canonical name + aliases).
  def match_keys
    keys = [ assignee_name_normalized ]
    Array(aliases).each do |a|
      k = a.to_s.downcase.strip
      keys << k if k.present?
    end
    keys.uniq
  end

  private
    def normalize_aliases_list
      self.aliases = Array(aliases).map { |a| a.to_s.strip }.reject(&:blank?).uniq
    end
end
