/**
 * Web3 管理后台 — 调用同源的 /api/*（FastAPI + MySQL）
 */
const $ = (sel) => document.querySelector(sel);

function adminHeaders() {
  const h = { "Content-Type": "application/json" };
  const k = localStorage.getItem("ADMIN_API_KEY");
  if (k) h["X-Admin-Key"] = k;
  return h;
}

async function api(path, opts = {}) {
  const r = await fetch(path, {
    ...opts,
    headers: { ...adminHeaders(), ...(opts.headers || {}) },
  });
  const text = await r.text();
  let data;
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    data = { detail: text };
  }
  if (!r.ok) {
    const msg = typeof data.detail === "string" ? data.detail : JSON.stringify(data.detail || data);
    throw new Error(msg || r.statusText);
  }
  return data;
}

function showStatus(msg, isErr) {
  const el = $("#status");
  el.textContent = msg;
  el.className = "show " + (isErr ? "err" : "ok");
}

function esc(s) {
  if (s == null) return "";
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

// ----- tabs -----
document.querySelectorAll("#tabs button").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll("#tabs button").forEach((b) => b.classList.remove("active"));
    document.querySelectorAll(".panel").forEach((p) => p.classList.remove("active"));
    btn.classList.add("active");
    const id = "panel-" + btn.dataset.tab;
    const panel = document.getElementById(id);
    if (panel) panel.classList.add("active");
  });
});

$("#btnSaveKey").addEventListener("click", () => {
  const v = $("#adminKey").value.trim();
  if (v) localStorage.setItem("ADMIN_API_KEY", v);
  else localStorage.removeItem("ADMIN_API_KEY");
  showStatus(v ? "已保存到浏览器 localStorage（勿在公共电脑使用）" : "已清除密钥", false);
});

$("#btnHealth").addEventListener("click", async () => {
  try {
    const d = await api("/api/health");
    showStatus(d.ok ? "数据库连接正常" : JSON.stringify(d), !d.ok);
  } catch (e) {
    showStatus(String(e.message || e), true);
  }
});

// ----- users -----
async function loadUsers() {
  const rows = await api("/api/admin/users");
  if (!rows.length) {
    $("#wrap-users").innerHTML = "<p class='muted'>无数据</p>";
    return;
  }
  const cols = Object.keys(rows[0]);
  let html = "<table><thead><tr>";
  cols.forEach((c) => (html += "<th>" + esc(c) + "</th>"));
  html += "<th>操作</th></tr></thead><tbody>";
  for (const r of rows) {
    html += "<tr>";
    cols.forEach((c) => (html += "<td class='mono'>" + esc(r[c]) + "</td>"));
    html += `<td>
      <select data-id="${r.id}" class="kyc-sel">
        <option value="0" ${r.kyc_status === 0 ? "selected" : ""}>0未认证</option>
        <option value="1" ${r.kyc_status === 1 ? "selected" : ""}>1审核中</option>
        <option value="2" ${r.kyc_status === 2 ? "selected" : ""}>2已通过</option>
        <option value="3" ${r.kyc_status === 3 ? "selected" : ""}>3已拒绝</option>
      </select>
      <button type="button" class="small primary btn-save-kyc" data-id="${r.id}">保存KYC</button>
      <button type="button" class="small danger btn-del-user" data-id="${r.id}">删除</button>
    </td></tr>`;
  }
  html += "</tbody></table>";
  $("#wrap-users").innerHTML = html;
  $("#wrap-users").querySelectorAll(".btn-save-kyc").forEach((b) => {
    b.addEventListener("click", async () => {
      const id = b.dataset.id;
      const sel = $("#wrap-users").querySelector(`select.kyc-sel[data-id="${id}"]`);
      try {
        await api("/api/admin/users/" + id, {
          method: "PATCH",
          body: JSON.stringify({ kyc_status: parseInt(sel.value, 10) }),
        });
        showStatus("用户 " + id + " KYC 已更新", false);
        loadUsers();
      } catch (e) {
        showStatus(e.message, true);
      }
    });
  });
  $("#wrap-users").querySelectorAll(".btn-del-user").forEach((b) => {
    b.addEventListener("click", async () => {
      if (!confirm("确定删除用户 " + b.dataset.id + "？若有外键引用将失败。")) return;
      try {
        await api("/api/admin/users/" + b.dataset.id, { method: "DELETE" });
        showStatus("已删除", false);
        loadUsers();
      } catch (e) {
        showStatus(e.message, true);
      }
    });
  });
}

