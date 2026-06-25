# Riskified Beacon Integration

Inject the Riskified beacon snippet into a merchant site, let the developer make key
decisions, and produce three tiers of automated validation.

The agent's job is injection and verification only. Do NOT add rskx_ready listeners or
beacon-ready endpoints to the merchant's code.

## Arguments

$ARGUMENTS: `<site-dir> <shop-domain>`
Example: `/beacon-integrate /path/to/my_store www.myshop.com`

Parse the first token as SITE_DIR and the second as SHOP_DOMAIN.
If either is missing, ask the user before proceeding.

Validate SHOP_DOMAIN before doing anything else:
- Must match the pattern `^[a-zA-Z0-9][a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`
- Must not contain spaces, quotes (`'` `"`), semicolons, or other shell/JS special characters

If SHOP_DOMAIN fails validation, stop immediately and print:
```
✗ Invalid shop domain: "<value>"
  A shop domain must be a plain hostname such as www.yourshop.com
  Re-run with a valid domain.
```

---

## Step 0 — Acknowledgment check

Before doing anything else, run:

```bash
ls ~/.riskified-beacon-agreed 2>/dev/null
```

**If the file does not exist**, display the following to the developer and wait
for their response — do not proceed until they reply:

```
Riskified Beacon Integration
─────────────────────────────────────────────────
This plugin writes code into your storefront codebase.
Before continuing, confirm you understand the following:

  1. Always run this in a staging or development environment first.
  2. Review every file change before deploying to production.
  3. Supported frameworks only: Flask, PHP, Node/Express, React + Vite.
     Results on other stacks are undefined.
  4. Riskified provides this plugin as-is with no warranty.
     Riskified is not liable for production issues arising from its use.

Full terms: https://github.com/riskified/beacon-agent#disclaimer

Type AGREE to accept and continue, or anything else to cancel.
```

- If the developer types **AGREE** (exact match, case-sensitive): run
  `touch ~/.riskified-beacon-agreed` then proceed to Step 1.
- If the developer types anything else: stop immediately, do not modify
  any files, and print: `Installation cancelled. Re-run /beacon-integrate
  when you're ready to accept the terms.`

**If the file already exists**: skip this step silently and proceed to Step 1.

---

## Step 1 — Detect site type

Read SITE_DIR and identify one of:

| SITE_TYPE | Detection signal |
|-----------|-----------------|
| `flask`   | `app.py` or `wsgi.py` imports `flask`; `templates/` directory present |
| `php`     | `.php` files present |
| `node`    | `server.js` or `index.js`; no Python/PHP; no React dep |
| `react`   | `package.json` contains `"react"` dependency |

Record SITE_TYPE, entry-point file, template directory, PORT (defaults: flask=5000, php=8080, node=5001, react=3000).

If the site type cannot be determined, ask the user.

---

## Step 2 — Session ID discovery

Scan the codebase for any existing session or identifier variable that could serve as the beacon session_id.
Look for patterns like:
- Flask: `session['...']`, `session.get('...')`, `g.user_id`, request-scoped UUID assignments
- PHP: `$_SESSION['...']`, `session_id()`, custom token fields
- Node: `req.session.*`, cookie values, JWT sub fields
- React: `sessionStorage.*`, `localStorage.*` UUID keys

For each candidate found, record: variable name, where it is set, what it contains (UUID, DB id, etc.), and which files use it.

Present the findings to the developer and ask which to use. Call ask_developer EXACTLY ONCE
for this decision. Options:
  A) Use an existing candidate
  B) Generate a new `rskx_session_id` variable

Wait for the developer's response before continuing.

If the developer chooses B, add the session_id generation to the server entry point:
- Flask: `session['rskx_session_id'] = str(uuid.uuid4())` in a `@before_request` (if not set)
- PHP: `$_SESSION['rskx_session_id'] = bin2hex(random_bytes(16))` after `session_start()`
- Node: generate in the GET / handler, set cookie
- React: `sessionStorage.getItem('rskx_sid') || crypto.randomUUID()`

