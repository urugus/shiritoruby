require 'rails_helper'

RSpec.describe 'Game', type: :system do
  before do
    driven_by(:selenium_chrome_headless)
  end

  it 'displays the game page' do
    visit root_path
    expect(page).to have_content('ShiritoRuby')
    expect(page).to have_content('Rubyしりとりゲーム')
  end
end
