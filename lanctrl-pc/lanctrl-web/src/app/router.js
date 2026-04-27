export function initRouter() {
  document.querySelectorAll("[data-tab]").forEach((button) => {
    button.addEventListener("click", () => {
      document.querySelectorAll("[data-tab]").forEach((item) => item.classList.toggle("active", item === button));
      document.querySelectorAll("[data-page]").forEach((page) => page.classList.toggle("active", page.dataset.page === button.dataset.tab));
    });
  });
}
