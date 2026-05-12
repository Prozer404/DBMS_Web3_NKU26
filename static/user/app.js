/**
 * Web3 用户端 — 弹窗登录注册 + 各模块数据
 */
const TOKEN_KEY = "USER_ACCESS_TOKEN";

const $ = (s) => document.querySelector(s);
const $$ = (s) => document.querySelectorAll(s);

function getToken() {
  return localStorage.getItem(TOKEN_KEY) || "";
}

function setToken(t) {
  if (t) localStorage.setItem(TOKEN_KEY, t);
  else localStorage.removeItem(TOKEN_KEY);
}

function toast(msg, ok) {
  const el = $("#toast");
  el.textContent = msg;
  el.className = "show " + (ok ? "ok" : "err");
  clearTimeout(el._t);
  el._t = setTimeout(() => el.classList.remove("show"), 3500);
}

async function api(path, opts = {}) {
  const headers = { Accept: "application/json", ...(opts.headers || {}) };
  if (opts.body && typeof opts.body === "object" && !(opts.body instanceof FormData)) {
    headers["Content-Type"] = "application/json";
    opts.body = JSON.stringify(opts.body);
  }
  const tok = getToken();
  if (tok) headers["Authorization"] = "Bearer " + tok;
  const r = await fetch(path, { ...opts, headers });
  const text = await r.text();
  let data;
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    data = { detail: text };
  }
  if (!r.ok) {
    const d = data.detail;
    const msg = typeof d === "string" ? d : Array.isArray(d) ? d.map((x) => x.msg).join("; ") : JSON.stringify(d || data);
    throw new Error(msg || r.statusText);
  }
  return data;
}

function requireAuth() {
  if (!getToken()) {
    toast("请先登录", false);
    openModal();
    return false;
  }
  return true;
}

function openModal() {
  $("#overlay").classList.add("show");
}
function closeModal() {
  $("#overlay").classList.remove("show");
}

function updateUserBar(me) {
  const info = $("#userInfo");
  const btnAuth = $("#btnOpenAuth");
  const btnOut = $("#btnLogout");
  if (me && me.email) {
    info.innerHTML = '<span class="email">' + esc(me.email) + "</span> · KYC " + esc(me.kyc_status);
    btnAuth.style.display = "none";
    btnOut.style.display = "inline-block";
  } else {
    info.textContent = "游客（仅可查看行情）";
    btnAuth.style.display = "inline-block";
    btnOut.style.display = "none";
  }
}

