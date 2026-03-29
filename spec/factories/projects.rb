FactoryBot.define do
  factory :project do
    user
    sequence(:name) { |n| "Project #{n}" }
  end
end
