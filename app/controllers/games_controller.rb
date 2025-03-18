class GamesController < ApplicationController
  def index
    # メインのゲーム画面を表示
  end

  def rankings
    # フィルタリングとソートのパラメータを取得
    @period = params[:period].to_i
    @player_name = params[:player_name]
    @sort_by = params[:sort_by] || "score"

    # ベースクエリを構築
    @games = Game.all

    # 期間フィルタを適用
    @games = @games.by_date(@period) if @period.positive?

    # プレイヤー名フィルタを適用
    @games = @games.by_player(@player_name) if @player_name.present?

    # ソート順を適用
    case @sort_by
    when "recent"
      @games = @games.recent
    when "time"
      @games = @games.order("duration_seconds ASC NULLS LAST")
    else # 'score'がデフォルト
      @games = @games.high_scores
    end

    # 結果を制限
    @games = @games.limit(50)
  end
end