SESSION_ID_EXPR per framework:
- Flask: `{{ session['<VAR>'] }}`
- PHP: `<?= htmlspecialchars($_SESSION['<VAR>'], ENT_QUOTES) ?>`
- Node: `{{<VAR>}}` (server replaces at render time)
- React: client-side from sessionStorage key `<VAR>`

---

## Step 3 — Page selection

List every template file in the templates directory (or .php files for PHP sites).
Mark each with its likely role based on filename and content.

Recommended for injection: homepage, product listing, product detail, cart, login, signup, account.
Not recommended: admin, blog, legal, error pages.

Present the list and ask the developer to confirm or customise it. Call ask_developer EXACTLY
ONCE for this decision. Wait for confirmation before proceeding.

---

## Step 4 — Inject the beacon snippet

**Layout analysis — determine injection points before writing anything.**

Scan all page files for include/extends patterns to build a header→pages map:
- Flask/Node: look for `{% extends 'base.html' %}` → single injection into the base template
- PHP: look for `require_once` / `include` of header files — may find multiple shared headers
  (e.g. `header_public.php` for browse pages, `header_checkout.php` for cart/checkout).
  Also check for standalone pages with their own `<head>`.

Present the injection plan before writing:

```
Layout Analysis
===============
  includes/header_public.php   → /, /shop.php, /product.php, /login.php
  includes/header_checkout.php → /cart.php, /account.php
  checkout.php                 → STANDALONE (own <head>, no shared include)

Injection plan: 3 files
```

Also check every page file for existing stale/broken beacon snippets (wrong shop domain,
placeholder session_id). If found, remove them before injecting and note in the audit log.

### Flask / Node templates

Insert immediately after the opening `<head>` tag (or replace `<!-- BEACON_SNIPPET -->` if present).
If a shared base template exists, inject ONCE into the base template only.

```html
<script type="text/javascript">
//<!CDATA[
(function() {
  function riskifiedBeaconLoad() {
    var store_domain = 'SHOP_DOMAIN';
    var session_id = 'SESSION_ID_EXPR';
    var url = ('https:' == document.location.protocol ? 'https://' : 'http://')
      + "beacon.riskified.com?shop=" + store_domain + "&sid=" + encodeURIComponent(session_id);
    var s = document.createElement('script');
    s.type = 'text/javascript';
    s.async = true;
    s.src = url;
    var x = document.getElementsByTagName('script')[0];
    x.parentNode.insertBefore(s, x);
  }
  if (window.attachEvent)
    window.attachEvent('onload', riskifiedBeaconLoad)
  else
    window.addEventListener('load', riskifiedBeaconLoad, false);
})();
//]]>
</script>
```

### PHP files

Same snippet, with PHP expression for session_id. Insert after the opening `<head>` tag.

### React (index.html)

```html
<script>
(function () {
  var KEY = 'SESSION_VAR';
  var sid = sessionStorage.getItem(KEY);
  if (!sid) {
    sid = (typeof crypto !== 'undefined' && crypto.randomUUID)
      ? crypto.randomUUID()
      : Math.random().toString(36).slice(2) + Date.now().toString(36);
    sessionStorage.setItem(KEY, sid);
  }
  function riskifiedBeaconLoad() {
    var store_domain = 'SHOP_DOMAIN';
    var url = ('https:' == document.location.protocol ? 'https://' : 'http://')
      + 'beacon.riskified.com?shop=' + store_domain + '&sid=' + encodeURIComponent(sid);
    var s = document.createElement('script');
    s.type = 'text/javascript';
    s.async = true;
    s.src = url;
    var x = document.getElementsByTagName('script')[0];
    x.parentNode.insertBefore(s, x);
  }
  if (window.attachEvent)
    window.attachEvent('onload', riskifiedBeaconLoad);
  else
    window.addEventListener('load', riskifiedBeaconLoad, false);
})();
</script>
```