$("#btnLoadUsers").addEventListener("click", () => loadUsers().catch((e) => showStatus(e.message, true)));
$("#btnCreateUser").addEventListener("click", async () => {
  const email = $("#nu_email").value.trim();
  const password_hash = $("#nu_hash").value.trim();
  const kyc_status = parseInt($("#nu_kyc").value, 10);
  if (!email || !password_hash) {
    showStatus("请填写邮箱与 password_hash", true);
    return;
  }
  try {
    await api("/api/admin/users", {
      method: "POST",
      body: JSON.stringify({ email, password_hash, kyc_status }),
    });
    showStatus("用户已创建", false);
    loadUsers();
  } catch (e) {
    showStatus(e.message, true);
  }
});

// ----- currencies -----
async function loadCurrencies() {
  const rows = await api("/api/admin/currencies");
  if (!rows.length) {
    $("#wrap-currencies").innerHTML = "<p>无数据</p>";
    return;
  }
  const cols = Object.keys(rows[0]);
  let html = "<table><thead><tr>";
  cols.forEach((c) => (html += "<th>" + esc(c) + "</th>"));
  html += "<th>操作</th></tr></thead><tbody>";
  for (const r of rows) {
    html += "<tr>";
    cols.forEach((c) => {
      if (c === "code")
        html += `<td class="mono">${esc(r[c])}<input type="hidden" class="cc-code" value="${esc(r[c])}" /></td>`;
      else
        html += `<td><input class="cc-${c}" data-code="${esc(r.code)}" value="${esc(r[c])}" style="width:100%;min-width:5rem" /></td>`;
    });
    html += `<td><button type="button" class="small primary btn-cc-save" data-code="${esc(r.code)}">保存</button>
      <button type="button" class="small danger btn-cc-del" data-code="${esc(r.code)}">删</button></td></tr>`;
  }
  html += "</tbody></table>";
  $("#wrap-currencies").innerHTML = html;
  $("#wrap-currencies").querySelectorAll(".btn-cc-save").forEach((b) => {
    b.addEventListener("click", async () => {
      const code = b.dataset.code;
      const tr = b.closest("tr");
      const name = tr.querySelector(".cc-name").value;
      const precision = parseInt(tr.querySelector(".cc-precision").value, 10);
      const withdrawal_fee = tr.querySelector(".cc-withdrawal_fee").value;
      const min_withdrawal = tr.querySelector(".cc-min_withdrawal").value;
      const is_active = parseInt(tr.querySelector(".cc-is_active").value, 10);
      try {
        await api("/api/admin/currencies/" + encodeURIComponent(code), {
          method: "PATCH",
          body: JSON.stringify({ name, precision, withdrawal_fee, min_withdrawal, is_active }),
        });
        showStatus("币种 " + code + " 已更新", false);
        loadCurrencies();
      } catch (e) {
        showStatus(e.message, true);
      }
    });
  });
  $("#wrap-currencies").querySelectorAll(".btn-cc-del").forEach((b) => {
    b.addEventListener("click", async () => {
      if (!confirm("删除币种 " + b.dataset.code + "？")) return;
      try {
        await api("/api/admin/currencies/" + encodeURIComponent(b.dataset.code), { method: "DELETE" });
        showStatus("已删除", false);
        loadCurrencies();
      } catch (e) {
        showStatus(e.message, true);
      }
    });
  });
}

