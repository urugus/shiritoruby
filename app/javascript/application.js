// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// crypto.randomUUID ポリフィル
if (!crypto.randomUUID) {
  crypto.randomUUID = function() {
    // https://stackoverflow.com/a/2117523/2800218
    return ([1e7]+-1e3+-4e3+-8e3+-1e11).replace(/[018]/g, c =>
      (c ^ crypto.getRandomValues(new Uint8Array(1))[0] & 15 >> c / 4).toString(16)
    );
  };
}
