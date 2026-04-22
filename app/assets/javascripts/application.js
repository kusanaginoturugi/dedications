document.addEventListener("DOMContentLoaded", () => {
  // メニューの外側をクリックしたら閉じる
  document.addEventListener("click", (event) => {
    const menuTree = document.querySelector(".menu-tree");
    if (!menuTree) return;

    if (!menuTree.contains(event.target)) {
      menuTree.removeAttribute("open");
    }
  });

  document.querySelectorAll("[data-href]").forEach((element) => {
    element.addEventListener("click", (event) => {
      if (event.target.closest("a, button, input, select, textarea, label")) return;
      window.location.href = element.dataset.href;
    });

    element.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        window.location.href = element.dataset.href;
      }
    });
  });

  const container = document.querySelector("[data-order-form]");
  if (!container) return;

  const formTypeSelect = container.querySelector("[data-form-type-select='true']");
  const quantityCalcInputs = Array.from(container.querySelectorAll("[data-quantity-calc-input='true']"));
  const totalQuantityDisplay = container.querySelector("[data-total-quantity-display]");
  const totalAmountDisplay = container.querySelector("[data-total-amount-display]");
  const searchInput = container.querySelector("[data-congregation-search-input]");
  const hiddenCongregationInput = container.querySelector("[data-congregation-search-target='hidden']");
  const searchResults = container.querySelector("[data-congregation-results]");
  const selectedCongregation = container.querySelector("[data-selected-congregation]");

  const renderSelection = (item) => {
    selectedCongregation.innerHTML = item ?
      `<button type="button" class="search-result active">${item.code} ${item.name}</button>` :
      "<span>未選択</span>";
  };

  const formatCurrency = (value) => `¥${new Intl.NumberFormat("ja-JP").format(value)}`;
  const unitPrices = JSON.parse(container.dataset.unitPrices || "{}");
  const unitPrice = () => Number(unitPrices[formTypeSelect.value] || totalAmountDisplay?.dataset.unitPrice || 0);

  const updateTotalQuantity = () => {
    if (!totalQuantityDisplay || quantityCalcInputs.length < 2) return;

    const [startInput, endInput] = quantityCalcInputs;
    const start = Number(startInput.value);
    const end = Number(endInput.value);

    if (startInput.value === "" || endInput.value === "" || Number.isNaN(start) || Number.isNaN(end)) {
      totalQuantityDisplay.textContent = "未計算";
      if (totalAmountDisplay) totalAmountDisplay.textContent = "未計算";
      return;
    }

    const quantity = end - start + 1;
    totalQuantityDisplay.textContent = `${quantity} 本`;
    if (totalAmountDisplay) totalAmountDisplay.textContent = formatCurrency(quantity * unitPrice());
  };

  let lastSearchToken = 0;

  searchInput.addEventListener("input", async () => {
    const query = searchInput.value.replace(/\D/g, "");
    hiddenCongregationInput.value = "";
    renderSelection(null);

    if (query.length < 2) {
      searchResults.innerHTML = "";
      return;
    }

    const searchToken = ++lastSearchToken;
    const response = await fetch(`${container.dataset.congregationsUrl}?query=${encodeURIComponent(query)}`, {
      headers: { Accept: "application/json" }
    });

    if (!response.ok || searchToken !== lastSearchToken) return;

    const items = await response.json();
    searchResults.innerHTML = "";

    items.forEach((item) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "search-result";
      button.textContent = `${item.code} ${item.name}`;
      button.addEventListener("click", () => {
        hiddenCongregationInput.value = item.id;
        searchInput.value = item.code;
        renderSelection(item);
        searchResults.innerHTML = "";
      });
      searchResults.appendChild(button);
    });
  });

  formTypeSelect.addEventListener("change", updateTotalQuantity);

  quantityCalcInputs.forEach((input) => input.addEventListener("input", updateTotalQuantity));
  updateTotalQuantity();
});