$("#btnLoadCurrencies").addEventListener("click", () => loadCurrencies().catch((e) => showStatus(e.message, true)));
$("#btnCreateCurrency").addEventListener("click", async () => {
  const body = {
    code: $("#cc_code").value.trim(),
    name: $("#cc_name").value.trim(),
    precision: parseInt($("#cc_prec").value, 10),
    withdrawal_fee: $("#cc_wf").value.trim() || "0",
    min_withdrawal: $("#cc_mw").value.trim() || "0",
    is_active: parseInt($("#cc_act").value, 10),
  };
  if (!body.code || !body.name) {
    showStatus("填写 code 与 name", true);
    return;
  }
  try {
    await api("/api/admin/currencies", { method: "POST", body: JSON.stringify(body) });
    showStatus("币种已创建", false);
    loadCurrencies();
  } catch (e) {
    showStatus(e.message, true);
  }
});

// ----- pairs -----
async function loadPairs() {
  const rows = await api("/api/admin/trading-pairs");
  if (!rows.length) {
    $("#wrap-pairs").innerHTML = "<p>无数据</p>";
    return;
  }
  const cols = Object.keys(rows[0]);
  let html = "<table><thead><tr>";
  cols.forEach((c) => (html += "<th>" + esc(c) + "</th>"));
  html += "<th>操作</th></tr></thead><tbody>";
  for (const r of rows) {
    html += "<tr>";
    cols.forEach((c) => {
      if (c === "id")
        html += `<td class="mono">${esc(r[c])}<input type="hidden" class="pid" value="${esc(r.id)}" /></td>`;
      else
        html += `<td><input class="tp-${c}" data-id="${r.id}" value="${esc(r[c])}" /></td>`;
    });
    html += `<td><button type="button" class="small primary btn-tp-save" data-id="${r.id}">保存</button>
      <button type="button" class="small danger btn-tp-del" data-id="${r.id}">删</button></td></tr>`;
  }
  html += "</tbody></table>";
  $("#wrap-pairs").innerHTML = html;
  $("#wrap-pairs").querySelectorAll(".btn-tp-save").forEach((b) => {
    b.addEventListener("click", async () => {
      const id = b.dataset.id;
      const tr = b.closest("tr");
      const min_order_amount = tr.querySelector(".tp-min_order_amount").value;
      const price_precision = parseInt(tr.querySelector(".tp-price_precision").value, 10);
      const amount_precision = parseInt(tr.querySelector(".tp-amount_precision").value, 10);
      try {
        await api("/api/admin/trading-pairs/" + id, {
          method: "PATCH",
          body: JSON.stringify({ min_order_amount, price_precision, amount_precision }),
        });
        showStatus("交易对已更新", false);
        loadPairs();
      } catch (e) {
        showStatus(e.message, true);
      }
    });
  });
  $("#wrap-pairs").querySelectorAll(".btn-tp-del").forEach((b) => {
    b.addEventListener("click", async () => {
      if (!confirm("删除交易对 " + b.dataset.id + "？")) return;
      try {
        await api("/api/admin/trading-pairs/" + b.dataset.id, { method: "DELETE" });
        showStatus("已删除", false);
        loadPairs();
      } catch (e) {
        showStatus(e.message, true);
      }
    });
  });
}

$("#btnLoadPairs").addEventListener("click", () => loadPairs().catch((e) => showStatus(e.message, true)));
$("#btnCreatePair").addEventListener("click", async () => {
  const body = {
    base_currency: $("#pc_base").value.trim(),
    quote_currency: $("#pc_quote").value.trim(),
    min_order_amount: $("#pc_min").value.trim(),
    price_precision: parseInt($("#pc_pp").value, 10),
    amount_precision: parseInt($("#pc_ap").value, 10),
  };
  if (!body.base_currency || !body.quote_currency) {
    showStatus("填写 base 与 quote", true);
    return;
  }
  try {
    await api("/api/admin/trading-pairs", { method: "POST", body: JSON.stringify(body) });
    showStatus("交易对已创建", false);
    loadPairs();
  } catch (e) {
    showStatus(e.message, true);
  }
});

