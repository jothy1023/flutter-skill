/**
 * flutter-skill Web SDK
 *
 * Lightweight in-browser bridge that lets flutter-skill automate web apps.
 * Include this script in your page during development — it registers
 * window.__FLUTTER_SKILL__ and window.__FLUTTER_SKILL_CALL__ so the
 * flutter-skill proxy can interact with the DOM.
 *
 * Usage:
 *   <script src="https://unpkg.com/flutter-skill@latest/web/flutter-skill.js"></script>
 *
 * Or conditionally in your build:
 *   if (process.env.NODE_ENV === 'development') require('flutter-skill/web');
 */
(function () {
  "use strict";

  if (window.__FLUTTER_SKILL__) return; // already loaded

  // ---------------------------------------------------------------
  // Registry
  // ---------------------------------------------------------------
  var sdk = {
    version: "1.0.0",
    framework: "web",
  };
  window.__FLUTTER_SKILL__ = sdk;

  // ---------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------

  /** Collect all semantics roots (shadow DOMs under flt-glass-pane, etc.) */
  function getFlutterSemanticsRoots() {
    var roots = [];
    // Flutter 3.x: flt-glass-pane with shadow root containing flt-semantics
    var glassPane = document.querySelector('flt-glass-pane');
    if (glassPane && glassPane.shadowRoot) {
      roots.push(glassPane.shadowRoot);
    }
    // Flutter 3.22+: may use <flutter-view> with shadow root
    var flutterViews = document.querySelectorAll('flutter-view');
    for (var i = 0; i < flutterViews.length; i++) {
      if (flutterViews[i].shadowRoot) roots.push(flutterViews[i].shadowRoot);
    }
    // Also search the main document (HTML renderer or older Flutter)
    roots.push(document);
    return roots;
  }

  /** Query across all Flutter semantics roots (including shadow DOMs). */
  function querySemanticsAll(selector) {
    var roots = getFlutterSemanticsRoots();
    var results = [];
    for (var i = 0; i < roots.length; i++) {
      try {
        var nodes = roots[i].querySelectorAll(selector);
        for (var j = 0; j < nodes.length; j++) results.push(nodes[j]);
      } catch (e) { /* selector may not be supported in shadow root */ }
    }
    return results;
  }

  /** Query first match across all Flutter semantics roots. */
  function querySemantics(selector) {
    var roots = getFlutterSemanticsRoots();
    for (var i = 0; i < roots.length; i++) {
      try {
        var el = roots[i].querySelector(selector);
        if (el) return el;
      } catch (e) {}
    }
    return null;
  }

  /** Call the Dart-side bridge if available (for Flutter Web apps with FlutterSkillBinding). */
  function callDartBridge(method, params) {
    if (typeof window.__FLUTTER_SKILL_DART_CALL__ === 'function') {
      try {
        var result = window.__FLUTTER_SKILL_DART_CALL__(method, JSON.stringify(params));
        return JSON.parse(result);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /** Find a Flutter semantics element by key name. */
  function findFlutterSemanticsElement(key) {
    // 1. flt-semantics-identifier attribute (Flutter 3.19+)
    var el = querySemantics('[flt-semantics-identifier="' + key + '"]');
    if (el) return el;

    // 2. aria-label matching the key
    el = querySemantics('[aria-label="' + key + '"]');
    if (el) return el;

    // 3. id attribute matching the key (some Flutter versions)
    el = querySemantics('[id="' + key + '"]');
    if (el) return el;

    // 4. data-semantics-identifier (alternative attribute name)
    el = querySemantics('[data-semantics-identifier="' + key + '"]');
    if (el) return el;

    // 5. Walk all flt-semantics nodes and check various attributes
    var semanticsNodes = querySemanticsAll('flt-semantics, [role]');
    for (var i = 0; i < semanticsNodes.length; i++) {
      var node = semanticsNodes[i];
      // Check aria-label with flexible matching (key may have underscores, label may have spaces)
      var label = node.getAttribute('aria-label') || '';
      var normalizedKey = key.replace(/_/g, ' ');
      if (label === key || label === normalizedKey ||
          label.toLowerCase() === key.toLowerCase() ||
          label.toLowerCase() === normalizedKey.toLowerCase()) {
        return node;
      }
      // Check any attribute containing the key
      if (node.getAttribute('flt-semantics-identifier') === key ||
          node.getAttribute('data-key') === key) {
        return node;
      }
    }

    return null;
  }

  /** Find the best element matching key (data-testid / id / Flutter semantics), visible text, or semantic ref. */
  function findElement(params) {
    if (params.selector) {
      var el = document.querySelector(params.selector);
      return el || null;
    }
    
    // Handle semantic ref ID (new system)
    if (params.ref) {
      return findElementByRef(params.ref);
    }
    
    if (params.key) {
      // Standard web: data-testid first, then id
      var el =
        document.querySelector('[data-testid="' + params.key + '"]') ||
        document.getElementById(params.key);
      if (el) return el;

      // Flutter Web: search semantics tree (shadow DOM, flt-semantics nodes)
      el = findFlutterSemanticsElement(params.key);
      if (el) return el;

      return null;
    }
    if (params.text) {
      // Walk visible elements looking for matching text (including Flutter semantics)
      var allSelectors = "button, a, input, textarea, select, [role=button], label, span, p, h1, h2, h3, h4, h5, h6, li, td, th, div";
      var all = document.querySelectorAll(allSelectors);
      for (var i = 0; i < all.length; i++) {
        var node = all[i];
        if (
          node.offsetParent !== null &&
          node.textContent &&
          node.textContent.trim().indexOf(params.text) !== -1
        ) {
          return node;
        }
      }
      // Also search Flutter semantics tree for text
      var semanticsNodes = querySemanticsAll('flt-semantics, [role]');
      for (var i = 0; i < semanticsNodes.length; i++) {
        var node = semanticsNodes[i];
        var label = node.getAttribute('aria-label') || '';
        var text = node.textContent || '';
        if (label.indexOf(params.text) !== -1 || text.indexOf(params.text) !== -1) {
          return node;
        }
      }
    }
    return null;
  }

  /** Find element by semantic ref ID - regenerates refs and matches */
  function findElementByRef(refId) {
    // Check if this is a legacy ref format (btn_0, tf_1, etc.)
    if (/^[a-z]+_\d+$/.test(refId)) {
      return findElementByLegacyRef(refId);
    }
    
    // For semantic refs, we need to regenerate the inspect data and match
    var inspectResult = methods.inspect_interactive({});
    var elements = inspectResult.elements;
    
    for (var i = 0; i < elements.length; i++) {
      if (elements[i].ref === refId) {
        // Found matching ref, now find the actual DOM element
        var bounds = elements[i].bounds;
        // Use document.elementFromPoint with center of element bounds
        var centerX = bounds.x + bounds.w / 2;
        var centerY = bounds.y + bounds.h / 2;
        var el = document.elementFromPoint(centerX, centerY);
        return el;
      }
    }
    
    return null;
  }

  /** Handle legacy ref format for backward compatibility */
  function findElementByLegacyRef(refId) {
    var parts = refId.split('_');
    if (parts.length !== 2) return null;
    
    var prefix = parts[0];
    var index = parseInt(parts[1]);
    
    // Map old prefixes to new roles
    var roleMap = {
      btn: 'button',
      tf: 'input', 
      sw: 'toggle',
      sl: 'slider',
      dd: 'select',
      lnk: 'link',
      item: 'item'
    };
    
    var role = roleMap[prefix];
    if (!role) return null;
    
    // Regenerate inspect data and find elements of matching role
    var inspectResult = methods.inspect_interactive({});
    var elements = inspectResult.elements;
    var matchingElements = [];
    
    for (var i = 0; i < elements.length; i++) {
      var ref = elements[i].ref;
      if (ref.startsWith(role + ':')) {
        matchingElements.push(elements[i]);
      }
    }
    
    if (matchingElements.length === 0 || index >= matchingElements.length) {
      return null;
    }
    
    // Get element at legacy index
    var targetElement = matchingElements[index];
    var bounds = targetElement.bounds;
    var centerX = bounds.x + bounds.w / 2;
    var centerY = bounds.y + bounds.h / 2;
    return document.elementFromPoint(centerX, centerY);
  }

  /** Check if an element is a Flutter semantics node. */
  function isFlutterSemanticsElement(el) {
    if (!el || !el.tagName) return false;
    var tag = el.tagName.toLowerCase();
    return tag === 'flt-semantics' || tag === 'flt-semantics-container' ||
           tag === 'flt-semantics-img' || tag === 'flt-semantics-text-field' ||
           (el.getRootNode && el.getRootNode() !== document);
  }

  /** Dispatch tap events at the center of an element (for Flutter semantics). */
  function dispatchTapOnElement(el) {
    var rect = el.getBoundingClientRect();
    var cx = rect.x + rect.width / 2;
    var cy = rect.y + rect.height / 2;
    var opts = { clientX: cx, clientY: cy, bubbles: true, composed: true };
    el.dispatchEvent(new PointerEvent('pointerdown', opts));
    el.dispatchEvent(new PointerEvent('pointerup', opts));
    el.dispatchEvent(new MouseEvent('click', opts));
  }

  /** Build an element descriptor object. */
  function describeElement(el) {
    var rect = el.getBoundingClientRect();
    var text = (el.textContent || "").trim().substring(0, 200);
    if (!text) text = (el.getAttribute('aria-label') || "").substring(0, 200);
    var id = el.id || el.getAttribute('flt-semantics-identifier') || null;
    return {
      tag: el.tagName.toLowerCase(),
      id: id,
      testId: el.getAttribute("data-testid") || el.getAttribute("flt-semantics-identifier") || null,
      text: text,
      type: el.getAttribute("type") || null,
      role: el.getAttribute("role") || null,
      bounds: {
        x: Math.round(rect.x),
        y: Math.round(rect.y),
        width: Math.round(rect.width),
        height: Math.round(rect.height),
      },
      visible: el.offsetParent !== null || isFlutterSemanticsElement(el),
    };
  }

  // ---------------------------------------------------------------
  // Method implementations
  // ---------------------------------------------------------------

  var methods = {};

  methods.initialize = function () {
    return { success: true, framework: "web", sdk_version: sdk.version };
  };

  methods.inspect = function (params) {
    var selectors =
      "button, a, input, textarea, select, [role=button], [role=link], " +
      "[role=textbox], [role=checkbox], [role=radio], [role=tab], " +
      "[data-testid], [onclick]";
    var nodes = document.querySelectorAll(selectors);
    var elements = [];
    var seen = new Set();
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (el.offsetParent === null && el.tagName !== "INPUT") continue; // hidden
      seen.add(el);
      elements.push(describeElement(el));
    }
    // Also include Flutter semantics elements from shadow DOM
    var semanticsNodes = querySemanticsAll('[role], flt-semantics, [aria-label]');
    for (var i = 0; i < semanticsNodes.length; i++) {
      var el = semanticsNodes[i];
      if (seen.has(el)) continue;
      // Only include elements with meaningful content
      var label = el.getAttribute('aria-label');
      var role = el.getAttribute('role');
      if (!label && !role) continue;
      seen.add(el);
      elements.push(describeElement(el));
    }
    return { elements: elements };
  };

  methods.inspect_interactive = function (params) {
    var elements = [];
    var refCounts = {};

    // Semantic ref generation system - generates {role}:{content}[{index}] format
    function generateSemanticRefId(el, elementType) {
      // Map element types to semantic roles
      var role = {
        button: "button",
        text_field: "input", 
        checkbox: "toggle",
        switch: "toggle",
        radio: "toggle",
        slider: "slider",
        dropdown: "select",
        link: "link",
        list_item: "item",
        tab: "item"
      }[elementType] || "element";

      // Extract content with priority: data-testid > aria-label > text > placeholder > fallback
      var content = el.getAttribute("data-testid") ||
                   el.getAttribute("aria-label") ||
                   (el.textContent && el.textContent.trim()) ||
                   el.getAttribute("placeholder") ||
                   el.getAttribute("title") ||
                   null;

      if (content) {
        // Clean and format content (replace spaces with underscores, remove special chars)
        content = content.replace(/\s+/g, '_')
                        .replace(/[^\w]/g, '')
                        .substring(0, 30);
        if (content.length > 27) {
          content = content.substring(0, 27) + '...';
        }

        var baseRef = role + ':' + content;
        var count = refCounts[baseRef] || 0;
        refCounts[baseRef] = count + 1;

        return count === 0 ? baseRef : baseRef + '[' + count + ']';
      } else {
        // No content - use role + index fallback
        var count = refCounts[role] || 0;
        refCounts[role] = count + 1;
        return role + '[' + count + ']';
      }
    }

    function getElementType(el) {
      var tag = el.tagName.toLowerCase();
      var type = el.type ? el.type.toLowerCase() : "";
      var role = el.getAttribute("role") || "";

      if (tag === "button" || role === "button" || el.onclick) return "button";
      if (tag === "input") {
        if (["checkbox", "radio"].includes(type)) return type;
        if (["text", "email", "password", "search", "number", "tel", "url"].includes(type)) return "text_field";
        if (type === "range") return "slider";
        return "button";
      }
      if (tag === "textarea") return "text_field";
      if (tag === "select") return "dropdown";
      if (tag === "a" && el.href) return "link";
      if (role === "tab" || el.closest('[role="tablist"]')) return "tab";
      if (role === "listitem" || tag === "li") return "list_item";
      if (role === "switch") return "switch";
      if (role === "slider") return "slider";
      return "button";
    }

    function getActions(elementType) {
      switch (elementType) {
        case "text_field": return ["tap", "enter_text"];
        case "slider": return ["tap", "swipe"];
        default: return ["tap", "long_press"];
      }
    }

    function getValue(el, elementType) {
      switch (elementType) {
        case "text_field": return el.value || "";
        case "checkbox":
        case "switch": return el.checked || false;
        case "dropdown": return el.value || "";
        case "slider": return parseFloat(el.value) || 0;
        default: return undefined;
      }
    }

    var selectors = "button, a, input, textarea, select, [role=button], [role=link], " +
      "[role=textbox], [role=checkbox], [role=radio], [role=tab], [role=switch], " +
      "[role=slider], [onclick], li[onclick]";
    var nodes = document.querySelectorAll(selectors);
    // Also gather Flutter semantics interactive elements
    var semanticsInteractive = querySemanticsAll(
      '[role=button], [role=textbox], [role=checkbox], [role=radio], [role=tab], ' +
      '[role=switch], [role=slider], [role=link], flt-semantics[aria-label]'
    );
    var allNodes = [];
    var seen = new Set();
    for (var i = 0; i < nodes.length; i++) { allNodes.push(nodes[i]); seen.add(nodes[i]); }
    for (var i = 0; i < semanticsInteractive.length; i++) {
      if (!seen.has(semanticsInteractive[i])) { allNodes.push(semanticsInteractive[i]); seen.add(semanticsInteractive[i]); }
    }

    for (var i = 0; i < allNodes.length; i++) {
      var el = allNodes[i];
      if (el.offsetParent !== null || el.tagName === "INPUT" || isFlutterSemanticsElement(el)) { // visible or input or semantics
        var elementType = getElementType(el);
        var refId = generateSemanticRefId(el, elementType);
        var rect = el.getBoundingClientRect();

        var element = {
          ref: refId,
          type: el.tagName + (el.type ? "[" + el.type + "]" : ""),
          text: (el.textContent || el.value || "").trim().substring(0, 100) || null,
          actions: getActions(elementType),
          enabled: !el.disabled && !el.readOnly,
          bounds: {
            x: Math.round(rect.x),
            y: Math.round(rect.y),
            w: Math.round(rect.width),
            h: Math.round(rect.height)
          }
        };

        var label = el.getAttribute("aria-label") || el.getAttribute("placeholder") || el.getAttribute("title");
        if (label) element.label = label;

        var value = getValue(el, elementType);
        if (value !== undefined) element.value = value;

        elements.push(element);
      }
    }

    // Generate summary
    var summaryParts = Object.keys(refCounts).map(function(prefix) {
      var count = refCounts[prefix];
      var label = {
        btn: "button", tf: "text field", sw: "switch", sl: "slider",
        dd: "dropdown", item: "list item", lnk: "link", tab: "tab"
      }[prefix] || "element";
      return count + " " + label + (count === 1 ? "" : (label === "switch" ? "es" : "s"));
    });

    var summary = summaryParts.length === 0 ? 
      "No interactive elements found" :
      elements.length + " interactive: " + summaryParts.join(", ");

    return { elements: elements, summary: summary };
  };

  methods.tap = function (params) {
    // Try Dart bridge first for key-based lookups (Flutter Web)
    if (params.key && typeof window.__FLUTTER_SKILL_DART_CALL__ === 'function') {
      var dartResult = callDartBridge('tap', params);
      if (dartResult && dartResult.success) return dartResult;
    }
    var el = findElement(params);
    if (!el) return { success: false, message: "Element not found" };
    // For Flutter semantics elements, dispatch pointer events at center of bounds
    // since .click() may not propagate through the canvas
    if (isFlutterSemanticsElement(el)) {
      dispatchTapOnElement(el);
    } else {
      el.click();
    }
    return { success: true, message: "Tapped" };
  };

  methods.enter_text = function (params) {
    // Try Dart bridge first for key-based lookups (Flutter Web)
    if (params.key && typeof window.__FLUTTER_SKILL_DART_CALL__ === 'function') {
      var dartResult = callDartBridge('enter_text', params);
      if (dartResult && dartResult.success) return dartResult;
    }
    var el = findElement({ 
      key: params.key, 
      selector: params.selector,
      ref: params.ref,
      text: params.text_locator || undefined
    });
    if (!el) return { success: false, message: "Element not found" };

    // For Flutter semantics text fields, find the actual input inside or nearby
    if (isFlutterSemanticsElement(el)) {
      // Flutter creates real <input> or <textarea> elements for text fields
      var realInput = el.querySelector('input, textarea');
      if (!realInput) {
        // Try sibling or nearby input in the semantics tree
        var parent = el.parentElement;
        if (parent) realInput = parent.querySelector('input, textarea');
      }
      if (!realInput) {
        // Try finding input in the shadow root near this element
        var root = el.getRootNode();
        if (root && root !== document) {
          var inputs = root.querySelectorAll('input, textarea');
          // Find the closest input by position
          var rect = el.getBoundingClientRect();
          var cx = rect.x + rect.width / 2;
          var cy = rect.y + rect.height / 2;
          var bestDist = Infinity;
          for (var i = 0; i < inputs.length; i++) {
            var ir = inputs[i].getBoundingClientRect();
            var dx = (ir.x + ir.width / 2) - cx;
            var dy = (ir.y + ir.height / 2) - cy;
            var d = dx * dx + dy * dy;
            if (d < bestDist) { bestDist = d; realInput = inputs[i]; }
          }
        }
      }
      if (realInput) {
        el = realInput;
      } else {
        // Last resort: tap to focus, then type via keyboard events
        dispatchTapOnElement(el);
        // Small delay would be needed but we're synchronous — try dispatching input events
        return { success: true, message: "Tapped text field (no real input found)" };
      }
    }

    // Focus and set value — pick the correct prototype for React/Vue change detection
    el.focus();
    var tag = el.tagName;
    if (tag === "INPUT" || tag === "TEXTAREA") {
      var proto =
        tag === "TEXTAREA"
          ? window.HTMLTextAreaElement.prototype
          : window.HTMLInputElement.prototype;
      var nativeSetter = Object.getOwnPropertyDescriptor(proto, "value");
      if (nativeSetter && nativeSetter.set) {
        nativeSetter.set.call(el, params.text);
      } else {
        el.value = params.text;
      }
      el.dispatchEvent(new Event("input", { bubbles: true }));
      el.dispatchEvent(new Event("change", { bubbles: true }));
    } else {
      // Non-input element: try setting textContent
      el.textContent = params.text;
    }
    return { success: true, message: "Text entered" };
  };

  methods.swipe = function (params) {
    var target = params.key ? findElement({ key: params.key }) : document.body;
    if (!target) target = document.body;
    var rect = target.getBoundingClientRect();
    var cx = rect.x + rect.width / 2;
    var cy = rect.y + rect.height / 2;
    var dist = params.distance || 300;

    var dx = 0,
      dy = 0;
    switch (params.direction) {
      case "up":
        dy = -dist;
        break;
      case "down":
        dy = dist;
        break;
      case "left":
        dx = -dist;
        break;
      case "right":
        dx = dist;
        break;
    }

    target.dispatchEvent(
      new PointerEvent("pointerdown", {
        clientX: cx,
        clientY: cy,
        bubbles: true,
      })
    );
    target.dispatchEvent(
      new PointerEvent("pointermove", {
        clientX: cx + dx,
        clientY: cy + dy,
        bubbles: true,
      })
    );
    target.dispatchEvent(
      new PointerEvent("pointerup", {
        clientX: cx + dx,
        clientY: cy + dy,
        bubbles: true,
      })
    );
    return { success: true };
  };

  methods.scroll = function (params) {
    var target = params.key ? findElement({ key: params.key }) : window;
    var dist = params.distance || 300;
    var dir = params.direction || "down";
    var dx = 0,
      dy = 0;
    if (dir === "down") dy = dist;
    else if (dir === "up") dy = -dist;
    else if (dir === "right") dx = dist;
    else if (dir === "left") dx = -dist;

    if (target === window || target === document.body) {
      window.scrollBy(dx, dy);
    } else if (target) {
      target.scrollBy(dx, dy);
    }
    return { success: true };
  };

  methods.find_element = function (params) {
    // Try Dart bridge first for key-based lookups (Flutter Web)
    if (params.key && typeof window.__FLUTTER_SKILL_DART_CALL__ === 'function') {
      var dartResult = callDartBridge('find_element', params);
      if (dartResult && dartResult.found) return dartResult;
    }
    var el = findElement(params);
    if (!el) return { found: false };
    return { found: true, element: describeElement(el) };
  };

  methods.get_text = function (params) {
    // Try Dart bridge first for key-based lookups (Flutter Web)
    if (params.key && typeof window.__FLUTTER_SKILL_DART_CALL__ === 'function') {
      var dartResult = callDartBridge('get_text', params);
      if (dartResult && dartResult.text != null) return dartResult;
    }
    var el = findElement(params);
    if (!el) return { text: null };
    if (el.tagName === "INPUT" || el.tagName === "TEXTAREA") {
      return { text: el.value };
    }
    // For Flutter semantics elements, prefer aria-label over textContent
    var text = (el.textContent || "").trim();
    if (!text) {
      text = el.getAttribute('aria-label') || '';
    }
    // For flt-semantics nodes, also check aria-valuenow/aria-valuetext
    if (!text && el.tagName && el.tagName.toLowerCase() === 'flt-semantics') {
      text = el.getAttribute('aria-valuetext') || el.getAttribute('aria-valuenow') || '';
    }
    return { text: text };
  };

  methods.wait_for_element = function (params) {
    // Try Dart bridge first for key-based lookups (Flutter Web)
    if (params.key && typeof window.__FLUTTER_SKILL_DART_CALL__ === 'function') {
      var dartResult = callDartBridge('wait_for_element', params);
      if (dartResult && dartResult.found) return dartResult;
    }
    // Synchronous check — the proxy can retry with polling
    var el = findElement(params);
    return { found: !!el };
  };

  methods.go_back = function () {
    window.history.back();
    return { success: true, message: "Navigated back via history.back()" };
  };

  methods.screenshot = function () {
    // Cannot take a screenshot from inside the page.
    // Signal to the proxy that it should use CDP Page.captureScreenshot.
    return { _needs_cdp: true };
  };

  methods.get_logs = function () {
    return { logs: sdk._logs || [] };
  };

  methods.clear_logs = function () {
    sdk._logs = [];
    return { success: true };
  };

  // Capture console output
  sdk._logs = [];
  var origLog = console.log;
  var origWarn = console.warn;
  var origError = console.error;

  console.log = function () {
    sdk._logs.push("[LOG] " + Array.prototype.slice.call(arguments).join(" "));
    if (sdk._logs.length > 500) sdk._logs.shift();
    origLog.apply(console, arguments);
  };
  console.warn = function () {
    sdk._logs.push(
      "[WARN] " + Array.prototype.slice.call(arguments).join(" ")
    );
    if (sdk._logs.length > 500) sdk._logs.shift();
    origWarn.apply(console, arguments);
  };
  console.error = function () {
    sdk._logs.push(
      "[ERROR] " + Array.prototype.slice.call(arguments).join(" ")
    );
    if (sdk._logs.length > 500) sdk._logs.shift();
    origError.apply(console, arguments);
  };

  // ---------------------------------------------------------------
  // Dispatcher
  // ---------------------------------------------------------------

  /**
   * Called by the proxy via CDP Runtime.evaluate.
   * @param {string} method
   * @param {object} params
   * @returns {string} JSON-encoded result
   */
  window.__FLUTTER_SKILL_CALL__ = function (method, params) {
    params = params || {};
    var fn = methods[method];
    if (!fn) {
      return JSON.stringify({ error: "Unknown method: " + method });
    }
    try {
      var result = fn(params);
      return JSON.stringify(result);
    } catch (e) {
      return JSON.stringify({ error: e.message || String(e) });
    }
  };
})();
