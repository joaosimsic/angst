"use strict";

try {
  const { Services } = ChromeUtils.importESModule(
    "resource://gre/modules/Services.sys.mjs"
  );

  const BROWSER_URL = "chrome://browser/content/browser.xhtml";
  const REMOVED_IDS = ["key_gotoHistory", "focusURLBar"];

  function removeBindings(document) {
    for (const id of REMOVED_IDS) {
      document.getElementById(id)?.remove();
    }
  }

  function onBrowserWindow(window) {
    window.addEventListener(
      "DOMContentLoaded",
      () => {
        const { document } = window;

        if (document.location.href !== BROWSER_URL) {
          return;
        }

        removeBindings(document);
      },
      { once: true }
    );
  }

  Services.obs.addObserver(onBrowserWindow, "chrome-document-global-created");
} catch (_) {}
