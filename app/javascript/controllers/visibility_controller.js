import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["hideable", "disableable"];

  toggleVisibility() {
    this.hideableTargets.forEach((hideableTarget) => {
      hideableTarget.classList.toggle("hidden");
    });

    this.disableableTargets.forEach((el) => {
      el.disabled = !el.disabled;
    });
  }
}
