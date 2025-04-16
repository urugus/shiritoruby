import { Controller } from "@hotwired/stimulus";

// 複数選択削除機能のコントローラー
export default class extends Controller {
  static targets = ["selectAll", "wordCheckbox", "bulkDeleteButton"];

  connect() {
    this.updateBulkDeleteButton();
  }

  // 全選択チェックボックスの切り替え
  toggleAll() {
    const checked = this.selectAllTarget.checked;
    this.wordCheckboxTargets.forEach((checkbox) => {
      checkbox.checked = checked;
    });
    this.updateBulkDeleteButton();
  }

  // 個別チェックボックスの切り替え
  toggleOne() {
    // 全てのチェックボックスがチェックされているか確認
    const allChecked = this.wordCheckboxTargets.every(
      (checkbox) => checkbox.checked
    );
    this.selectAllTarget.checked = allChecked;

    this.updateBulkDeleteButton();
  }

  // 削除ボタンの有効/無効を切り替え
  updateBulkDeleteButton() {
    const anyChecked = this.wordCheckboxTargets.some(
      (checkbox) => checkbox.checked
    );
    this.bulkDeleteButtonTarget.disabled = !anyChecked;
  }
}
