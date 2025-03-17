FactoryBot.define do
  factory :game do
    sequence(:player_name) { |n| "プレイヤー#{n}" }
    score { 0 }

    trait :with_words do
      transient do
        words_count { 3 }
      end

      after(:create) do |game, evaluator|
        create_list(:game_word, evaluator.words_count, game: game)
      end
    end

    trait :completed do
      score { 10 }
    end

    trait :high_score do
      score { 20 }
    end
  end
end