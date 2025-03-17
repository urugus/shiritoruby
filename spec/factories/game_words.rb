FactoryBot.define do
  factory :game_word do
    association :game
    association :word
    sequence(:turn) { |n| n }

    trait :first_turn do
      turn { 1 }
    end

    trait :player_turn do
      transient do
        turn_number { 1 }
      end

      turn { turn_number * 2 - 1 } # プレイヤーは奇数ターン
    end

    trait :computer_turn do
      transient do
        turn_number { 1 }
      end

      turn { turn_number * 2 } # コンピュータは偶数ターン
    end
  end
end