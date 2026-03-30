FactoryBot.define do
  factory :speaker do
    project
    sequence(:name) { |n| "Speaker #{n}" }
  end
end
