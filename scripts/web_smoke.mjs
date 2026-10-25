// Production-browser acceptance. Run against the release artifact, never a dev
// Flutter server. All AI traffic is a deterministic route fixture, no real key.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { createServer } from 'node:http';
import { createHash } from 'node:crypto';
import { readFile, stat, mkdir, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
const { chromium } = createRequire(import.meta.url)('playwright');
// Authentic old-build save; the recorded digest guards fixture fidelity.
const legacyPayload = {
  "schema":1,
  "case_id":"poc-vexa-001",
  "checksum":"sha256:517609f41dab0df37b5f8b95a04e4de316f29a4f85bd5b05098ae3d1a7f3fb53",
  "ruleset":"poc-1.0.0",
  "initial_state":{"seed":42,"turn":0,"trust_score":30,"agitation_level":45,"active_defense":"none","trauma":0,"freeze_turns":0,"session_progress":0,"medication":{"drug":null,"dosage":0,"tolerance":0,"dependency":0}},
  "loadout":{"card_ids":["open_question","validate","reframe","set_boundary"],"slot_cap":5},
  "controllers":{"focus":"balanced","emotional_delivery":"balanced"},
  "actions":Array(20).fill('validate'),
  "transcript":[
    "It helps to hear that you are following me. I can leave a little space between my words.",
    "Being heard matters, even while I am finding it hard to settle into this conversation.",
    "Thank you for staying with what I said. I am not ready to add much yet.",
    "Thank you. I can take my time explaining this part.",
    "It helps to hear that you are following me. I can leave a little space between my words.",
    "Yes, that is what I was trying to say. I do not have to rush the next sentence.",
    "I feel heard. Let me stay with the thought instead of jumping straight past it.",
    "Thank you. I can take my time explaining this part.",
    "It helps to hear that you are following me. I can leave a little space between my words.",
    "Being heard matters, even while I am finding it hard to settle into this conversation.",
    "I feel heard. Let me stay with the thought instead of jumping straight past it.",
    "I do want you to understand. I am still choosing which words feel right.",
    "I hear you. My thoughts are still racing, so I need a little room to answer.",
    "Yes, that is what I was trying to say. I do not have to rush the next sentence.",
    "I feel heard. Let me stay with the thought instead of jumping straight past it.",
    "Thank you. I can take my time explaining this part.",
    "It helps to hear that you are following me. I can leave a little space between my words.",
    "Yes, that is what I was trying to say. I do not have to rush the next sentence.",
    "I feel heard. Let me stay with the thought instead of jumping straight past it.",
    "I do want you to understand. I am still choosing which words feel right.",
  ].flatMap(text=>[{player:true,text:'Validate',practice:true},{player:false,text,practice:true}]),
  "partial_attempts":[],
  "completed_sessions":[],
  "balances":{},
  "history":{"carry_over_deltas":[],"inherited_medication":{"drug":null,"dosage":0,"tolerance":0,"dependency":0},"derangements":[],"collected_clues":[],"prior_session_count":0,"postponing_decay":0},
  "practice":true,
  "partial_text":"",
  "partial_status":"",
  "pending_action":null,
};
assert.equal(createHash('sha256').update(JSON.stringify(legacyPayload)).digest('hex'),'e22e5b0a6a8c81a66eef2a59a8f7a0633ecaae0b176006063f08f896f7a89217');

const root = resolve('app/build/web');
const evidence = resolve(process.env.PWA_EVIDENCE_DIR || 'test-results/pwa');
await mkdir(evidence, { recursive: true });
const types = { '.html':'text/html', '.js':'text/javascript', '.json':'application/json', '.wasm':'application/wasm', '.css':'text/css', '.png':'image/png', '.ttf':'font/ttf', '.svg':'image/svg+xml' };
const server = createServer(async (req, res) => {
  const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  const file = resolve(root, `.${pathname === '/' ? '/index.html' : pathname}`);
  if (!file.startsWith(root + sep)) { res.writeHead(403).end(); return; }
  try {
    if (!(await stat(file)).isFile()) { res.writeHead(404).end(); return; }
    res.writeHead(200, { 'Content-Type': types[extname(file)] ?? 'application/octet-stream', 'Cache-Control': 'no-store' });
    res.end(await readFile(file));
  } catch { res.writeHead(404).end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const origin = `http://127.0.0.1:${server.address().port}`;
// A normal temporary profile is required: Chromium intentionally disables PWA
// installation in the incognito contexts created by browser.newContext().
const profile = await mkdtemp(resolve(evidence, 'profile-'));
const context = await chromium.launchPersistentContext(profile, { headless: true, executablePath: process.env.CHROMIUM_PATH || undefined, args: ['--no-sandbox'], viewport: { width: 1440, height: 1000 }, reducedMotion: 'reduce', serviceWorkers: 'allow' });
const browser = context.browser();
const page = await context.newPage();
const errors = [];
const externalRequests = [];
const assetFailures = [];
const browserWarnings = [];
const lifecycle = [];
const readiness = [];
await page.exposeFunction('recordSmokeLifecycle', event => lifecycle.push(event));
await page.addInitScript(() => {
  const documentId = crypto.randomUUID();
  window.smokeDocumentId = documentId;
  const record = event => window.recordSmokeLifecycle({event, documentId, url:location.href,
    online:navigator.onLine, navigation:performance.getEntriesByType('navigation')[0]?.type,
    historyState:history.state});
  record('document');
  for (const method of ['pushState','replaceState']) {
    const original = history[method].bind(history);
    history[method] = (...args) => { const result = original(...args); record(method); return result; };
  }
  for (const event of ['pageshow','pagehide','popstate','hashchange']) addEventListener(event,()=>record(event));
});
page.on('pageerror', error => errors.push(error.message));
page.on('request', request => { if (!request.url().startsWith(origin)) externalRequests.push(request.url()); });
page.on('response', response => { if (response.url().startsWith(origin) && response.status() >= 400) assetFailures.push({url:response.url(),status:response.status()}); });
page.on('console', message => { if (['warning','error'].includes(message.type())) browserWarnings.push({type:message.type(),text:message.text()}); });
const checks = [];
const playthrough = [];
const strategies = [];
const viewportChecks = [];
async function semantics() {
  const placeholder = page.locator('flt-semantics-placeholder');
  if (await placeholder.count()) await placeholder.evaluate(element => element.click());
  await page.getByRole('button', {name:'New game', exact:true}).or(page.getByRole('button',{name:'Resume Session',exact:true})).or(page.getByRole('heading',{name:'AI settings',exact:true})).first().waitFor({timeout:30000});
}
async function shot(name) {
  await page.mouse.move(20,60);
  await renderedFrame();
  await page.screenshot({path:resolve(evidence,`${name}.png`),fullPage:true});
}
async function renderedFrame() {
  await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
}
function turnStatus(turn, legacy = false) {
  return page.getByText(new RegExp(`^Turn ${turn}${legacy ? ' · original rules' : ' / 16'} · Trust \\d+ · Agitation \\d+$`));
}
async function surfacePosition() {
  return page.evaluate(()=>{
    const view = document.querySelector('flutter-view');
    return {windowX:scrollX,windowY:scrollY,viewX:view.scrollLeft,viewY:view.scrollTop};
  });
}
async function activatePaintedControl(control,keyboard = false) {
  const box = await control.boundingBox();
  const viewport = page.viewportSize();
  const navigation = await page.getByRole('tablist').boundingBox();
  assert(box && box.width > 0 && box.height > 0 && box.x >= 0 && box.x + box.width <= viewport.width && box.y >= 56 && box.y + box.height <= navigation.y,'The whole painted control must be inside the usable viewport');
  assert(await control.isEnabled());
  // Locator.click() performs native scrollIntoView on Flutter's invisible
  // semantics DOM. With a fading tooltip this can pan the entire flutter-view,
  // which real pointer clicks and keyboard activation do not do. Click the
  // observed control position without mutating DOM or synthesizing app state.
  if (keyboard) await control.press('Enter');
  else await page.mouse.click(box.x + box.width / 2,box.y + box.height / 2);
}
async function latestReplyVisible(text,turn,completed) {
  const escaped = text.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
  const reply = page.getByRole('group',{name:new RegExp(`^Patient response[\\s\\S]*${escaped}$`)}).last();
  const boundary = completed ? page.getByRole('tablist') : turnStatus(turn);
  await boundary.waitFor();
  const deadline = Date.now() + 5000;
  do {
    const boxes = await Promise.all([reply,boundary].map(locator=>locator.evaluateAll(nodes=>{
      if (!nodes.length) return null;
      const {x,y,width,height} = nodes[0].getBoundingClientRect();
      return {x,y,width,height};
    })));
    const surface = await surfacePosition();
    assert.deepEqual(surface,{windowX:0,windowY:0,viewX:0,viewY:0},'The outer Flutter surface must never be panned or scrolled');
    const width = page.viewportSize().width;
    if (boxes[0] && boxes[1] && boxes[0].x >= 0 && boxes[0].x + boxes[0].width <= width && boxes[0].y >= 56 && boxes[0].y + boxes[0].height <= boxes[1].y) return boxes[0];
    await renderedFrame();
  } while (Date.now() < deadline);
  throw new Error(`Latest patient reply must fit horizontally and remain readable above the pinned controls after turn ${turn}`);
}
async function reveal(locator, direction = 1, bodyOnly = false) {
  // Flutter lazily mounts list children. DOM scrollIntoView may move only its
  // semantics layer, so wheel the actual canvas until the painted control is
  // inside the body above the persistent navigation bar.
  for (let step = 0; step < 12; step++) {
    // Read presence and bounds together. A Flutter rebuild can unmount the
    // lazily rendered control between count() and a separate boundingBox().
    const box = await locator.evaluateAll(nodes => {
      if (!nodes.length) return null;
      const {x,y,width,height} = nodes[0].getBoundingClientRect();
      return {x,y,width,height};
    });
    const navigation = await page.getByRole('tablist').boundingBox();
    const dock = await page.getByText(/^Turn \d+(?: \/ 16| · original rules) · Trust \d+ · Agitation \d+$/).evaluateAll(nodes=>nodes.length ? nodes[0].getBoundingClientRect().y : null);
    const bottom = bodyOnly && dock !== null ? dock - 8 : navigation.y;
    if (box && box.y >= 56 && box.y + box.height <= bottom) return step;
    const viewport = page.viewportSize();
    await page.mouse.move(viewport.width / 2,(56 + (dock ?? navigation.y)) / 2);
    await page.mouse.wheel(0,450 * (box ? (box.y < 56 ? -1 : 1) : direction));
    await renderedFrame();
  }
  throw new Error(`Could not scroll the visible game control into the body: ${locator}`);
}
async function savedGame() {
  return page.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('psychosims.offline.v1')).data));
}
async function restoreFixture(payload) {
  const data = JSON.stringify(payload);
  const encoded = JSON.stringify({data,digest:createHash('sha256').update(data).digest('hex')});
  await page.evaluate(value=>localStorage.setItem('psychosims.offline.v1',value),encoded);
  await page.goto(`${origin}/#/session`,{waitUntil:'load'});
  await page.reload({waitUntil:'load'});
  const placeholder = page.locator('flt-semantics-placeholder');
  if (await placeholder.count()) await placeholder.evaluate(element=>element.click());
  await turnStatus(payload.actions.length,payload.ruleset !== '0.2.0').waitFor({timeout:30000});
  assert.deepEqual(await savedGame(),payload,'A compatible saved session must restore without being rewritten');
}
async function beginPreparedSession(delivery) {
  await page.getByText('Prepare Session',{exact:true}).waitFor();
  if (delivery) {
    const control = page.getByRole('button',{name:/Emotional Delivery/});
    await reveal(control);
    await control.click();
    await page.getByRole('menuitem',{name:delivery,exact:true}).click();
  }
  const practice = page.getByRole('switch');
  await reveal(practice);
  if (await practice.getAttribute('aria-checked') !== 'true') await practice.click();
  const start = page.getByRole('button',{name:'Start Session',exact:true});
  await reveal(start);
  await start.click();
  await turnStatus(0).waitFor();
  assert.equal((await savedGame()).ruleset,'0.2.0');
}
async function nextPreparedSession(delivery) {
  const next = page.getByRole('button',{name:'Next session',exact:true});
  await reveal(next);
  await next.click();
  await beginPreparedSession(delivery);
}
async function runStrategy(name,actions,outcome,{fixture = null,keyboardTurns = []} = {}) {
  const before = await savedGame();
  assert.equal(before.actions.length,0);
  assert.equal(before.ruleset,'0.2.0');
  const turns = [];
  let saved;
  for (const [index,action] of actions.entries()) {
    const turn = index + 1;
    const button = page.getByRole('button',{name:action,exact:true});
    const wheelSteps = await reveal(button);
    assert.equal(wheelSteps,0,`${name} turn ${turn} must keep its action visible without scrolling`);
    const keyboard = keyboardTurns.includes(turn);
    await activatePaintedControl(button,keyboard);
    await page.waitForFunction(expected=>JSON.parse(JSON.parse(localStorage.getItem('psychosims.offline.v1')).data).actions.length === expected,turn);
    await renderedFrame();
    saved = await savedGame();
    const completed = saved.completed_sessions.length > before.completed_sessions.length;
    assert.equal(completed,turn === actions.length,`${name} must finish on its verified turn`);
    const replyBox = await latestReplyVisible(saved.transcript.at(-1).text,turn,completed);
    const visibleState = completed ? await page.getByText(outcome === 'succeed' ? 'Session complete' : 'Session ended',{exact:true}).textContent() : await turnStatus(turn).textContent();
    const surface = await surfacePosition();
    const state = {strategy:name,turn,action,input:keyboard ? 'keyboard Enter' : 'pointer',wheelSteps,replyBox,surface,visibleState,transcriptEntries:saved.transcript.length,completed};
    turns.push(state);
    playthrough.push(state);
    if ([1,5,8,12,14,16].includes(turn) || completed) await shot(`${name}-turn-${turn}`);
  }
  assert(actions.length <= 16,'New sessions finish within their bounded pacing window');
  if (outcome === 'succeed') assert(actions.length >= 12,'Success requires the minimum session pacing');
  assert.equal(saved.completed_sessions.length,before.completed_sessions.length + 1);
  const record = saved.completed_sessions.at(-1);
  assert.equal(record.outcome,outcome);
  assert.equal(record.ruleset,'0.2.0');
  assert.equal(record.turns,actions.length);
  assert.deepEqual(record.transcript,saved.transcript);
  assert.equal(record.transcript.length,record.turns * 2);
  if (outcome !== 'succeed') {
    assert.deepEqual(record.rewards,{},'Unsuccessful sessions must not award success rewards');
    assert.deepEqual(saved.balances,before.balances);
  }
  strategies.push({name,fixture,outcome,turns:record.turns,rewards:record.rewards,steps:turns});
  return saved;
}
async function focusKeyEditor() {
  const editor = await context.newCDPSession(page);
  try {
    await page.getByLabel('OpenRouter API key',{exact:true}).click();
    const deadline = Date.now() + 5000;
    let listening = false;
    while (!listening && Date.now() < deadline) {
      const { result } = await editor.send('Runtime.evaluate', {
        expression:'document.activeElement instanceof HTMLInputElement && document.activeElement.type === "password" ? document.activeElement : null'
      });
      if (result.objectId) {
        const { listeners } = await editor.send('DOMDebugger.getEventListeners',{objectId:result.objectId});
        listening = listeners.some(listener=>listener.type === 'input');
        await editor.send('Runtime.releaseObject',{objectId:result.objectId});
      }
      if (!listening) await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>resolve())));
    }
    assert(listening,'Flutter must attach its input listener before the first keystroke');
  } finally {
    // Keep CDP detached during later offline emulation, as above.
    await editor.detach();
  }
}
async function captureReadiness(step) {
  const state = await page.evaluate(() => ({documentId:window.smokeDocumentId,url:location.href,online:navigator.onLine,
    pwaOnline:window.psychosimsPwa?.online,
    keyPresent:document.body.textContent.includes('Key is present in memory.'),
    keyAbsent:document.body.textContent.includes('No key in memory.'),
    selectedModel:[...document.querySelectorAll('[role="button"]')].find(node=>(node.getAttribute('aria-label')??node.textContent).includes('Patient model'))?.textContent,
    historyState:history.state,
    practice:document.querySelector('[role="switch"]')?.getAttribute('aria-checked'),
    validateDisabled:[...document.querySelectorAll('[role="button"]')].find(node=>node.textContent==='Validate')?.getAttribute('aria-disabled'),
    activeTab:document.querySelector('[role="tab"][aria-selected="true"]')?.getAttribute('aria-label')}));
  readiness.push({step,...state});
}
try {
  // The service worker performs its own complete precache. Network idleness is
  // not its readiness contract; wait for the loaded page, visible UI and the
  // explicit offline-ready/controller checks below instead.
  await page.goto(origin, {waitUntil:'load'});
  await semantics();
  await page.waitForFunction(() => window.psychosimsPwa?.ready === true, undefined, { timeout:60000 });
  await page.waitForFunction(() => navigator.serviceWorker.controller !== null);
  const cache = await page.evaluate(async () => {
    const names = await caches.keys();
    return { names, urls:(await Promise.all(names.map(async name => (await (await caches.open(name)).keys()).map(req=>req.url)))).flat() };
  });
  const manifest = JSON.parse(await readFile(resolve(root,'offline-manifest.json'),'utf8'));
  assert.equal(cache.urls.length, manifest.resource_count);
  assert(cache.urls.every(url => url.startsWith(origin)));
  checks.push(`Complete static cache: ${cache.urls.length} resources`);
  const cdp = await context.newCDPSession(page);
  await cdp.send('Page.enable');
  const install = await cdp.send('Page.getInstallabilityErrors');
  assert.deepEqual(install.installabilityErrors, []);
  const appManifest = await cdp.send('Page.getAppManifest');
  assert.deepEqual(appManifest.errors, []);
  // Do not leave a second DevTools session attached: it can reset Chromium's
  // navigator.onLine emulation during reload while network requests stay blocked.
  await cdp.detach();
  checks.push('Chromium installability and manifest checks pass');
  await shot('home-1440');
  for (const width of [360,768,1440]) {
    await page.setViewportSize({width,height:900});
    await renderedFrame();
    await page.getByRole('button',{name:'New game',exact:true}).waitFor();
    assert(await page.evaluate(()=>document.documentElement.scrollWidth <= innerWidth));
    await shot(`noir-home-${width}`);
    await page.mouse.move(width / 2,450);
    await page.mouse.wheel(0,520);
    await renderedFrame();
    await shot(`noir-home-profile-${width}`);
    await page.mouse.wheel(0,-3000);
    await renderedFrame();
  }
  checks.push('Home and patient profile visually captured at 360,768,1440px without page horizontal overflow');
  for (const [width,height] of [[360,640],[360,800],[768,1024],[1440,900]]) {
    await page.setViewportSize({width,height});
    await renderedFrame();
    const newGame = page.getByRole('button',{name:'New game',exact:true});
    const initialBox = await newGame.boundingBox();
    const wheelSteps = await reveal(newGame);
    assert(await page.evaluate(()=>document.documentElement.scrollWidth <= innerWidth));
    viewportChecks.push({width,height,homeNewGameInitialBox:initialBox,homeNewGameWheelSteps:wheelSteps});
    await shot(`home-${width}x${height}`);
    await page.mouse.wheel(0,-3000);
    await renderedFrame();
  }
  checks.push('New game remains reachable at 360x640,360x800,768x1024,1440x900');
  await page.getByRole('button',{name:'New game',exact:true}).click();
  await page.waitForURL('**/#/loadout', {timeout:5000});
  await page.getByRole('switch').click();
  await page.getByRole('button',{name:'Start Session',exact:true}).click();
  await page.getByRole('button',{name:'Validate',exact:true}).click();
  await turnStatus(1).waitFor();
  const save = await page.evaluate(() => localStorage.getItem('psychosims.offline.v1'));
  assert(save);
  assert(JSON.parse(JSON.parse(save).data).transcript.length === 2);
  checks.push('Player action persisted deterministic state and transcript');
  for (const [width,height] of [[360,900],[480,900],[600,900],[768,900],[1024,900],[1440,900],[360,640],[360,800],[768,1024],[1440,900]]) {
    await page.setViewportSize({width,height});
    await renderedFrame();
    await page.waitForFunction(()=>document.documentElement.scrollWidth <= innerWidth, undefined, {timeout:5000});
    assert(await page.evaluate(()=>document.documentElement.scrollWidth <= innerWidth));
    await shot(height === 900 ? `session-${width}` : `session-${width}x${height}`);
    await reveal(page.getByRole('button',{name:'Validate',exact:true}));
    await shot(height === 900 ? `noir-actions-${width}` : `noir-actions-${width}x${height}`);
    await page.mouse.move(width / 2,height / 2);
    await page.mouse.wheel(0,-3000);
    await renderedFrame();
  }
  await shot('noir-session-1440');
  checks.push('Session responsive at 360,480,600,768,1024,1440px; no page horizontal overflow');
  await context.setOffline(true);
  assert(await page.evaluate(async()=>{
    try { await fetch('/offline-network-probe', {cache:'no-store'}); return false; }
    catch { return true; }
  }), 'An uncached network request must fail while offline');
  await page.reload({waitUntil:'load'});
  const placeholder = page.locator('flt-semantics-placeholder');
  if (await placeholder.count()) await placeholder.evaluate(element=>element.click());
  await turnStatus(1).waitFor({timeout:30000});
  await page.waitForFunction(()=>window.psychosimsPwa?.ready === true && window.psychosimsPwa?.online === false);
  assert.equal(await page.evaluate(()=>localStorage.getItem('psychosims.offline.v1')),save);
  await page.getByRole('button',{name:'Validate',exact:true}).click();
  await turnStatus(2).waitFor();
  await shot('offline-reload');
  checks.push('Offline reload preserves save/transcript and local mechanics advance');
  for (const [route,label] of [['/','Resume Session'],['/loadout','Prepare Session'],['/session','Turn 2'],['/history','Session history'],['/settings','AI settings']]) {
    await page.goto(`${origin}/#${route}`,{waitUntil:'load'});
    await page.reload({waitUntil:'load'});
    const placeholder = page.locator('flt-semantics-placeholder');
    if (await placeholder.count()) await placeholder.evaluate(element=>element.click());
    await page.locator('flt-semantics').first().waitFor({timeout:30000});
    if (route === '/settings') await page.getByRole('button',{name:'Use key for this tab',exact:true}).waitFor();
    else if (route === '/session') await turnStatus(2).waitFor();
    else await page.getByText(label,{exact:true}).first().waitFor();
    const address = new URL(page.url());
    assert.equal(address.pathname,'/');
    // Flutter normalizes the root hash to an empty fragment; both request '/'.
    if (route === '/') assert(['','#/'].includes(address.hash));
    else assert.equal(address.hash,`#${route}`);
  }
  checks.push('All five hash routes reload offline without server rewrites');
  await page.getByRole('main').getByText('No key in memory.',{exact:true}).waitFor();
  await shot('settings-offline');
  assert.deepEqual(externalRequests,[]);
  assert.deepEqual(errors,[]);
  checks.push('No external runtime assets, API calls, or uncaught browser errors during offline practice');
  // Exercise the actual compiled HTTP/SSE transport without sending a real
  // credential or fictional transcript to any external service.
  const credential = 'browser-test-credential';
  let completions = 0;
  let interruptResponse = true;
  let unavailableResponse = false;
  await context.route('https://openrouter.ai/**', async route => {
    const request = route.request();
    const headers = {'access-control-allow-origin':origin,'access-control-allow-headers':'*','access-control-allow-methods':'GET, POST, OPTIONS','cache-control':'no-store'};
    if (request.method() === 'OPTIONS') return route.fulfill({status:204,headers});
    if (new URL(request.url()).pathname === '/api/v1/models') {
      assert.equal(request.headers().authorization,undefined);
      return route.fulfill({status:200,headers:{...headers,'content-type':'application/json'},body:JSON.stringify({data:[{
        id:'test/patient:free', name:'Browser test patient', context_length:32000,
        architecture:{input_modalities:['text'],output_modalities:['text']},
        pricing:{prompt:'0',completion:'0'},supported_parameters:['max_tokens']
      }]})});
    }
    if (new URL(request.url()).pathname === '/api/v1/endpoints/zdr') {
      assert.equal(request.headers().authorization,undefined);
      return route.fulfill({status:200,headers:{...headers,'content-type':'application/json'},body:JSON.stringify({data:[{
        model_id:'test/patient:free',tag:'test-provider',status:0,context_length:32000,
        pricing:{prompt:'0',completion:'0',discount:0},supported_parameters:['max_tokens']
      }]})});
    }
    assert.equal(new URL(request.url()).pathname,'/api/v1/chat/completions');
    assert.equal(request.headers().authorization,`Bearer ${credential}`);
    const payload = request.postDataJSON();
    assert.equal(payload.model,'test/patient:free');
    assert.equal(payload.stream,true);
    assert.equal(payload.provider.data_collection,'deny');
    assert.equal(payload.provider.zdr,true);
    assert.equal(payload.provider.allow_fallbacks,false);
    assert.deepEqual(payload.provider.only,['test-provider']);
    completions++;
    if (unavailableResponse) {
      return route.fulfill({status:404,headers:{...headers,'content-type':'application/json'},body:JSON.stringify({error:{message:'untrusted-upstream-debug-details'}})});
    }
    const event = text => `data: ${JSON.stringify({model:'test/patient:free',choices:[{delta:{content:text}}]})}\n\n`;
    if (interruptResponse) {
      return route.fulfill({status:200,headers:{...headers,'content-type':'text/event-stream'},body:event('I can start to explain.')});
    }
    return route.fulfill({status:200,headers:{...headers,'content-type':'text/event-stream'},body:event('I feel ')+event('heard. [ferve-axine] [restless-activation]')+'data: [DONE]\n\n'});
  });
  await context.setOffline(false);
  await page.waitForFunction(()=>window.psychosimsPwa?.online === true);
  // DOM focus requests Flutter focus; a later semantics update attaches the
  // input listener. fill() or typing before that update loses input. Observe
  // listener activation (without mutating the app), then use actual keyboard
  // events and verify acceptance. No fixed delay or credential retry is used.
  await focusKeyEditor();
  await captureReadiness('editor activated');
  await page.keyboard.type(credential);
  await page.waitForFunction(value=>document.activeElement.value === value,credential);
  await page.getByRole('button',{name:'Use key for this tab',exact:true}).click();
  await page.getByRole('main').getByText('Key is present in memory.',{exact:true}).waitFor();
  assert.equal(await page.getByLabel('OpenRouter API key',{exact:true}).inputValue(),'');
  await captureReadiness('after key use');
  await page.getByRole('button',{name:'Refresh model catalog',exact:true}).click();
  await page.getByRole('button',{name:/Patient model/}).click();
  await page.getByRole('menuitem',{name:'Browser test patient',exact:true}).click();
  await page.getByRole('button',{name:/Patient model\s+Browser test patient/}).waitFor();
  await captureReadiness('after model selection');
  await page.getByRole('switch').click();
  await page.getByRole('switch',{checked:false}).waitFor();
  await captureReadiness('AI configured');
  const aiDocumentId = await page.evaluate(()=>window.smokeDocumentId);
  await page.getByRole('tab',{name:'Session',exact:true}).press('Enter');
  await page.waitForURL('**/#/session');
  await page.getByRole('tab',{name:'Session',exact:true,selected:true}).waitFor();
  await reveal(page.getByRole('button',{name:'Validate',exact:true}));
  assert(await page.getByRole('button',{name:'Validate',exact:true}).isEnabled());
  await captureReadiness('before back');
  await page.goBack();
  await page.waitForURL('**/#/settings');
  // URL changes precede Flutter's frame/semantics update. Wait for the rendered
  // destination before traversing again, and distinguish reloads from routing.
  await page.getByRole('heading',{name:'AI settings',exact:true}).waitFor();
  await page.getByRole('tab',{name:'Settings',exact:true,selected:true}).waitFor();
  await page.getByRole('main').getByText('Key is present in memory.',{exact:true}).waitFor();
  await page.getByRole('button',{name:/Patient model\s+Browser test patient/}).waitFor();
  assert.equal(await page.evaluate(()=>window.smokeDocumentId),aiDocumentId);
  await captureReadiness('after back');
  await page.goForward();
  await page.waitForURL('**/#/session');
  await page.getByRole('tab',{name:'Session',exact:true,selected:true}).waitFor();
  assert.equal(await page.evaluate(()=>window.smokeDocumentId),aiDocumentId);
  await reveal(page.getByRole('button',{name:'Validate',exact:true}));
  assert(await page.getByRole('button',{name:'Validate',exact:true}).isEnabled());
  await captureReadiness('after forward');
  await page.getByRole('button',{name:'Validate',exact:true}).click();
  await reveal(page.getByRole('button',{name:'Retry Validate',exact:true}));
  await page.getByRole('button',{name:'Retry Validate',exact:true}).waitFor();
  const interrupted = await page.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('psychosims.offline.v1')).data));
  assert.equal(interrupted.actions.length,2);
  assert.equal(interrupted.transcript.length,4);
  assert.equal(interrupted.partial_text,'I can start to explain.');
  assert.equal(interrupted.pending_action,'validate');
  assert.equal(completions,1);
  await shot('interrupted-ai-response');
  await context.setOffline(true);
  await page.waitForFunction(()=>window.psychosimsPwa?.online === false);
  // The shell handles the browser event before Flutter paints its next frame.
  await page.getByRole('button',{name:'Retry Validate',exact:true,disabled:true}).waitFor();
  assert(await page.getByRole('button',{name:'Retry Validate',exact:true}).isDisabled());
  await context.setOffline(false);
  await page.waitForFunction(()=>window.psychosimsPwa?.online === true);
  assert.equal(completions,1,'Reconnection must not retry an incomplete response');
  interruptResponse = false;
  await page.getByRole('button',{name:'Retry Validate',exact:true}).click();
  // Retrying at the bottom leaves the turn heading outside Flutter's lazy
  // list. Observe the committed turn, then its rendered patient dialogue.
  await page.waitForFunction(()=>JSON.parse(JSON.parse(localStorage.getItem('psychosims.offline.v1')).data).actions.length === 3);
  await renderedFrame();
  assert.match(await page.getByRole('main').ariaSnapshot(),/I feel heard\./);
  const aiSave = await page.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('psychosims.offline.v1')).data));
  assert.equal(aiSave.transcript.at(-1).text,'I feel heard.');
  assert.equal(completions,2);
  assert.equal(aiSave.partial_attempts.length,1);
  assert.equal(aiSave.partial_attempts[0].text,'I can start to explain.');
  assert.equal(aiSave.partial_text,'');
  assert.equal(aiSave.pending_action,null);
  checks.push('Truncated SSE preserves partial text without applying a turn; offline retry disables; reconnect does not replay; explicit retry applies exactly once and retains the incomplete attempt');
  await shot('mocked-ai-response');
  unavailableResponse = true;
  await page.getByRole('button',{name:'Validate',exact:true}).click();
  await page.getByRole('button',{name:'Retry Validate',exact:true}).waitFor();
  await reveal(page.getByText(/HTTP 404/));
  const unavailableSave = await savedGame();
  assert.deepEqual(unavailableSave.actions,aiSave.actions);
  assert.deepEqual(unavailableSave.transcript,aiSave.transcript);
  assert.deepEqual(unavailableSave.balances,aiSave.balances);
  assert.equal(unavailableSave.pending_action,'validate');
  assert.equal(unavailableSave.partial_text,'');
  assert.equal(completions,3);
  assert(!(await page.getByRole('main').ariaSnapshot()).includes('untrusted-upstream-debug-details'));
  await shot('mocked-private-route-404');
  await context.setOffline(true);
  await page.waitForFunction(()=>window.psychosimsPwa?.online === false);
  await page.getByRole('button',{name:'Retry Validate',exact:true,disabled:true}).waitFor();
  await context.setOffline(false);
  await page.waitForFunction(()=>window.psychosimsPwa?.online === true);
  await page.getByRole('button',{name:'Retry Validate',exact:true,disabled:false}).waitFor();
  assert.equal(completions,3,'404 and reconnection must not automatically retry or change providers');
  unavailableResponse = false;
  await page.getByRole('button',{name:'Retry Validate',exact:true}).click();
  await page.waitForFunction(()=>JSON.parse(JSON.parse(localStorage.getItem('psychosims.offline.v1')).data).actions.length === 4);
  const recoveredSave = await savedGame();
  assert.equal(completions,4);
  assert.equal(recoveredSave.transcript.length,8);
  assert.equal(recoveredSave.pending_action,null);
  assert.equal(recoveredSave.partial_attempts.length,1);
  assert.equal(recoveredSave.transcript.at(-1).text,'I feel heard.');
  checks.push('HTTP404 preserves turn/transcript/rewards and offers safe guidance; reconnect does not replay; explicit retry retains the exact provider allowlist and all privacy flags');
  await context.setOffline(true);
  await page.reload({waitUntil:'load'});
  const restoredPlaceholder = page.locator('flt-semantics-placeholder');
  if (await restoredPlaceholder.count()) await restoredPlaceholder.evaluate(element=>element.click());
  await turnStatus(4).waitFor();
  await reveal(page.getByRole('button',{name:'Validate',exact:true}));
  assert(await page.getByRole('button',{name:'Validate',exact:true}).isDisabled());
  await page.getByRole('tab',{name:'Settings',exact:true}).click();
  await page.getByRole('main').getByText('No key in memory.',{exact:true}).waitFor();
  const localData = await page.evaluate(async()=>({
    local:JSON.stringify(localStorage),session:JSON.stringify(sessionStorage),
    urls:(await Promise.all((await caches.keys()).map(async name=>(await (await caches.open(name)).keys()).map(req=>req.url)))).flat()
  }));
  assert(!localData.local.includes(credential));
  assert(!localData.session.includes(credential));
  assert(localData.urls.every(url=>url.startsWith(origin)));
  assert.equal(localData.urls.length,manifest.resource_count);
  await context.setOffline(false);
  await page.waitForFunction(()=>window.psychosimsPwa?.online === true);
  assert.equal(completions,4);
  assert.deepEqual(errors,[]);
  checks.push('Mocked catalog and SSE apply one validated AI turn; offline reload keeps dialogue but forgets key; reconnect sends no replay');
  checks.push('No credential in local/session storage and no API URL in the static cache');
  checks.push('Keyboard navigation and browser back/forward preserve the session');
  // New game must be an explicit, safe entry point from an active session.
  // Cancellation preserves the exact saved bytes; confirmation replaces only
  // current progress and must survive an offline reload without replaying AI.
  await page.getByRole('tab',{name:'Home',exact:true}).click();
  // Leave the navigation target so Material's hover tooltip cannot temporarily
  // concatenate a second "Home" into its accessible name during selection.
  await page.mouse.move(20,60);
  await page.getByRole('tab',{name:'Home',exact:true,selected:true}).waitFor();
  const beforeNewGame = await page.evaluate(()=>localStorage.getItem('psychosims.offline.v1'));
  const beforePayload = JSON.parse(JSON.parse(beforeNewGame).data);
  await page.getByRole('button',{name:'New game',exact:true}).click();
  await page.getByText('Start a new game?',{exact:true}).waitFor();
  await page.getByRole('button',{name:'Keep playing',exact:true}).click();
  await page.getByText('Start a new game?',{exact:true}).waitFor({state:'hidden'});
  assert.equal(await page.evaluate(()=>localStorage.getItem('psychosims.offline.v1')),beforeNewGame);
  await page.getByRole('button',{name:'Resume Session',exact:true}).click();
  await turnStatus(4).waitFor();
  await reveal(page.getByRole('button',{name:'New game',exact:true}),-1);
  await page.getByRole('button',{name:'New game',exact:true}).click();
  await page.getByText('Start a new game?',{exact:true}).waitFor();
  await page.getByRole('button',{name:'Start new game',exact:true}).click();
  await page.waitForURL('**/#/loadout');
  await page.getByText('Prepare Session',{exact:true}).waitFor();
  const resetSave = await page.evaluate(()=>localStorage.getItem('psychosims.offline.v1'));
  const resetPayload = JSON.parse(JSON.parse(resetSave).data);
  assert.deepEqual(resetPayload.actions,[]);
  assert.deepEqual(resetPayload.transcript,[]);
  for (const field of ['completed_sessions','balances','history','loadout','controllers','practice']) {
    assert.deepEqual(resetPayload[field],beforePayload[field],field);
  }
  await page.getByRole('button',{name:'Start Session',exact:true}).click();
  await turnStatus(0).waitFor();
  await context.setOffline(true);
  await page.reload({waitUntil:'load'});
  const newGamePlaceholder = page.locator('flt-semantics-placeholder');
  if (await newGamePlaceholder.count()) await newGamePlaceholder.evaluate(element=>element.click());
  await turnStatus(0).waitFor({timeout:30000});
  assert.equal(await page.evaluate(()=>localStorage.getItem('psychosims.offline.v1')),resetSave);
  assert.equal(completions,4);
  assert.deepEqual(errors,[]);
  await shot('new-game-offline');
  checks.push('New game is reachable from Home and Session; cancel preserves save; confirm resets current turn and transcript while retaining career/setup; fresh game reloads offline');
  // Complete a real session through painted controls on a short phone screen.
  // This primary playthrough reads storage only as evidence.
  await page.setViewportSize({width:360,height:640});
  await renderedFrame();
  await reveal(page.getByRole('switch'),1,true);
  await page.getByRole('switch').click();
  await page.getByRole('switch',{checked:true}).waitFor();
  const completedSave = await runStrategy('mixed-success',[
    ...Array(6).fill('Validate'),...Array(5).fill('Open question'),'Set boundary'
  ],'succeed');
  const record = completedSave.completed_sessions[0];
  assert.deepEqual(record.rewards,{xp:100,study:3,cash:50});
  assert.deepEqual(completedSave.balances,record.rewards);
  checks.push('A varied 12-turn mobile session succeeds with actual rapport and calm; every action needs zero scrolling and every latest reply/state remains visible');
  await reveal(page.getByRole('button',{name:'Next session',exact:true}));
  await shot('mobile-completed-session');
  await page.getByRole('tab',{name:'History',exact:true}).press('Enter');
  await page.getByText('Session history',{exact:true}).waitFor();
  const historyEntry = page.getByRole('button',{name:new RegExp(`Session 1.*${record.outcome}`)});
  await reveal(historyEntry);
  await historyEntry.click();
  const archivedReply = record.transcript[1].text.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
  await page.getByRole('group',{name:new RegExp(`^Patient response[\\s\\S]*${archivedReply}`)}).first().waitFor();
  await shot('mobile-completed-history');
  await page.reload({waitUntil:'load'});
  const historyPlaceholder = page.locator('flt-semantics-placeholder');
  if (await historyPlaceholder.count()) await historyPlaceholder.evaluate(element=>element.click());
  await page.getByText('Session history',{exact:true}).waitFor({timeout:30000});
  const restoredCareer = await page.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('psychosims.offline.v1')).data));
  assert.deepEqual(restoredCareer,completedSave);
  await page.getByRole('tab',{name:'Home',exact:true}).press('Enter');
  await reveal(page.getByRole('button',{name:'New game',exact:true}));
  await page.getByRole('button',{name:'New game',exact:true}).click();
  await page.getByText('Prepare Session',{exact:true}).waitFor();
  const afterCareerReset = await page.evaluate(()=>JSON.parse(JSON.parse(localStorage.getItem('psychosims.offline.v1')).data));
  assert.deepEqual(afterCareerReset.actions,[]);
  assert.deepEqual(afterCareerReset.transcript,[]);
  for (const field of ['completed_sessions','balances','history','loadout','controllers','practice']) assert.deepEqual(afterCareerReset[field],completedSave[field],field);
  assert.equal(completions,4,'The full offline session must make no AI requests');
  assert.deepEqual(errors,[]);
  checks.push(`Completed ${record.turns}-turn offline mobile session; keyboard History navigation exposes archived dialogue; offline reload and New game retain completed history/career`);
  // Repetition is bounded and cannot farm successful-session rewards. These
  // are actual player actions, with the same career retained between sessions.
  for (const [index,action] of ['Validate','Open question','Reframe','Set boundary'].entries()) {
    if (index === 0) await beginPreparedSession();
    else await nextPreparedSession();
    await runStrategy(`repeat-${action.toLowerCase().replaceAll(' ','-')}`,Array(action === 'Reframe' ? 8 : 16).fill(action),'fail');
  }
  checks.push('Each single-action strategy ends without success rewards by turn16; repeated reframing triggers an earlier turn8 walkout');
  await nextPreparedSession('Objective');
  const unsuccessfulSave = await runStrategy('low-trust-objective',['Open question',...Array(15).fill('Validate')],'fail');
  const lowTrust = strategies.at(-1).steps.at(-2).visibleState.match(/Trust (\d+)/);
  assert(lowTrust && Number(lowTrust[1]) < 50,'Objective delivery must retain the low-trust regression precondition');
  await page.reload({waitUntil:'load'});
  const unsuccessfulPlaceholder = page.locator('flt-semantics-placeholder');
  if (await unsuccessfulPlaceholder.count()) await unsuccessfulPlaceholder.evaluate(element=>element.click());
  // Reload starts at the top; the terminal footer is a lazy list child below
  // the archived dialogue. Wait for the rendered title before reading state.
  await page.getByText('Turn 16 / 16',{exact:true}).waitFor();
  assert.deepEqual(await savedGame(),unsuccessfulSave,'Offline reload must preserve unsuccessful history without replay or rewards');
  const unsuccessfulAxes = await page.getByText(/^Trust \d+\s+Agitation \d+\s+Progress \d+$/).textContent();
  assert.match(unsuccessfulAxes,/^Trust 27\s+Agitation 45\s+Progress 100$/,'A full progress bar with actual low trust must remain unsuccessful');
  checks.push('Objective delivery with low rapport cannot convert repeated progress into success or career rewards');
  await nextPreparedSession('Balanced');
  // This explicitly seeded regression exercises a crisis that the default seed
  // does not reach. Only the setup seed is injected; every recovery action uses
  // the same visible controls as ordinary play.
  const crisisFixture = await savedGame();
  crisisFixture.initial_state.seed = 0;
  await restoreFixture(crisisFixture);
  await runStrategy('crisis-recovery',[
    ...Array(5).fill('Reframe'),...Array(3).fill('Set boundary'),...Array(6).fill('Validate')
  ],'succeed',{fixture:'Fresh 0.2.0 save with initial seed0, checksummed before reload',keyboardTurns:[9]});
  const crisisSteps = strategies.at(-1).steps;
  assert.match(crisisSteps[4].visibleState,/Agitation 81$/);
  assert.match(crisisSteps[7].visibleState,/Trust 29 · Agitation 47$/);
  checks.push('Seed0 crisis reaches agitation81; three boundaries lower it to47; validation then succeeds at turn14 through the ordinary controls');
  // Legacy replay below uses an authentic save captured from production build
  // abf021ab65222904ec98b29c, not a fabricated 20-turn current-rules session.
  await restoreFixture(legacyPayload);
  assert.equal(await turnStatus(20,true).textContent(),'Turn 20 · original rules · Trust 41 · Agitation 45');
  assert.equal((await savedGame()).completed_sessions.length,0,'A legacy session beyond turn16 must not be retroactively completed');
  await page.getByRole('button',{name:'Validate',exact:true}).click();
  await turnStatus(21,true).waitFor();
  assert.equal(await turnStatus(21,true).textContent(),'Turn 21 · original rules · Trust 42 · Agitation 45');
  const legacyContinued = await savedGame();
  assert.equal(legacyContinued.ruleset,'poc-1.0.0');
  assert.deepEqual(legacyContinued.transcript.slice(0,40),legacyPayload.transcript);
  assert.equal(legacyContinued.completed_sessions.length,0);
  await shot('legacy-turn21-original-rules');
  await page.getByRole('tab',{name:'Home',exact:true}).press('Enter');
  await reveal(page.getByRole('button',{name:'New game',exact:true}));
  await page.getByRole('button',{name:'New game',exact:true}).click();
  await page.getByRole('button',{name:'Start new game',exact:true}).click();
  await beginPreparedSession();
  const upgraded = await savedGame();
  assert.equal(upgraded.ruleset,'0.2.0');
  assert.deepEqual(upgraded.actions,[]);
  assert.deepEqual(upgraded.transcript,[]);
  await page.reload({waitUntil:'load'});
  const upgradedPlaceholder = page.locator('flt-semantics-placeholder');
  if (await upgradedPlaceholder.count()) await upgradedPlaceholder.evaluate(element=>element.click());
  await turnStatus(0).waitFor();
  assert.deepEqual(await savedGame(),upgraded);
  await shot('legacy-new-game-current-rules-offline');
  assert.equal(completions,4,'All strategy and legacy checks remain offline without AI requests');
  checks.push('Authentic legacy turn20 save resumes with identical transcript and original mechanics through turn21; explicit New game opts into0.2.0 and reloads offline');
  await writeFile(resolve(evidence,'playthrough.json'),JSON.stringify({viewportChecks,playthrough,strategies,outcome:record.outcome,rewards:record.rewards,legacy:{sourceBuild:'abf021ab65222904ec98b29c',restoredTurn:20,continuedTurn:21,upgradedRuleset:upgraded.ruleset}},null,2)+'\n');
  assert.deepEqual(errors,[]);
  assert(externalRequests.every(value=>{
    const url = new URL(value);
    return url.origin === 'https://openrouter.ai' && ['/api/v1/models','/api/v1/endpoints/zdr','/api/v1/chat/completions'].includes(url.pathname);
  }),'Only the intercepted catalog, private-endpoint metadata, and completion URLs may leave the local runtime');
  assert.deepEqual([...new Set(assetFailures.map(failure=>`${failure.status} ${failure.url}`))],[],'Every requested runtime asset, including fallback fonts, must exist');
  await writeFile(resolve(evidence,'results.json'),JSON.stringify({status:'PASS',testedAt:new Date().toISOString(),browser:browser.version(),origin,checks,errors,assetFailures,browserWarnings,externalRequestAttempts:externalRequests,aiTransport:'Intercepted deterministic fixtures; no external service contacted',resourceCount:manifest.resource_count,buildId:manifest.build_id},null,2)+'\n');
  console.log(JSON.stringify({status:'PASS',checks,evidence},null,2));
} catch(error) {
  await shot('failure');
  await writeFile(resolve(evidence,'failure.txt'),`${error.stack}\nBrowser errors: ${JSON.stringify(errors)}\nAsset failures: ${JSON.stringify(assetFailures)}\nBrowser warnings: ${JSON.stringify(browserWarnings)}\nExternal requests: ${JSON.stringify(externalRequests)}\n`);
  await writeFile(resolve(evidence,'failure-dom.txt'),`${page.url()}\n${await page.locator('body').ariaSnapshot()}\n${await page.content()}`);
  await writeFile(resolve(evidence,'failure-layout.json'),JSON.stringify(await page.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,overflow:[...document.querySelectorAll('*')].map(e=>({tag:e.tagName,id:e.id,right:e.getBoundingClientRect().right,width:e.getBoundingClientRect().width})).filter(e=>e.right>innerWidth+1)})),null,2));
  throw error;
} finally {
  await writeFile(resolve(evidence,'lifecycle.json'),JSON.stringify({lifecycle,readiness},null,2)+'\n');
  await writeFile(resolve(evidence,'diagnostics.json'),JSON.stringify({checks,viewportChecks,playthrough,strategies,errors,assetFailures,browserWarnings},null,2)+'\n');
  await context.close(); await rm(profile, { recursive:true, force:true }); await new Promise(resolve=>server.close(resolve));
}