// ----- kyc -----
async function loadKyc() {
  const rows = await api("/api/admin/kyc-applications");
  if (!rows.length) {
    $("#wrap-kyc").innerHTML = "<p>无数据</p>";
    return;
  }
  const cols = Object.keys(rows[0]);
  let html = "<table><thead><tr>";
  cols.forEach((c) => (html += "<th>" + esc(c) + "</th>"));
  html += "<th>操作</th></tr></thead><tbody>";
  for (const r of rows) {
    html += "<tr>";
    cols.forEach((c) => (html += "<td class='mono'>" + esc(r[c]) + "</td>"));
    html += `<td>
      <select class="kyc-st" data-id="${r.id}">
        <option value="0" ${r.status === 0 ? "selected" : ""}>0待审核</option>
        <option value="1" ${r.status === 1 ? "selected" : ""}>1通过</option>
        <option value="2" ${r.status === 2 ? "selected" : ""}>2拒绝</option>
      </select>
      <input class="kyc-reason" data-id="${r.id}" placeholder="拒绝原因" value="${esc(r.reject_reason || "")}" style="width:10rem" />
      <input class="kyc-rev" data-id="${r.id}" placeholder="reviewer_id" value="${r.reviewer_id != null ? esc(r.reviewer_id) : ""}" style="width:5rem" />
      <button type="button" class="small primary btn-kyc-save" data-id="${r.id}">保存</button>
    </td></tr>`;
  }
  html += "</tbody></table>";
  $("#wrap-kyc").innerHTML = html;
  $("#wrap-kyc").querySelectorAll(".btn-kyc-save").forEach((b) => {
    b.addEventListener("click", async () => {
      const id = b.dataset.id;
      const st = document.querySelector(`select.kyc-st[data-id="${id}"]`).value;
      const reject_reason = document.querySelector(`input.kyc-reason[data-id="${id}"]`).value || null;
      const rid = document.querySelector(`input.kyc-rev[data-id="${id}"]`).value;
      const reviewer_id = rid === "" ? null : parseInt(rid, 10);
      try {
        await api("/api/admin/kyc-applications/" + id, {
          method: "PATCH",
          body: JSON.stringify({
            status: parseInt(st, 10),
            reject_reason,
            reviewer_id,
          }),
        });
        showStatus("KYC " + id + " 已更新", false);
        loadKyc();
        loadUsers();
      } catch (e) {
        showStatus(e.message, true);
      }
    });
  });
}

$("#btnLoadKyc").addEventListener("click", () => loadKyc().catch((e) => showStatus(e.message, true)));

// ----- deposits -----
async function loadDeposits() {
  const rows = await api("/api/admin/deposits");
  if (!rows.length) {
    $("#wrap-deposits").innerHTML = "<p>无数据</p>";
    return;
  }
  const cols = Object.keys(rows[0]);
  let html = "<table><thead><tr>";
  cols.forEach((c) => (html += "<th>" + esc(c) + "</th>"));
  html += "<th>操作</th></tr></thead><tbody>";
  for (const r of rows) {
    html += "<tr>";
    cols.forEach((c) => (html += "<td class='mono'>" + esc(r[c]) + "</td>"));
    html += `<td>
      <select class="dep-st" data-id="${r.id}">
        <option value="0" ${r.status === 0 ? "selected" : ""}>0待确认</option>
        <option value="1" ${r.status === 1 ? "selected" : ""}>1成功</option>
        <option value="2" ${r.status === 2 ? "selected" : ""}>2失败</option>
      </select>
      <input class="dep-hash" data-id="${r.id}" placeholder="tx_hash" value="${esc(r.tx_hash || "")}" style="width:12rem" />
      <button type="button" class="small primary btn-dep-save" data-id="${r.id}">保存</button>
    </td></tr>`;
  }
  html += "</tbody></table>";
  $("#wrap-deposits").innerHTML = html;
  $("#wrap-deposits").querySelectorAll(".btn-dep-save").forEach((b) => {
    b.addEventListener("click", async () => {
      const id = b.dataset.id;
      const status = parseInt(document.querySelector(`select.dep-st[data-id="${id}"]`).value, 10);
      const tx_hash = document.querySelector(`input.dep-hash[data-id="${id}"]`).value.trim() || null;
      try {
        await api("/api/admin/deposits/" + id, {
          method: "PATCH",
          body: JSON.stringify({ status, tx_hash }),
        });
        showStatus("充值 " + id + " 已更新", false);
        loadDeposits();
      } catch (e) {
        showStatus(e.message, true);
      }
    });
  });
}