After each file write, verify:
- `store_domain` is set to the actual shop domain, no angle-bracket placeholders
- SESSION_ID_EXPR is present and not a placeholder
- `beacon.riskified.com` appears exactly once per template (or once in base.html)

---

## Step 5 — Start the server

### Flask
```bash
cd <SITE_DIR> && pip3 install -q -r requirements.txt && python3 app.py > /tmp/beacon_server.log 2>&1 &
sleep 2 && curl -s -o /dev/null -w "%{http_code}" http://localhost:<PORT>/
```

### PHP
```bash
cd <SITE_DIR> && php -S localhost:<PORT> > /tmp/beacon_server.log 2>&1 &
sleep 1 && curl -s -o /dev/null -w "%{http_code}" http://localhost:<PORT>/
```

### Node
```bash
cd <SITE_DIR> && npm install -s && node server.js > /tmp/beacon_server.log 2>&1 &
sleep 2 && curl -s -o /dev/null -w "%{http_code}" http://localhost:<PORT>/
```

### React
```bash
cd <SITE_DIR> && npm install -s
node server.js > /tmp/beacon_api.log 2>&1 &
npx vite --port <PORT> > /tmp/beacon_vite.log 2>&1 &
sleep 4 && curl -s -o /dev/null -w "%{http_code}" http://localhost:<PORT>/
```

If the port is already in use, skip startup.

---

## Step 6 — Layer 1: curl smoke checks

For each page in PAGES, fetch it and run all checks.
Use a fresh cookie jar per session to get consistent session_id values within a session.

```bash
curl -s -c /tmp/bc_session.txt http://localhost:<PORT>/<PATH> > /tmp/beacon_<PAGE>.html
```

Per-page checks:

| Check | Pass condition |
|---|---|
| HTTP 200 | curl exit code 0, status 200 |
| Snippet present | `grep -c "beacon.riskified.com"` ≥ 1 |
| Correct shop | `grep "store_domain"` contains the shop domain |
| `&sid=` wired | `grep "&sid="` matches |
| No placeholder | `grep -iE "SESSION ID GOES HERE\|REPLACE_ME"` = 0 |
| session_id live | value on `session_id =` line is non-empty, ≤ 100 chars |
| No legacy snippet | only one occurrence of `beacon.riskified.com` per page |

Per-visit uniqueness (non-React): fetch with a second fresh cookie jar, confirm session_id differs.

Report per-page results inline. Stop and report failures before moving to Layer 2.

---

## Step 7 — Layer 2: generate smoke tests

### Flask → tests/test_beacon_smoke.py

```python
"""Beacon integration smoke tests — generated by beacon-integrate."""
import os, re, pytest, requests

BASE_URL = os.environ.get("BEACON_TEST_URL", "http://localhost:<PORT>")
SHOP     = os.environ.get("BEACON_TEST_SHOP", "<SHOP>")
PAGES    = [<comma-separated quoted page paths>]

@pytest.mark.parametrize("path", PAGES)
def test_snippet_present(path):
    r = requests.get(BASE_URL + path)
    assert r.status_code == 200
    assert "beacon.riskified.com" in r.text

@pytest.mark.parametrize("path", PAGES)
def test_store_domain(path):
    r = requests.get(BASE_URL + path)
    assert f"store_domain = '{SHOP}'" in r.text

@pytest.mark.parametrize("path", PAGES)
def test_sid_wired(path):
    r = requests.get(BASE_URL + path)
    assert "&sid=" in r.text

@pytest.mark.parametrize("path", PAGES)
def test_no_placeholder(path):
    r = requests.get(BASE_URL + path)
    assert "SESSION ID GOES HERE" not in r.text.upper()

@pytest.mark.parametrize("path", PAGES)
def test_session_id_live(path):
    r = requests.get(BASE_URL + path)
    match = re.search(r"session_id\s*=\s*'([^']+)'", r.text)
    assert match, "session_id assignment not found in rendered HTML"
    assert 0 < len(match.group(1)) <= 100

def test_session_id_per_visit_unique():
    r1 = requests.get(BASE_URL + "/")
    r2 = requests.get(BASE_URL + "/")
    m1 = re.search(r"session_id\s*=\s*'([^']+)'", r1.text)
    m2 = re.search(r"session_id\s*=\s*'([^']+)'", r2.text)
    assert m1 and m2
    assert m1.group(1) != m2.group(1), "session_id is not per-visit unique"

def test_beacon_endpoint():
    r = requests.get(f"https://beacon.riskified.com?shop={SHOP}")
    if r.status_code == 200:
        assert len(r.content) > 5000
    else:
        pytest.skip(f"Shop not registered (HTTP {r.status_code})")
```

