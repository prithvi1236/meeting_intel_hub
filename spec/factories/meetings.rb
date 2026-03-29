FactoryBot.define do
  factory :meeting do
    project
    sequence(:title) { |n| "Meeting #{n}" }
    status { "pending" }
  end
end