$("#btnLoadDeposits").addEventListener("click", () => loadDeposits().catch((e) => showStatus(e.message, true)));

// ----- withdrawals -----
async function loadWithdrawals() {
  const rows = await api("/api/admin/withdrawals");
  if (!rows.length) {
    $("#wrap-withdrawals").innerHTML = "<p>无数据</p>";
    return;
  }
  const cols = Object.keys(rows[0]);
  let html = "<table><thead><tr>";
  cols.forEach((c) => (html += "<th>" + esc(c) + "</th>"));
  html += "<th>操作</th></tr></thead><tbody>";
  for (const r of rows) {
    html += "<tr>";
    cols.forEach((c) => (html += "<td class='mono'>" + esc(r[c]) + "</td>"));
    html += `<td>
      <select class="wd-st" data-id="${r.id}">
        <option value="0" ${r.status === 0 ? "selected" : ""}>0审核中</option>
        <option value="1" ${r.status === 1 ? "selected" : ""}>1处理中</option>
        <option value="2" ${r.status === 2 ? "selected" : ""}>2成功</option>
        <option value="3" ${r.status === 3 ? "selected" : ""}>3驳回</option>
      </select>
      <input class="wd-hash" data-id="${r.id}" placeholder="tx_hash" value="${esc(r.tx_hash || "")}" style="width:10rem" />
      <input class="wd-reason" data-id="${r.id}" placeholder="reject" value="${esc(r.reject_reason || "")}" style="width:8rem" />
      <input class="wd-rev" data-id="${r.id}" placeholder="reviewer" value="${r.reviewer_id != null ? esc(r.reviewer_id) : ""}" style="width:4rem" />
      <button type="button" class="small primary btn-wd-save" data-id="${r.id}">保存</button>
    </td></tr>`;
  }
  html += "</tbody></table>";
  $("#wrap-withdrawals").innerHTML = html;
  $("#wrap-withdrawals").querySelectorAll(".btn-wd-save").forEach((b) => {
    b.addEventListener("click", async () => {
      const id = b.dataset.id;
      const status = parseInt(document.querySelector(`select.wd-st[data-id="${id}"]`).value, 10);
      const tx_hash = document.querySelector(`input.wd-hash[data-id="${id}"]`).value.trim() || null;
      const reject_reason = document.querySelector(`input.wd-reason[data-id="${id}"]`).value.trim() || null;
      const rv = document.querySelector(`input.wd-rev[data-id="${id}"]`).value.trim();
      const reviewer_id = rv === "" ? null : parseInt(rv, 10);
      try {
        await api("/api/admin/withdrawals/" + id, {
          method: "PATCH",
          body: JSON.stringify({ status, tx_hash, reject_reason, reviewer_id }),
        });
        showStatus("提现 " + id + " 已更新", false);
        loadWithdrawals();
      } catch (e) {
        showStatus(e.message, true);
      }
    });
  });
}

$("#btnLoadWithdrawals").addEventListener("click", () => loadWithdrawals().catch((e) => showStatus(e.message, true)));

// init
(function () {
  const k = localStorage.getItem("ADMIN_API_KEY");
  if (k) $("#adminKey").value = k;
})();