function esc(s) {
  if (s == null) return "";
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function renderTable(rows, extraColHtmlFn) {
  if (!rows || !rows.length) return "<p class='muted'>暂无数据</p>";
  const cols = Object.keys(rows[0]);
  let h = "<table><thead><tr>";
  cols.forEach((c) => (h += "<th>" + esc(c) + "</th>"));
  if (extraColHtmlFn) h += "<th></th>";
  h += "</tr></thead><tbody>";
  for (const r of rows) {
    h += "<tr>";
    cols.forEach((c) => (h += "<td class='mono'>" + esc(r[c]) + "</td>"));
    if (extraColHtmlFn) h += "<td>" + extraColHtmlFn(r) + "</td>";
    h += "</tr>";
  }
  h += "</tbody></table>";
  return h;
}

async function refreshMe() {
  if (!getToken()) {
    updateUserBar(null);
    return null;
  }
  try {
    const me = await api("/api/me");
    updateUserBar(me);
    return me;
  } catch {
    setToken("");
    updateUserBar(null);
    openModal();
    return null;
  }
}

async function loadPublicPairs() {
  const rows = await api("/api/public/pairs");
  $("#wrapPairs").innerHTML = renderTable(rows);
  const sel = $("#ordPair");
  sel.innerHTML = "";
  for (const p of rows) {
    const o = document.createElement("option");
    o.value = p.id;
    o.textContent = p.id + " · " + p.base_currency + "/" + p.quote_currency;
    sel.appendChild(o);
  }
}

async function loadAssets() {
  if (!requireAuth()) return;
  const rows = await api("/api/me/assets");
  $("#wrapAssets").innerHTML = renderTable(rows);
}

async function loadLedger() {
  if (!requireAuth()) return;
  const rows = await api("/api/me/ledger");
  $("#wrapLedger").innerHTML = renderTable(rows);
}

async function loadOrders() {
  if (!requireAuth()) return;
  const rows = await api("/api/me/orders");
  $("#wrapOrders").innerHTML = renderTable(rows, (r) => {
    const st = Number(r.status);
    if (st === 0 || st === 1)
      return '<button type="button" class="small btn-cancel-ord" data-id="' + esc(r.id) + '">撤单</button>';
    return "";
  });
  $("#wrapOrders").querySelectorAll(".btn-cancel-ord").forEach((b) => {
    b.addEventListener("click", async () => {
      if (!confirm("确认撤单 " + b.dataset.id + "？")) return;
      try {
        await api("/api/me/orders/" + b.dataset.id + "/cancel", { method: "POST" });
        toast("已撤单", true);
        loadOrders();
      } catch (e) {
        toast(e.message, false);
      }
    });
  });
}

async function loadTrades() {
  if (!requireAuth()) return;
  const rows = await api("/api/me/trades");
  $("#wrapTrades").innerHTML = renderTable(rows);
}

async function loadDeps() {
  if (!requireAuth()) return;
  const rows = await api("/api/me/deposits");
  $("#wrapDeps").innerHTML = renderTable(rows);
}

async function loadWds() {
  if (!requireAuth()) return;
  const rows = await api("/api/me/withdrawals");
  $("#wrapWds").innerHTML = renderTable(rows);
}

// ----- nav -----
$$("#nav button").forEach((btn) => {
  btn.addEventListener("click", () => {
    $$("#nav button").forEach((b) => b.classList.remove("active"));
    $$(".panel").forEach((p) => p.classList.remove("active"));
    btn.classList.add("active");
    const p = $("#panel-" + btn.dataset.tab);
    if (p) p.classList.add("active");
    const tab = btn.dataset.tab;
    if (tab === "pairs") loadPublicPairs().catch((e) => toast(e.message, false));
    if (tab === "assets") loadAssets().catch((e) => toast(e.message, false));
    if (tab === "ledger") loadLedger().catch((e) => toast(e.message, false));
    if (tab === "orders") loadOrders().catch((e) => toast(e.message, false));
    if (tab === "trades") loadTrades().catch((e) => toast(e.message, false));
    if (tab === "deposits") loadDeps().catch((e) => toast(e.message, false));
    if (tab === "withdrawals") loadWds().catch((e) => toast(e.message, false));
  });
});

// ----- modal tabs -----
$("#tabLogin").addEventListener("click", () => {
  $("#tabLogin").classList.add("active");
  $("#tabReg").classList.remove("active");
  $("#formLogin").style.display = "";
  $("#formReg").style.display = "none";
});
$("#tabReg").addEventListener("click", () => {
  $("#tabReg").classList.add("active");
  $("#tabLogin").classList.remove("active");
  $("#formReg").style.display = "";
  $("#formLogin").style.display = "none";
});

function bindClose() {
  const fn = () => closeModal();
  $("#btnModalClose").addEventListener("click", fn);
  $("#btnModalClose2").addEventListener("click", fn);
}
bindClose();

$("#btnOpenAuth").addEventListener("click", openModal);

$("#btnLogout").addEventListener("click", () => {
  setToken("");
  updateUserBar(null);
  openModal();
  toast("已退出", true);
});

$("#formLogin").addEventListener("submit", async (e) => {
  e.preventDefault();
  try {
    const data = await api("/api/auth/login", {
      method: "POST",
      body: { email: $("#loginEmail").value.trim(), password: $("#loginPass").value },
    });
    setToken(data.access_token);
    closeModal();
    await refreshMe();
    toast("登录成功", true);
  } catch (err) {
    toast(err.message, false);
  }
});

$("#formReg").addEventListener("submit", async (e) => {
  e.preventDefault();
  try {
    const data = await api("/api/auth/register", {
      method: "POST",
      body: { email: $("#regEmail").value.trim(), password: $("#regPass").value },
    });
    setToken(data.access_token);
    closeModal();
    await refreshMe();
    toast("注册成功", true);
  } catch (err) {
    toast(err.message, false);
  }
});

$("#btnLoadPairs").addEventListener("click", () => loadPublicPairs().catch((e) => toast(e.message, false)));
$("#btnLoadAssets").addEventListener("click", () => loadAssets().catch((e) => toast(e.message, false)));
$("#btnLoadLedger").addEventListener("click", () => loadLedger().catch((e) => toast(e.message, false)));
$("#btnLoadOrders").addEventListener("click", () => loadOrders().catch((e) => toast(e.message, false)));
$("#btnLoadTrades").addEventListener("click", () => loadTrades().catch((e) => toast(e.message, false)));
$("#btnLoadDeps").addEventListener("click", () => loadDeps().catch((e) => toast(e.message, false)));
$("#btnLoadWds").addEventListener("click", () => loadWds().catch((e) => toast(e.message, false)));

$("#btnPlaceOrder").addEventListener("click", async () => {
  if (!requireAuth()) return;
  const body = {
    pair_id: parseInt($("#ordPair").value, 10),
    side: parseInt($("#ordSide").value, 10),
    order_type: parseInt($("#ordType").value, 10),
    price: $("#ordPrice").value.trim() || "0",
    total_amount: $("#ordAmt").value.trim(),
  };
  if (!body.total_amount) {
    toast("请填写数量", false);
    return;
  }
  try {
    await api("/api/me/orders", { method: "POST", body });
    toast("订单已提交", true);
    loadOrders();
  } catch (e) {
    toast(e.message, false);
  }
});

$("#btnDepSubmit").addEventListener("click", async () => {
  if (!requireAuth()) return;
  const body = {
    currency: $("#depCcy").value.trim(),
    amount: $("#depAmt").value.trim(),
    tx_hash: $("#depHash").value.trim() || null,
  };
  if (!body.currency || !body.amount) {
    toast("填写币种与金额", false);
    return;
  }
  try {
    await api("/api/me/deposits", { method: "POST", body });
    toast("充值申请已提交", true);
    loadDeps();
  } catch (e) {
    toast(e.message, false);
  }
});

$("#btnWdSubmit").addEventListener("click", async () => {
  if (!requireAuth()) return;
  const body = {
    currency: $("#wdCcy").value.trim(),
    address: $("#wdAddr").value.trim(),
    amount: $("#wdAmt").value.trim(),
  };
  if (!body.currency || !body.address || !body.amount) {
    toast("填写完整", false);
    return;
  }
  try {
    await api("/api/me/withdrawals", { method: "POST", body });
    toast("提现申请已提交", true);
    loadWds();
  } catch (e) {
    toast(e.message, false);
  }
});

$("#btnKycSubmit").addEventListener("click", async () => {
  if (!requireAuth()) return;
  const body = {
    real_name: $("#kycName").value.trim(),
    id_card_number: $("#kycId").value.trim(),
    document_url: $("#kycUrl").value.trim() || null,
  };
  if (!body.real_name || !body.id_card_number) {
    toast("填写姓名与证件号", false);
    return;
  }
  try {
    await api("/api/me/kyc", { method: "POST", body });
    toast("KYC 已提交", true);
    await refreshMe();
  } catch (e) {
    toast(e.message, false);
  }
});

// init
(async function init() {
  try {
    await loadPublicPairs();
  } catch (e) {
    toast("无法加载行情: " + e.message, false);
  }
  if (getToken()) {
    await refreshMe();
    closeModal();
  } else {
    openModal();
  }
})();
