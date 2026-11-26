(function () {
  function tokens(value) {
    var normalized = (value || "").toLowerCase().replace(/[^a-z0-9]+/g, " ").replace(/\s+/g, " ").trim();
    return normalized ? normalized.split(" ") : [];
  }

  function hasToken(haystack, token) {
    return (" " + haystack + " ").indexOf(" " + token + " ") !== -1;
  }

  function matchesTokens(haystack, query) {
    var parts = tokens(query);
    for (var i = 0; i < parts.length; i++) {
      if (!hasToken(haystack, parts[i])) return false;
    }
    return true;
  }

  var form = document.getElementById("filters");
  if (form) {
    var q = document.getElementById("q");
    var state = document.getElementById("state");
    var service = document.getElementById("service");
    var list = document.getElementById("directory");
    var countEl = document.getElementById("result-count");
    var empty = document.getElementById("empty");
    var cards = list ? Array.prototype.slice.call(list.querySelectorAll(".card")) : [];
    var index = null;

    function matchItem(item) {
      if (state.value && item.state !== state.value) return false;
      if (service.value && item.services.indexOf(service.value) === -1) return false;
      return matchesTokens(item.search || "", q.value);
    }

    function matchCard(card) {
      if (state.value && card.getAttribute("data-state") !== state.value) return false;
      if (service.value) {
        var services = card.getAttribute("data-services") || "";
        if (!hasToken(services, service.value)) return false;
      }
      return matchesTokens(card.getAttribute("data-search") || "", q.value);
    }

    function apply() {
      var visible = 0;
      if (index) {
        var allowed = {};
        for (var i = 0; i < index.length; i++) {
          if (matchItem(index[i])) allowed[index[i].url] = true;
        }
        for (var j = 0; j < cards.length; j++) {
          var show = !!allowed[cards[j].getAttribute("data-url")];
          cards[j].hidden = !show;
          if (show) visible++;
        }
      } else {
        for (var k = 0; k < cards.length; k++) {
          var showCard = matchCard(cards[k]);
          cards[k].hidden = !showCard;
          if (showCard) visible++;
        }
      }
      if (countEl) countEl.textContent = "Showing " + visible + " of " + cards.length + " centers";
      if (empty) empty.hidden = visible !== 0;
      var params = new URLSearchParams(window.location.search);
      function setParam(key, value) {
        if (value) params.set(key, value);
        else params.delete(key);
      }
      setParam("q", q.value.trim());
      setParam("state", state.value);
      setParam("service", service.value);
      var query = params.toString();
      window.history.replaceState(null, "", window.location.pathname + (query ? "?" + query : ""));
    }

    var initial = new URLSearchParams(window.location.search);
    if (initial.get("q")) q.value = initial.get("q");
    if (initial.get("state")) state.value = initial.get("state");
    if (initial.get("service")) service.value = initial.get("service");

    form.addEventListener("submit", function (event) {
      event.preventDefault();
      apply();
    });
    q.addEventListener("input", apply);
    state.addEventListener("change", apply);
    service.addEventListener("change", apply);
    var clear = document.getElementById("clear-filters");
    if (clear) {
      clear.addEventListener("click", function () {
        q.value = "";
        state.value = "";
        service.value = "";
        apply();
      });
    }

    fetch("/search-index.json")
      .then(function (response) {
        if (!response.ok) throw new Error("index");
        return response.json();
      })
      .then(function (data) {
        index = data.centers || [];
        apply();
      })
      .catch(function () {
        index = null;
        apply();
      });
  }

  var typeField = document.getElementById("request-type");
  var nameField = document.getElementById("business-name");
  var messageField = document.getElementById("message");
  if (typeField && nameField) {
    var request = new URLSearchParams(window.location.search);
    var type = request.get("type");
    var center = request.get("center");
    if (type) {
      for (var option = 0; option < typeField.options.length; option++) {
        if (typeField.options[option].value === type) typeField.value = type;
      }
    }
    if (center) {
      if (!nameField.value) nameField.value = center;
      if (messageField && !messageField.value) messageField.value = "Correction for " + center + ": ";
    }
  }

  document.addEventListener("click", function (event) {
    var node = event.target;
    if (!node) return;
    if (node.nodeType !== 1) node = node.parentElement;
    if (!node || !node.closest) return;
    var link = node.closest("a");
    if (!link || !link.href) return;

    var slug = link.getAttribute("data-business-slug");
    var raw = link.getAttribute("href") || "";
    var externalHttp = /^https?:\/\//i.test(raw);
    if (externalHttp) {
      try {
        var url = new URL(link.href, window.location.href);
        if (url.hostname === window.location.hostname) externalHttp = false;
      } catch (err) {
        externalHttp = true;
      }
    }
    if (!slug && !externalHttp) return;

    var name = link.getAttribute("data-business-name") || "";
    var location = link.getAttribute("data-link-location") || "";
    var analytics = window.analytics;
    if (analytics && typeof analytics.capture === "function") {
      analytics.capture("outbound_click", {
        business_name: name,
        business_slug: slug || "",
        destination_url: link.href,
        link_location: location
      });
      if (typeof analytics.flush === "function") analytics.flush();
    }
    if (typeof window.gtag === "function") {
      window.gtag("event", "outbound_click", {
        business_name: name,
        business_slug: slug || "",
        link_url: link.href,
        link_location: location,
        transport_type: "beacon"
      });
    }
  });
})();
