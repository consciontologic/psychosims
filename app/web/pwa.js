(() => {
  const status = document.querySelector('#pwa-status');
  const retry = document.querySelector('#pwa-retry');
  const install = document.querySelector('#pwa-install');
  let registration;
  let installPrompt;
  let ready = false;
  let failed = false;
  let checking = false;
  function render() {
    const online = navigator.onLine;
    const update = Boolean(registration?.waiting);
    window.psychosimsPwa = Object.freeze({ ready, online, update, failed });
    window.dispatchEvent(new CustomEvent('psychosims-pwa-status', { detail: window.psychosimsPwa }));
    status.textContent = update ? 'Update downloaded. Save, then close all app tabs and reopen to update.' :
      ready ? (online ? 'Ready offline · AI replies need internet' : 'Offline · Saved games available; AI paused') :
      failed ? 'Offline download incomplete. Reconnect and retry before leaving.' :
      online ? 'Downloading resources for offline play…' : 'Offline · Initial download still needed';
    retry.hidden = !failed;
  }
  async function checkReady() {
    const worker = registration?.active;
    if (!worker || checking) return;
    checking = true;
    const channel = new MessageChannel();
    const timeout = setTimeout(() => { checking = false; }, 5000);
    channel.port1.onmessage = event => {
      clearTimeout(timeout); channel.port1.close(); checking = false;
      ready = event.data.ready === true; failed = !ready; render();
    };
    worker.postMessage({ type: 'PWA_STATUS' }, [channel.port2]);
  }
  function watch(worker) {
    if (!worker) return;
    worker.addEventListener('statechange', () => {
      if (worker.state === 'redundant') failed = true;
      if (worker.state === 'activated') checkReady();
      render();
    });
  }
  async function register() {
    failed = false; render();
    if (!('serviceWorker' in navigator) || !window.isSecureContext) {
      failed = true;
      status.textContent = 'Offline installation requires a browser with service workers and HTTPS.';
      return;
    }
    try {
      registration = await navigator.serviceWorker.getRegistration('/') ??
        await navigator.serviceWorker.register('service_worker.js', { scope: '/', updateViaCache: 'none' });
      watch(registration.installing);
      registration.addEventListener('updatefound', () => { watch(registration.installing); render(); });
      await checkReady();
      // An update network failure never invalidates an already installed cache.
      try { await registration.update(); } catch { if (!registration.active) failed = true; }
      render();
    } catch { failed = true; render(); }
  }
  retry.addEventListener('click', register);
  window.addEventListener('online', () => { render(); checkReady(); });
  window.addEventListener('offline', render);
  navigator.serviceWorker?.addEventListener('controllerchange', checkReady);
  window.addEventListener('beforeinstallprompt', event => {
    event.preventDefault(); installPrompt = event; install.hidden = false;
  });
  install.addEventListener('click', async () => {
    if (!installPrompt) return;
    await installPrompt.prompt(); await installPrompt.userChoice;
    installPrompt = null; install.hidden = true;
  });
  window.addEventListener('appinstalled', () => { installPrompt = null; install.hidden = true; });
  register();
})();
