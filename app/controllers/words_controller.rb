class WordsController < ApplicationController
  def index
    @words = Word.order(:word).page(params[:page]).per(50)
  end
end