### PHP → tests/BeaconSmokeTest.php (PHPUnit)
### Node/React → tests/beacon.smoke.test.js (Jest)

Generate equivalent assertions in the matching framework.

---

## Step 8 — Layer 3: generate Playwright behavioral tests

Write a Playwright test file covering:

1. Page loads → beacon fires POST to `c.riskified.com/v2/client_infos` → localStorage `rCookie` set
2. `riskified_cookie` in client_infos body matches `rCookie` value
3. For each page in PAGES: beacon fires and `rCookie` is stable
4. `rCookie` stable across reload; page_id rotates
5. Rendered HTML contains `store_domain = '<SHOP>'`

File: `tests/test_beacon_playwright.py` (Python) or `tests/beacon.playwright.test.ts` (TypeScript for Node/React).

Note in the file: Playwright tests require the shop to be registered with Riskified to pass.
They will fail against an unregistered shop — this is expected and is not a code defect.

---

## Step 9 — Final report

Print a summary:

```
Beacon Integration — Final Report
==================================
Site type      : <SITE_TYPE>
Shop           : <SHOP_DOMAIN>
Session var    : <SESSION_VAR> (<existing | generated>)
Pages injected : <N> pages
Server URL     : http://localhost:<PORT>/

LAYER 1 — curl smoke checks
----------------------------
  <page>   PASS / FAIL
  ...
  session_id per-visit unique   PASS / FAIL

LAYER 2 — smoke test file
  Written to : tests/test_beacon_smoke.py (or equivalent)
  Run with   : pytest tests/test_beacon_smoke.py -v

LAYER 3 — Playwright test file
  Written to : tests/test_beacon_playwright.py (or equivalent)
  Note       : requires registered shop to pass

BEACON ENDPOINT
  https://beacon.riskified.com?shop=<SHOP>   PASS / UNREGISTERED

AGENT SCOPE — DONE
✓ Beacon snippet injected into <N> file(s)
✓ Session var: <SESSION_VAR> → &sid= on every instrumented page
✓ Legacy beacon removed from: <file>  [if applicable]

MERCHANT TODO
→ Pass <SESSION_VAR> as cart_token when submitting orders to Riskified's Order API
→ Register shop with Riskified (required for beacon + Layer 3 tests)
→ Run Layer 2 smoke tests now — they work without a registered shop
→ Run Layer 3 Playwright tests after shop registration
→ Add CSP directives if needed: beacon.riskified.com, c.riskified.com, img.riskified.com
```

---

## Step 10 — Write audit log

Write `<SITE_DIR>/beacon_audit.json`. If it exists, append to the `runs` array.

```json
{
  "runs": [{
    "timestamp": "<ISO-8601>",
    "site_dir": "<SITE_DIR>",
    "site_type": "<SITE_TYPE>",
    "shop": "<SHOP_DOMAIN>",
    "session_var": {
      "name": "<SESSION_VAR>",
      "origin": "existing | generated",
      "candidates_found": []
    },
    "injection_files": ["<path1>", "<path2>"],
    "legacy_beacon_removed": "<file: description> | null",
    "pages_instrumented": [],
    "layer1": { "/": "PASS | FAIL" },
    "session_id_unique": "PASS | FAIL | N/A",
    "layer2_file": "<relative path>",
    "layer3_file": "<relative path>",
    "beacon_endpoint": "PASS | UNREGISTERED | FAIL",
    "all_pass": true
  }]
}
```
