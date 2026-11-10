/// Linux headless 版内嵌 WebUI：单页、零外部资源，可在仅能访问校园网
/// 的树莓派上直接使用。页面不含任何持久化逻辑，凭据只存在于表单输入框。
///
/// 以 raw string 内嵌，避免 Dart 插值与 JS 模板语法冲突；修改时直接改
/// 下方 HTML/CSS/JS 即可，无需重新生成资源。
const String kHeadlessWebUiHtml = r'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>GiWiFi 校园网认证台</title>
<style>
  :root {
    --bg: #0f1115;
    --card: #171a21;
    --line: #272c36;
    --text: #e8eaf0;
    --muted: #9aa3b2;
    --accent: #4f8cff;
    --ok: #3fb950;
    --warn: #d29922;
    --err: #f85149;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    padding: 20px 16px 40px;
    background: var(--bg);
    color: var(--text);
    font: 15px/1.6 "PingFang SC", "Microsoft YaHei", "Noto Sans CJK SC", system-ui, sans-serif;
  }
  main { max-width: 560px; margin: 0 auto; display: grid; gap: 14px; }
  header { display: flex; align-items: center; justify-content: space-between; gap: 10px; }
  h1 { margin: 0; font-size: 17px; font-weight: 600; letter-spacing: .2px; }
  .badge {
    flex: none; font-size: 13px; padding: 3px 11px; border-radius: 999px;
    background: var(--line); color: var(--muted);
  }
  .badge.online { background: rgba(63, 185, 80, .14); color: var(--ok); }
  .badge.offline { background: rgba(248, 81, 73, .14); color: var(--err); }
  .card {
    background: var(--card); border: 1px solid var(--line); border-radius: 14px;
    padding: 16px; display: grid; gap: 12px;
  }
  .rows { display: grid; gap: 8px; }
  .row { display: flex; justify-content: space-between; gap: 12px; font-size: 14px; }
  .row span { color: var(--muted); flex: none; }
  .row b { font-weight: 500; text-align: right; word-break: break-all; }
  .label { font-size: 13px; color: var(--muted); margin-bottom: -6px; }
  .slots { display: flex; flex-wrap: wrap; gap: 8px; }
  .slot {
    border: 1px solid var(--line); background: transparent; color: var(--text);
    border-radius: 999px; padding: 6px 14px; font-size: 14px; cursor: pointer;
  }
  .slot.active { border-color: var(--accent); background: rgba(79, 140, 255, .16); color: #bcd3ff; }
  input, textarea {
    width: 100%; border: 1px solid var(--line); background: #10131a; color: var(--text);
    border-radius: 10px; padding: 10px 12px; font: inherit; outline: none;
  }
  input:focus, textarea:focus { border-color: var(--accent); }
  textarea { resize: vertical; min-height: 58px; }
  .actions { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 2px; }
  button {
    border: 1px solid var(--line); background: transparent; color: var(--text);
    border-radius: 10px; padding: 10px 18px; font: inherit; cursor: pointer;
  }
  button.primary { background: var(--accent); border-color: var(--accent); color: #fff; font-weight: 600; }
  button:disabled { opacity: .55; cursor: default; }
  .message {
    margin: 0; padding: 10px 12px; border-radius: 10px; font-size: 14px;
    background: rgba(154, 163, 178, .1); color: var(--text); white-space: pre-wrap;
  }
  .message.ok { background: rgba(63, 185, 80, .12); color: #9ae6a8; }
  .message.warn { background: rgba(210, 153, 34, .12); color: #e8c26a; }
  .message.error { background: rgba(248, 81, 73, .12); color: #ff9d99; }
  .foot { margin: 2px 4px 0; font-size: 12px; color: var(--muted); }
</style>
</head>
<body>
<main>
  <header>
    <h1>GiWiFi 校园网认证台</h1>
    <span id="status-badge" class="badge">检测中…</span>
  </header>

  <section class="card">
    <div class="rows">
      <div class="row"><span>在线时长</span><b id="duration">—</b></div>
      <div class="row"><span>门户地址</span><b id="portal">—</b></div>
      <div class="row"><span>AC 名称</span><b id="ac">—</b></div>
      <div class="row"><span>本机 IP</span><b id="ip">—</b></div>
    </div>
  </section>

  <section class="card">
    <div class="label">终端槽位（认证后计为该设备类型）</div>
    <div id="slots" class="slots"></div>
    <textarea id="custom-ua" rows="2" placeholder="自定义 User-Agent" hidden></textarea>

    <label class="label" for="username">校园网账号</label>
    <input id="username" autocomplete="username" autocapitalize="off" spellcheck="false">

    <label class="label" for="password">密码</label>
    <input id="password" type="password" autocomplete="off">

    <div class="actions">
      <button id="login" class="primary" type="button">认证登录</button>
      <button id="refresh" type="button">刷新状态</button>
      <button id="logout" type="button">注销</button>
    </div>
    <p id="message" class="message" hidden></p>
  </section>

  <p class="foot">凭据只保存在当前页面内存中，提交后不做任何落盘；刷新或关闭页面即清除。</p>
</main>

<script>
(function () {
  'use strict';

  var TOKEN = new URLSearchParams(location.search).get('token') || '';
  var profiles = [];
  var currentSlot = 'pc';
  var busy = false;

  function $(id) { return document.getElementById(id); }

  function api(path) {
    if (!TOKEN) return path;
    return path + (path.indexOf('?') >= 0 ? '&' : '?') + 'token=' + encodeURIComponent(TOKEN);
  }

  function setBusy(value) {
    busy = value;
    var ids = ['login', 'refresh', 'logout'];
    for (var i = 0; i < ids.length; i++) $(ids[i]).disabled = value;
    var slots = $('slots').children;
    for (var j = 0; j < slots.length; j++) slots[j].disabled = value;
  }

  function setMessage(text, kind) {
    var el = $('message');
    el.hidden = !text;
    el.textContent = text || '';
    el.className = 'message' + (kind ? ' ' + kind : '');
  }

  function setBadge(status) {
    var el = $('status-badge');
    var text = { online: '在线', offline: '未认证', unknown: '状态未知' };
    el.textContent = text[status] || '状态未知';
    el.className = 'badge ' + (status === 'online' ? 'online' : status === 'offline' ? 'offline' : '');
  }

  function renderSlots() {
    var box = $('slots');
    box.textContent = '';
    for (var i = 0; i < profiles.length; i++) {
      (function (profile) {
        var button = document.createElement('button');
        button.type = 'button';
        button.className = 'slot' + (profile.id === currentSlot ? ' active' : '');
        button.textContent = profile.label;
        button.disabled = busy;
        button.addEventListener('click', function () { selectSlot(profile.id); });
        box.appendChild(button);
      })(profiles[i]);
    }
  }

  function selectSlot(id) {
    currentSlot = id;
    $('custom-ua').hidden = id !== 'custom';
    renderSlots();
    refreshStatus();
  }

  function slotPayload() {
    return { slot: currentSlot, custom_ua: $('custom-ua').value.trim() };
  }

  function fillPortal(portal) {
    portal = portal || {};
    $('portal').textContent = portal.baseUrl || '—';
    $('ac').textContent = portal.acName || '—';
    $('ip').textContent = portal.clientIp || '—';
  }

  function requestJson(path, options) {
    return fetch(api(path), options).then(function (response) {
      return response.json().catch(function () { return {}; }).then(function (data) {
        if (!response.ok && !data.error) data.error = 'HTTP ' + response.status;
        return data;
      });
    });
  }

  async function loadProfiles() {
    try {
      var data = await requestJson('/api/profiles');
      profiles = data.profiles || [];
      if (profiles.length) {
        var found = false;
        for (var i = 0; i < profiles.length; i++) if (profiles[i].id === currentSlot) found = true;
        if (!found) currentSlot = profiles[0].id;
      }
      renderSlots();
    } catch (e) {
      setMessage('槽位列表加载失败：' + e, 'error');
    }
  }

  async function refreshStatus() {
    if (busy) return;
    setBusy(true);
    var payload = slotPayload();
    try {
      var data = await requestJson(
        '/api/status?slot=' + encodeURIComponent(payload.slot) +
        '&custom_ua=' + encodeURIComponent(payload.custom_ua)
      );
      if (data.error) { setMessage(data.error, 'error'); return; }
      setBadge(data.status);
      $('duration').textContent = data.duration || '—';
      fillPortal(data.portal);
    } catch (e) {
      setMessage('状态检测失败：' + e, 'error');
    } finally {
      setBusy(false);
    }
  }

  async function doLogin(extra) {
    extra = extra || {};
    if (busy) return;
    var username = $('username').value.trim();
    var password = $('password').value;
    if (!username || !password) { setMessage('请先填写账号和密码', 'error'); return; }

    setBusy(true);
    setMessage('正在认证…');
    var retry = null;
    try {
      var body = {
        username: username,
        password: password,
        slot: currentSlot,
        custom_ua: $('custom-ua').value.trim(),
        confirm_rebind: !!extra.confirm_rebind,
        confirm_switch: !!extra.confirm_switch
      };
      var data = await requestJson('/api/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
      });
      if (data.error) {
        setMessage(data.error, 'error');
      } else if (data.needsRebind && !extra.confirm_rebind) {
        if (confirm((data.rebindInfo || '服务器要求更换绑定设备') +
          '\n\n确认后将自动提交换绑并重新认证，是否继续？')) {
          retry = { confirm_rebind: true };
        } else {
          setMessage('已取消换绑，认证未完成。', 'warn');
        }
      } else if (data.alreadyOnline && !extra.confirm_switch) {
        if (confirm('当前设备已在线。\n\n确认后将先注销当前在线设备，再按所选槽位重新认证（会校验账号密码）。是否继续？')) {
          retry = { confirm_switch: true };
        } else {
          setMessage('当前设备已在线，已取消切换（未验证账号密码）。', 'warn');
        }
      } else {
        setMessage(data.message, data.success ? 'ok' : 'error');
        fillPortal(data.portal);
        if (data.success) {
          $('duration').textContent = data.onlineDuration || '—';
          setBadge('online');
        } else {
          refreshStatus();
        }
      }
    } catch (e) {
      setMessage('认证请求异常：' + e, 'error');
    } finally {
      setBusy(false);
    }
    if (retry) await doLogin(retry);
  }

  async function doLogout() {
    if (busy) return;
    if (!confirm('确认注销当前在线设备？')) return;
    setBusy(true);
    try {
      var payload = slotPayload();
      var data = await requestJson('/api/logout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      if (data.error) {
        setMessage(data.error, 'error');
      } else {
        setMessage(data.message || (data.success ? '已注销' : '注销失败'), data.success ? 'ok' : 'error');
        setBadge(data.success ? 'offline' : 'unknown');
        $('duration').textContent = '—';
      }
    } catch (e) {
      setMessage('注销请求异常：' + e, 'error');
    } finally {
      setBusy(false);
    }
    refreshStatus();
  }

  $('login').addEventListener('click', function () { doLogin(); });
  $('refresh').addEventListener('click', refreshStatus);
  $('logout').addEventListener('click', doLogout);
  $('custom-ua').addEventListener('change', function () { refreshStatus(); });
  $('password').addEventListener('keydown', function (event) {
    if (event.key === 'Enter') doLogin();
  });

  loadProfiles().then(refreshStatus);
})();
</script>
</body>
</html>
''';
