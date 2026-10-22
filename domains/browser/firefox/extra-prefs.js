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
  const REMOVED_IDS = ["focusURLBar"];

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

  const IDLE_BOOL_PREF = "angst.tabs.idleUnload.enabled";
  const IDLE_MINUTES_PREF = "angst.tabs.idleUnload.minutes";
  const IDLE_ALLOWLIST_PREF = "angst.tabs.idleUnload.allowlist";
  const IDLE_DEFAULT_ALLOWLIST = "web.whatsapp.com";
  const idleLastSeen = new WeakMap();
  const idleWindows = new WeakSet();

  try {
    const defaults = Services.prefs.getDefaultBranch("");
    defaults.setBoolPref("browser.sessionstore.restore_on_demand", true);
    defaults.setBoolPref("browser.tabs.unloadOnLowMemory", true);
    defaults.setBoolPref("browser.tabs.unloadTabInContextMenu", true);
    defaults.setBoolPref(IDLE_BOOL_PREF, true);
    defaults.setIntPref(IDLE_MINUTES_PREF, 60);
    defaults.setStringPref(IDLE_ALLOWLIST_PREF, IDLE_DEFAULT_ALLOWLIST);
  } catch (_) {}

  const prefBool = (name, fallback) => {
    try {
      return Services.prefs.getBoolPref(name, fallback);
    } catch (_) {
      return fallback;
    }
  };

  const prefInt = (name, fallback) => {
    try {
      return Services.prefs.getIntPref(name, fallback);
    } catch (_) {
      return fallback;
    }
  };

  const prefString = (name, fallback) => {
    try {
      return Services.prefs.getStringPref(name, fallback);
    } catch (_) {
      return fallback;
    }
  };

  const idleAllowlist = () =>
    prefString(IDLE_ALLOWLIST_PREF, IDLE_DEFAULT_ALLOWLIST)
      .split(",")
      .map((entry) => entry.trim().toLowerCase().replace(/^\./, ""))
      .filter(Boolean);

  const hostAllowed = (host) => {
    if (!host) return false;
    const normalized = String(host).toLowerCase();
    return idleAllowlist().some(
      (entry) => normalized === entry || normalized.endsWith("." + entry)
    );
  };

  const noteTab = (tab) => {
    try {
      idleLastSeen.set(tab, Date.now());
    } catch (_) {}
  };

  const updateNativeProtection = (tab) => {
    try {
      let protect = Boolean(tab.pinned);
      const browser = tab.linkedBrowser;
      if (!protect && browser && browser.currentURI) {
        protect = hostAllowed(browser.currentURI.host);
      }
      if (!protect && browser && browser.hasBeforeUnload) {
        protect = true;
      }
      tab.undiscardable = protect;
    } catch (_) {}
  };

  const setupIdleWindow = (win) => {
    if (!win || idleWindows.has(win)) return;
    const gBrowser = win.gBrowser;
    if (!gBrowser || !gBrowser.tabContainer) return;
    if (typeof gBrowser.prepareDiscardBrowser !== "function") return;
    if (typeof gBrowser.discardBrowser !== "function") return;

    idleWindows.add(win);

    for (const tab of gBrowser.tabs) {
      noteTab(tab);
      updateNativeProtection(tab);
    }

    const onTab = (event) => {
      if (!event || !event.target) return;
      noteTab(event.target);
      updateNativeProtection(event.target);
    };

    gBrowser.tabContainer.addEventListener("TabSelect", onTab);
    gBrowser.tabContainer.addEventListener("TabOpen", onTab);

    const tick = () => {
      try {
        if (!prefBool(IDLE_BOOL_PREF, true)) return;
        const minutes = prefInt(IDLE_MINUTES_PREF, 60);
        if (!Number.isFinite(minutes) || minutes <= 0) return;
        const cutoff = Date.now() - minutes * 60000;

        for (const tab of gBrowser.tabs) {
          updateNativeProtection(tab);

          if (tab.selected) {
            noteTab(tab);
            continue;
          }
          if (!idleLastSeen.has(tab)) {
            noteTab(tab);
            continue;
          }
          if ((idleLastSeen.get(tab) || 0) > cutoff) continue;
          if (tab.closing || tab.pinned) continue;

          let browser;
          try {
            browser = tab.linkedBrowser;
          } catch (_) {
            continue;
          }
          if (!browser || !browser.isRemoteBrowser || !browser.isConnected) {
            continue;
          }

          let host = "";
          try {
            host = browser.currentURI ? browser.currentURI.host : "";
          } catch (_) {}
          if (hostAllowed(host)) continue;
          if (
            tab.hasAttribute("busy") ||
            tab.hasAttribute("soundplaying") ||
            tab.hasAttribute("activemedia-blocked")
          ) {
            continue;
          }
          if (browser.hasBeforeUnload) continue;

          try {
            gBrowser
              .prepareDiscardBrowser(tab)
              .then(() => {
                try {
                  if (!tab.selected && !tab.closing) {
                    if (gBrowser.discardBrowser(tab, true)) {
                      noteTab(tab);
                    }
                  }
                } catch (_) {}
              })
              .catch(function () {});
          } catch (_) {}
        }
      } catch (_) {}
    };

    const interval = win.setInterval(tick, 60000);
    win.addEventListener(
      "unload",
      () => {
        try {
          win.clearInterval(interval);
        } catch (_) {}
        idleWindows.delete(win);
      },
      { once: true }
    );
  };

  const idleObserver = {
    observe(win, topic) {
      if (topic === "browser-delayed-startup-finished") {
        setupIdleWindow(win);
      }
    },
  };

  if (obsSvc) {
    obsSvc.addObserver(idleObserver, "browser-delayed-startup-finished");
  } else if (Services && Services.obs) {
    Services.obs.addObserver(idleObserver, "browser-delayed-startup-finished");
  }

  try {
    const windows = Services.wm.getEnumerator("navigator:browser");
    while (windows.hasMoreElements()) {
      setupIdleWindow(windows.getNext());
    }
  } catch (_) {}
} catch (_) {}
