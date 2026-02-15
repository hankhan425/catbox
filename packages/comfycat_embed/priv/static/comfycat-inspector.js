(function () {
  "use strict";

  var active = false;
  var overlay = null;
  var hoveredEl = null;

  function createOverlay() {
    var el = document.createElement("div");
    el.id = "comfycat-inspector-overlay";
    el.style.cssText =
      "position:fixed;pointer-events:none;z-index:2147483647;" +
      "border:2px solid #7c3aed;background:rgba(124,58,237,0.12);" +
      "transition:all 80ms ease-out;display:none;";
    document.body.appendChild(el);
    return el;
  }

  function positionOverlay(target) {
    if (!overlay) overlay = createOverlay();
    var rect = target.getBoundingClientRect();
    overlay.style.top = rect.top + "px";
    overlay.style.left = rect.left + "px";
    overlay.style.width = rect.width + "px";
    overlay.style.height = rect.height + "px";
    overlay.style.display = "block";
  }

  function hideOverlay() {
    if (overlay) overlay.style.display = "none";
  }

  function buildSelector(el) {
    if (el.id) return "#" + el.id;

    var parts = [];
    var current = el;

    while (current && current !== document.body && parts.length < 4) {
      var tag = current.tagName.toLowerCase();
      if (current.id) {
        parts.unshift("#" + current.id);
        break;
      }

      var parent = current.parentElement;
      if (parent) {
        var siblings = Array.from(parent.children).filter(
          function (c) { return c.tagName === current.tagName; }
        );
        if (siblings.length > 1) {
          var idx = siblings.indexOf(current) + 1;
          tag += ":nth-of-type(" + idx + ")";
        }
      }

      parts.unshift(tag);
      current = parent;
    }

    return parts.join(" > ");
  }

  function truncate(str, len) {
    if (!str) return "";
    str = str.trim().replace(/\s+/g, " ");
    return str.length > len ? str.substring(0, len) + "..." : str;
  }

  function onMouseOver(e) {
    if (!active) return;
    hoveredEl = e.target;
    positionOverlay(hoveredEl);
  }

  function onMouseOut() {
    if (!active) return;
    hoveredEl = null;
    hideOverlay();
  }

  function onClick(e) {
    if (!active || !hoveredEl) return;
    e.preventDefault();
    e.stopPropagation();

    var el = hoveredEl;
    var payload = {
      tag: el.tagName.toLowerCase(),
      id: el.id || null,
      classes: Array.from(el.classList).join(" ") || null,
      text: truncate(el.textContent, 120),
      selector: buildSelector(el),
      page: window.location.pathname
    };

    window.parent.postMessage(
      { type: "comfycat:element-selected", payload: payload },
      "*"
    );
  }

  function startInspect() {
    if (active) return;
    active = true;
    document.body.style.cursor = "crosshair";
    document.addEventListener("mouseover", onMouseOver, true);
    document.addEventListener("mouseout", onMouseOut, true);
    document.addEventListener("click", onClick, true);
  }

  function stopInspect() {
    if (!active) return;
    active = false;
    hoveredEl = null;
    document.body.style.cursor = "";
    hideOverlay();
    document.removeEventListener("mouseover", onMouseOver, true);
    document.removeEventListener("mouseout", onMouseOut, true);
    document.removeEventListener("click", onClick, true);
  }

  window.addEventListener("message", function (e) {
    if (e.data === "comfycat:start-inspect") startInspect();
    else if (e.data === "comfycat:stop-inspect") stopInspect();
  });
})();
