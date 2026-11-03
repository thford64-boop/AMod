import Foundation

/// The AMod standard library, evaluated before every script.
/// It wraps the raw `__native` bridge in a friendly API plus a SwiftUI-style view DSL.
enum Prelude {
    static let source = #"""
(function (g) {
  'use strict';
  const N = g.__native;

  // ---------- printing ----------
  const str = (x) => {
    if (typeof x === 'string') return x;
    if (x === undefined) return 'undefined';
    if (x instanceof Error) return x.name + ': ' + x.message;
    if (typeof x === 'function') return '[function]';
    try { const s = JSON.stringify(x, null, 2); return s === undefined ? String(x) : s; }
    catch (e) { return String(x); }
  };
  const fmt = (a) => a.map(str).join(' ');
  g.__amod_errfmt = (e) => {
    if (!e) return 'Unknown error';
    let m = (e.name ? e.name + ': ' : '') + (e.message !== undefined ? e.message : String(e));
    if (e.line) m = 'Line ' + e.line + ': ' + m;
    return m;
  };
  g.print = (...a) => N.log('out', fmt(a));
  g.console = {
    log: g.print,
    info: (...a) => N.log('info', fmt(a)),
    warn: (...a) => N.log('warn', fmt(a)),
    error: (...a) => N.log('error', fmt(a)),
    clear: () => N.log('clear', ''),
  };
  g.output = (v) => N.output(str(v));
  g.exit = () => { N.exit(); throw new Error('__amod_exit__'); };

  // ---------- timers ----------
  const timers = {};
  let timerId = 0;
  g.__amod_fire = (id) => { const f = timers[id]; if (f) f(); };
  g.setTimeout = (fn, ms, ...rest) => {
    const id = ++timerId;
    timers[id] = () => { delete timers[id]; fn(...rest); };
    N.after(ms || 0, id);
    return id;
  };
  g.setInterval = (fn, ms, ...rest) => {
    const id = ++timerId;
    timers[id] = () => { N.after(ms || 0, id); fn(...rest); };
    N.after(ms || 0, id);
    return id;
  };
  g.clearTimeout = g.clearInterval = (id) => { delete timers[id]; };
  g.sleep = (seconds) => N.sleep(seconds || 0);
  g.wait = (seconds) => new Promise((r) => g.setTimeout(r, (seconds || 0) * 1000));

  // ---------- device ----------
  g.haptic = (style) => N.haptic(style || 'medium');
  g.vibrate = () => N.vibrate();
  g.flashlight = {
    on: (level) => N.torch(true, level == null ? 1 : level),
    off: () => N.torch(false, 0),
    toggle: () => N.torch(!N.torchState(), 1),
    get isOn() { return N.torchState(); },
  };
  g.device = {
    info: () => N.deviceInfo(),
    get battery() { return N.deviceInfo().battery; },
    get brightness() { return N.getBrightness(); },
    set brightness(v) { N.setBrightness(v); },
    get volume() { return N.getVolume(); },
    set volume(v) { N.setVolume(v); },
    playSound: (id) => N.playSound(id == null ? 1007 : id),
  };

  // ---------- settings / shortcuts ----------
  g.settings = {
    open: (section) => N.openSettings(section || ''),
    brightness: (v) => (v == null ? N.getBrightness() : N.setBrightness(v)),
    volume: (v) => (v == null ? N.getVolume() : N.setVolume(v)),
    flashlight: (on) => (on ? g.flashlight.on() : g.flashlight.off()),
    sections: ['wifi', 'bluetooth', 'cellular', 'hotspot', 'vpn', 'notifications', 'sounds', 'focus',
      'screentime', 'general', 'about', 'storage', 'keyboard', 'display', 'wallpaper', 'accessibility',
      'battery', 'privacy', 'location', 'siri', 'faceid', 'safari', 'app'],
  };
  g.shortcuts = {
    run: (name, input) => N.runShortcut(String(name), input == null ? '' : str(input)),
    open: () => N.openURL('shortcuts://'),
  };
  g.openURL = (url) => N.openURL(String(url));

  // ---------- text, speech, clipboard, notifications ----------
  g.clipboard = { get: () => N.clipboardGet(), set: (t) => N.clipboardSet(str(t)) };
  g.speak = (text, opts) => N.speak(str(text), opts || {});
  g.notify = (title, body, opts) =>
    N.notify(str(title), body == null ? '' : str(body), (opts && opts.delay) || 0);
  g.share = (x) => N.share(str(x));

  // ---------- prompts ----------
  g.alert = (title, message, buttons) => {
    const i = N.alert(title == null ? '' : str(title), message == null ? '' : str(message), buttons || ['OK']);
    return i == null ? -1 : i;
  };
  g.confirm = (title, message) => g.alert(title, message, ['Cancel', 'OK']) === 1;
  g.input = (prompt, defaultValue, opts) =>
    N.input(prompt == null ? '' : str(prompt), defaultValue == null ? '' : String(defaultValue), !!(opts && opts.secure));
  g.ask = g.input;
  g.menu = (title, options) => {
    const list = (options || []).map(str);
    const i = N.menu(title == null ? '' : str(title), list);
    return i == null ? null : list[i];
  };

  // ---------- network ----------
  g.http = {
    request: (method, url, opts) => {
      opts = opts || {};
      const headers = Object.assign({}, opts.headers || {});
      let body = opts.body;
      if (body != null && typeof body !== 'string') {
        body = JSON.stringify(body);
        if (!headers['Content-Type']) headers['Content-Type'] = 'application/json';
      }
      const r = N.http(method, String(url), headers, body == null ? null : body, opts.timeout || 30, !!opts.base64);
      if (r.error) throw new Error(r.error);
      r.json = () => JSON.parse(r.body);
      return r;
    },
    get: (url, opts) => g.http.request('GET', url, opts),
    post: (url, body, opts) => g.http.request('POST', url, Object.assign({}, opts, { body })),
    put: (url, body, opts) => g.http.request('PUT', url, Object.assign({}, opts, { body })),
    delete: (url, opts) => g.http.request('DELETE', url, opts),
  };
  g.fetchJSON = (url) => g.http.get(url).json();

  g.location = () => N.location();

  // ---------- base64 ----------
  g.base64 = {
    encode: (s) => N.b64encode(String(s)),
    decode: (s) => N.b64decode(String(s)),
    fromURL: (url) => g.http.get(url, { base64: true }).base64,
  };
  g.btoa = g.base64.encode;
  g.atob = g.base64.decode;

  // ---------- images in the console ----------
  g.showImage = (src) => {
    let s = String(src);
    if (/^https?:\/\//.test(s)) s = g.base64.fromURL(s);
    else if (!s.startsWith('data:') && s.length < 256 && N.fileExists(s)) s = N.fileReadBase64(s);
    N.log('image', s);
  };
  g.console.image = g.showImage;

  // ---------- audio ----------
  const noteFreq = (n) => {
    if (typeof n === 'number') return n;
    const m = /^([A-Ga-g])([#b]?)(-?\d)$/.exec(String(n));
    if (!m) return 440;
    const semis = { c: -9, d: -7, e: -5, f: -4, g: -2, a: 0, b: 2 }[m[1].toLowerCase()]
      + (m[2] === '#' ? 1 : m[2] === 'b' ? -1 : 0) + (parseInt(m[3], 10) - 4) * 12;
    return 440 * Math.pow(2, semis / 12);
  };
  g.audio = {
    play: (src, opts) => N.audioPlay(String(src), opts || {}),
    playBase64: (b64, opts) => N.audioPlay(String(b64), Object.assign({}, opts, { base64: true })),
    stop: () => N.audioStop(),
    tone: (freq, seconds, opts) => N.audioTone(noteFreq(freq || 440), seconds == null ? 0.3 : seconds, opts || {}),
    note: (name, seconds, opts) => g.audio.tone(noteFreq(name), seconds == null ? 0.3 : seconds, opts),
    melody: (notes, opts) => (notes || []).forEach((n) => {
      const pair = Array.isArray(n) ? n : [n, 0.25];
      if (pair[0] == null || pair[0] === '-') N.sleep(pair[1]);
      else g.audio.note(pair[0], pair[1], opts);
    }),
    toneBase64: (freq, seconds, wave) => N.audioToneBase64(noteFreq(freq || 440), seconds == null ? 0.3 : seconds, wave || 'sine'),
    frequency: noteFreq,
  };
  g.playSound = (src, opts) => (typeof src === 'number' ? N.playSound(src) : g.audio.play(src, opts));

  // ---------- files & storage ----------
  g.files = {
    read: (p) => N.fileRead(String(p)),
    write: (p, text) => N.fileWrite(String(p), str(text), false),
    append: (p, text) => N.fileWrite(String(p), str(text), true),
    list: (dir) => N.fileList(dir || ''),
    exists: (p) => N.fileExists(String(p)),
    delete: (p) => N.fileDelete(String(p)),
    readBase64: (p) => N.fileReadBase64(String(p)),
    writeBase64: (p, b64) => N.fileWriteBase64(String(p), String(b64)),
  };
  g.storage = {
    get: (key, fallback) => {
      const v = N.kvGet(String(key));
      return v == null ? (fallback === undefined ? null : fallback) : JSON.parse(v);
    },
    set: (key, value) => N.kvSet(String(key), JSON.stringify(value)),
    remove: (key) => N.kvSet(String(key), null),
  };

  // ---------- calendar & reminders ----------
  const iso = (d) => (d instanceof Date ? d : new Date(d)).toISOString();
  g.calendar = {
    addEvent: (title, start, end, notes) => {
      const s = new Date(start);
      const e = end ? new Date(end) : new Date(s.getTime() + 3600000);
      return N.addEvent(str(title), iso(s), iso(e), notes || '');
    },
  };
  g.reminders = {
    add: (title, opts) => N.addReminder(str(title), (opts && opts.notes) || '', opts && opts.due ? iso(opts.due) : ''),
  };

  // ---------- other scripts ----------
  g.scripts = {
    list: () => N.scriptList(),
    run: (name, input) => N.openURL('amod://run?name=' + encodeURIComponent(name) +
      (input == null ? '' : '&input=' + encodeURIComponent(str(input)))),
  };
  g.require = (name) => {
    const code = N.scriptCode(String(name));
    if (code == null) throw new Error('No script named "' + name + '"');
    const module = { exports: {} };
    new Function('module', 'exports', code)(module, module.exports);
    return module.exports;
  };

  // ---------- SwiftUI-style views ----------
  class View {
    constructor(type, props, children) {
      this.type = type;
      this.props = props || {};
      this.children = children || [];
      this.mods = [];
    }
  }
  ['padding', 'font', 'fontWeight', 'bold', 'italic', 'monospaced', 'foregroundColor', 'foregroundStyle',
    'background', 'cornerRadius', 'frame', 'opacity', 'tint', 'onTapGesture', 'shadow', 'border',
    'rotationEffect', 'scaleEffect', 'offset', 'multilineTextAlignment', 'lineLimit', 'disabled',
    'buttonStyle', 'textFieldStyle', 'listStyle', 'navigationTitle', 'ignoresSafeArea', 'clipShape',
    'fill', 'gradient', 'blur', 'grayscale', 'saturation', 'brightness', 'contrast', 'aspectRatio',
    'onLongPressGesture', 'contextMenu', 'badge', 'hidden', 'refreshable', 'imageScale', 'toggleStyle',
    'pickerStyle', 'controlSize', 'fixedSize', 'labelsHidden', 'zIndex', 'animation', 'symbolRenderingMode',
    'overlay', 'listRowBackground', 'scrollContentBackground', 'containerBackground', 'minimumScaleFactor',
    'truncationMode', 'tracking', 'underline', 'strikethrough', 'shadowColor', 'glass']
    .forEach((name) => {
      View.prototype[name] = function (...args) { this.mods.push([name].concat(args)); return this; };
    });

  const isView = (x) => x instanceof View;
  const isOpts = (x) => x && typeof x === 'object' && !isView(x) && !Array.isArray(x);
  const kids = (args) => {
    const out = [];
    const walk = (list) => list.forEach((x) => {
      if (Array.isArray(x)) walk(x);
      else if (x != null && x !== false && x !== true) out.push(isView(x) ? x : g.Text(x));
    });
    walk(args);
    return out;
  };
  const container = (type) => (...args) => {
    const opts = isOpts(args[0]) ? args.shift() : {};
    return new View(type, opts, kids(args));
  };

  g.View = View;
  g.VStack = container('vstack');
  g.HStack = container('hstack');
  g.ZStack = container('zstack');
  g.ScrollView = container('scroll');
  g.List = container('list');
  g.Form = container('list');
  g.Section = (title, ...children) => new View('section', { title: title == null ? '' : str(title) }, kids(children));
  g.ForEach = (items, fn) => Array.from(items).map(fn);
  g.Text = (t) => new View('text', { text: typeof t === 'string' ? t : str(t) });
  g.Button = (label, action) => isView(label)
    ? new View('button', { action }, [label])
    : new View('button', { label: str(label), action });
  // Image("star.fill"), Image("https://…"), Image("data:image/png;base64,…"),
  // Image({ base64 }), Image({ file: "pic.png" }), Image({ url }), Image({ emoji: "🔥" })
  g.Image = (src, opts) => {
    let props;
    if (src && typeof src === 'object') props = Object.assign({}, src);
    else {
      const s = String(src);
      if (s.startsWith('data:')) props = { base64: s };
      else if (/^https?:\/\//.test(s)) props = { url: s };
      else props = { system: s };
    }
    return new View('image', Object.assign(props, opts || {}));
  };
  g.Grid = (...args) => {
    const opts = isOpts(args[0]) ? args.shift() : {};
    return new View('grid', { columns: opts.columns || 2, spacing: opts.spacing, minWidth: opts.minWidth }, kids(args));
  };
  g.Circle = () => new View('shape', { shape: 'circle' });
  g.Rectangle = () => new View('shape', { shape: 'rect' });
  g.RoundedRectangle = (r) => new View('shape', { shape: 'rounded', radius: r == null ? 12 : r });
  g.Capsule = () => new View('shape', { shape: 'capsule' });
  g.LinearGradient = (colors, direction) => new View('gradient', { colors: colors || ['blue', 'purple'], direction: direction || 'vertical' });
  g.Gauge = (value, opts) => {
    opts = opts || {};
    return new View('gauge', { value: +value || 0, min: opts.min || 0, max: opts.max == null ? 1 : opts.max,
      label: opts.label == null ? '' : str(opts.label), style: opts.style || 'linear', color: opts.color });
  };
  g.DatePicker = (label, date, onChange, opts) => new View('datepicker', {
    label: str(label), value: new Date(date == null ? Date.now() : date).toISOString(),
    mode: (opts && opts.mode) || 'both', style: (opts && opts.style) || 'compact',
    onChange: onChange ? (iso) => onChange(new Date(iso)) : undefined,
  });
  g.ColorPicker = (label, hex, onChange) => new View('colorpicker', { label: str(label), value: hex || '#007AFF', onChange });
  g.Menu = (label, ...items) => isView(label)
    ? new View('menu', { }, [label].concat(kids(items)))
    : new View('menu', { label: str(label) }, kids(items));
  g.DisclosureGroup = (label, ...children) => new View('disclosure', { label: str(label) }, kids(children));
  g.GroupBox = (title, ...children) => new View('groupbox', { title: title == null ? '' : str(title) }, kids(children));
  g.TabView = (...tabs) => new View('tabview', {}, kids(tabs));
  g.Tab = (title, icon, ...children) => new View('tab', { title: str(title), system: icon || 'circle' }, kids(children));
  g.NavigationLink = (label, ...destination) =>
    new View('navlink', {}, [isView(label) ? label : g.Text(label), g.VStack(...destination)]);
  g.TextEditor = (text, onChange) => new View('texteditor', { value: text == null ? '' : String(text), onChange });
  g.Chart = (data, opts) => {
    opts = opts || {};
    const xk = opts.x || 'x', yk = opts.y || 'y', sk = opts.series || 'series';
    return new View('chart', { type: opts.type || 'bar', color: opts.color,
      data: (data || []).map((d) => ({ x: str(d[xk]), y: +d[yk] || 0, s: d[sk] == null ? '' : str(d[sk]) })) });
  };
  g.Map = (opts) => {
    opts = opts || {};
    return new View('map', { latitude: +opts.latitude || 0, longitude: +opts.longitude || 0, span: opts.span || 0.05,
      pins: (opts.pins || []).map((p) => ({ latitude: +p.latitude, longitude: +p.longitude, title: p.title ? str(p.title) : '' })) });
  };
  g.WebView = (src) => new View('web', (src && typeof src === 'object') ? src
    : (/^https?:\/\//.test(String(src)) ? { url: String(src) } : { html: String(src) }));
  g.Emoji = (e, size) => new View('text', { text: String(e) }).font(size || 48);
  g.Badge = (text, color) => g.Text(text).font('caption', 'bold').padding('horizontal', 8).padding('vertical', 3)
    .background(color || 'red').foregroundColor('white').clipShape('capsule');
  g.Card = (...args) => {
    const opts = isOpts(args[0]) ? args.shift() : {};
    return g.VStack(Object.assign({ alignment: 'leading', spacing: 8 }, opts), ...args)
      .padding().frame({ maxWidth: Infinity, alignment: 'leading' })
      .background(opts.color || 'secondaryBackground').cornerRadius(opts.radius || 16);
  };
  g.Label = (title, systemImage) => new View('label', { title: str(title), system: systemImage || 'circle' });
  g.Spacer = (min) => new View('spacer', { min: min || 0 });
  g.Divider = () => new View('divider');
  g.Toggle = (label, isOn, onChange) => new View('toggle', { label: str(label), value: !!isOn, onChange });
  g.Slider = (value, onChange, opts) => {
    opts = opts || {};
    return new View('slider', { value: +value || 0, onChange, min: opts.min == null ? 0 : opts.min,
      max: opts.max == null ? 1 : opts.max, step: opts.step || 0 });
  };
  g.Stepper = (label, value, onChange, opts) => {
    opts = opts || {};
    return new View('stepper', { label: str(label), value: +value || 0, onChange, step: opts.step || 1,
      min: opts.min == null ? -1e15 : opts.min, max: opts.max == null ? 1e15 : opts.max });
  };
  g.TextField = (placeholder, text, onChange, onSubmit) =>
    new View('textfield', { placeholder: str(placeholder), value: text == null ? '' : String(text), onChange, onSubmit });
  g.SecureField = (placeholder, text, onChange, onSubmit) =>
    new View('textfield', { placeholder: str(placeholder), value: text == null ? '' : String(text), onChange, onSubmit, secure: true });
  g.Picker = (label, options, selection, onChange) =>
    new View('picker', { label: str(label), options: (options || []).map(str), value: selection == null ? '' : str(selection), onChange });
  g.ProgressView = (value, total) => new View('progress', { value: value == null ? null : +value, total: total || 1 });
  g.Color = (c) => new View('color', { color: c });
  g.Link = (label, url) => new View('link', { label: str(label), url: String(url) });

  // ---------- rendering ----------
  let renderFn = null;
  let callbacks = {};
  let callbackCount = 0;
  const reg = (fn) => { const id = 'c' + (++callbackCount); callbacks[id] = fn; return { __cb: id }; };
  const conv = (x) => {
    if (typeof x === 'function') return reg(x);
    if (Array.isArray(x)) return x.map(conv);
    if (x && typeof x === 'object' && !isView(x) && !(x instanceof Date)) {
      const o = {};
      Object.keys(x).forEach((k) => { if (x[k] !== undefined) o[k] = conv(x[k]); });
      return o;
    }
    return x;
  };
  const ser = (v) => {
    const props = {};
    Object.keys(v.props).forEach((k) => {
      const p = v.props[k];
      if (p !== undefined) props[k] = conv(p);
    });
    const mods = v.mods.map((m) => m.map(conv));
    return { type: v.type, props, mods, children: v.children.map(ser) };
  };
  const infinity = (k, v) => (v === Infinity ? 'inf' : v);
  const push = () => {
    if (!renderFn) return;
    callbacks = {};
    callbackCount = 0;
    let tree;
    try { tree = renderFn(); } catch (e) { N.log('error', g.__amod_errfmt(e)); return; }
    if (!isView(tree)) tree = g.VStack(tree);
    N.render(JSON.stringify(ser(tree), infinity));
  };
  let queued = false;
  const schedule = () => {
    if (queued) return;
    queued = true;
    g.setTimeout(() => { queued = false; push(); }, 0);
  };
  g.__amod_invoke = (id, value) => {
    const fn = callbacks[id];
    if (!fn) return;
    try {
      const r = fn(value === null ? undefined : value);
      if (r && typeof r.then === 'function') r.then(schedule, (e) => N.log('error', g.__amod_errfmt(e)));
    } catch (e) {
      if (!(e && e.message === '__amod_exit__')) N.log('error', g.__amod_errfmt(e));
    }
    push();
  };
  g.ui = {
    render: (fn) => { renderFn = typeof fn === 'function' ? fn : () => fn; push(); },
    refresh: schedule,
    title: (t) => N.title(str(t)),
    close: () => N.close(),
    console: () => N.showConsole(),
  };
  g.state = (initial) => new Proxy(initial || {}, {
    set(target, key, value) { target[key] = value; schedule(); return true; },
  });
})(this);
"""#
}
