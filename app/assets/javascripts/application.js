document.addEventListener("DOMContentLoaded", () => {
  const container = document.querySelector("[data-order-form]");
  if (!container) return;

  const definitions = JSON.parse(container.dataset.formDefinitions);
  const formTypeSelect = container.querySelector("[data-form-type-select='true']");
  const quantityInputs = Array.from(container.querySelectorAll("[data-quantity-input='true']"));
  const amountInputs = Array.from(container.querySelectorAll("input[name*='[amount]']"));
  const totalQuantity = container.querySelector("[data-total-quantity]");
  const totalAmount = container.querySelector("[data-total-amount]");
  const formDescription = container.querySelector("[data-form-description]");
  const selectedFormType = formTypeSelect.value;

  const searchInput = container.querySelector("[data-congregation-search-input]");
  const hiddenCongregationInput = container.querySelector("[data-congregation-search-target='hidden']");
  const searchResults = container.querySelector("[data-congregation-results]");
  const selectedCongregation = container.querySelector("[data-selected-congregation]");

  const formatNumber = (value) => new Intl.NumberFormat("ja-JP").format(value);
  const definition = definitions[selectedFormType];

  const updateTotals = () => {
    const quantity = quantityInputs.reduce((sum, input) => sum + Number(input.value || 0), 0);
    const amount = amountInputs.reduce((sum, input) => sum + Number(input.value || 0), 0);
    totalQuantity.textContent = formatNumber(quantity);
    totalAmount.textContent = formatNumber(amount);
  };

  const renderSelection = (item) => {
    selectedCongregation.innerHTML = item ?
      `<button type="button" class="search-result active">${item.code} ${item.name}</button>` :
      "<span>未選択</span>";
  };

  const applyAutoAmounts = () => {
    quantityInputs.forEach((input, index) => {
      const amount = Number(input.value || 0) * definition.unit_price;
      amountInputs[index].value = amount;
    });
    updateTotals();
  };

  formDescription.textContent = `固定項目: ${definition.label} / 既定単価: ¥${formatNumber(definition.unit_price)}`;

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

  quantityInputs.forEach((input) => input.addEventListener("input", applyAutoAmounts));
  amountInputs.forEach((input) => input.addEventListener("input", updateTotals));
  formTypeSelect.addEventListener("change", () => {
    const url = new URL(window.location.href);
    url.searchParams.set("form_type", formTypeSelect.value);
    window.location.href = url.toString();
  });

  applyAutoAmounts();
});
