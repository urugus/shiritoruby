module Games
  class GameState
    # ゲームの状態を表す定数
    STATES = {
      waiting_for_player: "waiting_for_player",
      player_turn: "player_turn",
      computer_turn: "computer_turn",
      game_over: "game_over"
    }.freeze

    # ゲームの終了理由
    END_REASONS = {
      computer_surrender: "computer_surrender",
      player_timeout: "player_timeout"
    }.freeze

    attr_reader :current_state, :end_reason

    def initialize
      @current_state = STATES[:waiting_for_player]
      @end_reason = nil
    end

    def start_game
      @current_state = STATES[:player_turn]
    end

    def to_player_turn
      @current_state = STATES[:player_turn]
    end

    def to_computer_turn
      @current_state = STATES[:computer_turn]
    end

    def end_game(reason)
      @current_state = STATES[:game_over]
      @end_reason = reason
    end

    def player_turn?
      @current_state == STATES[:player_turn]
    end

    def computer_turn?
      @current_state == STATES[:computer_turn]
    end

    def game_over?
      @current_state == STATES[:game_over]
    end
  end
end
