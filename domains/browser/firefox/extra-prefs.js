"use strict";

try {
  let Services = globalThis.Services;
  if (!Services) {
    try {
      Services = ChromeUtils.importESModule(
        "resource://gre/modules/Services.sys.mjs"
      ).Services;
    } catch (e) {
      try {
        Services = ChromeUtils.import(
          "resource://gre/modules/Services.jsm"
        ).Services;
      } catch (e2) {
        Services = globalThis.Services;
      }
    }
  }
  if (!Services) {
    try {
      Services = Components.classes["@mozilla.org/toolkit/service;1"] || globalThis.Services;
    } catch (_) {}
  }

  const BROWSER_URL = "chrome://browser/content/browser.xhtml";
  const REMOVED_IDS = ["key_gotoHistory", "focusURLBar"];

  const observer = {
    observe(win) {
      const remove = () => {
        try {
          const doc = win.document;
          if (!doc) return;
          if (
            doc.location.href !== BROWSER_URL &&
            doc.documentURI !== BROWSER_URL
          )
            return;
          for (const id of REMOVED_IDS) {
            const el = doc.getElementById(id);
            if (el) el.remove();
          }
        } catch (_) {}
      };
      try {
        win.addEventListener("DOMContentLoaded", remove, { once: true });
      } catch (_) {}
      try {
        win.addEventListener("load", remove, { once: true });
      } catch (_) {}
    },
  };

  let obsSvc = Services && Services.obs;
  if (!obsSvc && typeof Components !== "undefined") {
    try {
      obsSvc = Components.classes["@mozilla.org/observer-service;1"].getService(
        Components.interfaces.nsIObserverService
      );
    } catch (_) {}
  }
  if (obsSvc) {
    obsSvc.addObserver(observer, "chrome-document-global-created");
  } else if (Services && Services.obs) {
    Services.obs.addObserver(observer, "chrome-document-global-created");
  }
} catch (_) {}
