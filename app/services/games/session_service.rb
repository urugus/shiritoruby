module Games
  class SessionService
    # セッション関連のエラー
    class SessionError < StandardError; end
    class SessionNotFoundError < SessionError; end
    class InvalidSessionError < SessionError; end

    # セッションからゲームセッションマネージャーを取得
    # @param session_id [String] セッションID
    # @param current_session [ActionDispatch::Request::Session] 現在のセッション
    # @return [Games::SessionManager] セッションマネージャー
    def self.retrieve_session_manager(session_id = nil, current_session = nil)
      game_id = find_game_id(session_id, current_session)

      unless game_id
        raise SessionNotFoundError, "ゲームセッションが見つかりません"
      end

      rebuild_session_manager(game_id)
    end

    # セッションIDまたは現在のセッションからゲームIDを取得
    # @param session_id [String] セッションID
    # @param current_session [ActionDispatch::Request::Session] 現在のセッション
    # @return [String, nil] ゲームID
    def self.find_game_id(session_id = nil, current_session = nil)
      game_id = nil

      # デバッグ用ログ出力
      Rails.logger.debug "find_game_id: セッションID = #{session_id}, 現在のセッション = #{current_session.inspect}"

      # セッションIDからゲームIDを取得
      if session_id.present?
        game_id = extract_game_id_from_session_record(session_id)
        Rails.logger.debug "セッションIDからのゲームID取得結果: #{game_id}"
      end

      # 現在のセッションからゲームIDを取得（セッションIDからの取得に失敗した場合）
      if game_id.nil? && current_session
        game_id = current_session[:game_id]
        Rails.logger.debug "現在のセッションからのゲームID取得結果: #{game_id}"
      end

      Rails.logger.debug "最終的なゲームID: #{game_id}"
      game_id
    end

    # セッションレコードからゲームIDを抽出
    # @param session_id [String] セッションID
    # @return [String, nil] ゲームID
    def self.extract_game_id_from_session_record(session_id)
      # デバッグ用ログ出力
      Rails.logger.debug "extract_game_id_from_session_record: セッションID = #{session_id}"

      # 完全一致でのみセッションレコードを検索
      session_record = ActiveRecord::SessionStore::Session.find_by(session_id: session_id)

      # デバッグ用ログ出力
      if session_record
        Rails.logger.debug "セッションレコードが見つかりました: #{session_record.inspect}"
      else
        Rails.logger.debug "セッションレコードが見つかりませんでした"
      end

      return nil unless session_record&.data.present?

      # セッションデータを解析
      session_data = parse_session_data(session_record.data)
      Rails.logger.debug "解析されたセッションデータ: #{session_data.inspect}"
      session_data["game_id"]
    rescue JSON::ParserError => e
      Rails.logger.error "JSONの解析に失敗しました: #{e.message}"
      nil
    rescue NoMethodError, TypeError => e
      Rails.logger.error "セッションデータの型エラーが発生しました: #{e.message}"
      nil
    end

    # セッションデータを解析
    # @param data [String, Hash] セッションデータ
    # @return [Hash] 解析されたセッションデータ
    def self.parse_session_data(data)
      if data.is_a?(String)
        JSON.parse(data)
      elsif data.is_a?(Hash)
        data
      else
        data.to_h rescue {}
      end
    end

    # ゲームIDからセッションマネージャーを再構築
    # @param game_id [String] ゲームID
    # @return [Games::SessionManager] セッションマネージャー
    def self.rebuild_session_manager(game_id)
      game = Game.find_by(id: game_id)

      unless game
        raise SessionNotFoundError, "ゲームが見つかりません"
      end

      # 既存のゲームからセッションマネージャーを再構築
      session_manager = Games::SessionManager.new(game.player_name)
      session_manager.instance_variable_set(:@game, game)
      session_manager.instance_variable_set(:@start_time, game.created_at)

      # 使用済み単語を復元
      game_words = game.game_words.includes(:word).by_turn_order
      used_words = game_words.map { |gw| gw.word.word }
      session_manager.instance_variable_set(:@used_words, used_words)

      # 最後に使用した単語を設定
      last_game_word = game_words.last
      last_word = last_game_word&.word&.word
      session_manager.instance_variable_set(:@last_word, last_word)

      # ゲームの状態を設定
      current_state = determine_game_state(game)
      session_manager.instance_variable_set(:@current_state, current_state)

      # プレイヤーのターン状態を設定
      session_manager.instance_variable_set(
        :@player_turn,
        current_state == Games::SessionManager::GAME_STATE[:player_turn]
      )

      session_manager
    rescue SessionNotFoundError => e
      # SessionNotFoundErrorはそのまま再送出
      raise
    rescue => e
      Rails.logger.error "セッションマネージャー復元エラー: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise SessionError, "ゲームセッションの復元に失敗しました: #{e.message}"
    end

    # ゲームの状態を決定
    # @param game [Game] ゲーム
    # @return [String] ゲームの状態
    def self.determine_game_state(game)
      if game.game_words.count.zero?
        # 単語がまだない場合（ゲーム開始直後）はプレイヤーのターン
        Games::SessionManager::GAME_STATE[:player_turn]
      elsif game.game_words.count.odd?
        # 単語数が奇数の場合はコンピューターのターン
        Games::SessionManager::GAME_STATE[:computer_turn]
      else
        # 単語数が偶数かつ0でない場合はプレイヤーのターン
        Games::SessionManager::GAME_STATE[:player_turn]
      end
    end
  end
end
