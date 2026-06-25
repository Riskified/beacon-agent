# Riskified Beacon Integration — Claude Code Plugin

A Claude Code slash command that integrates the [Riskified](https://www.riskified.com) fraud-detection beacon into your storefront, with automated verification included.

> ⚠️ **Always run this in a staging or development environment first.**
> Review all changes before deploying to production. See [Disclaimer](#disclaimer) below.

---

## What it does

1. **Detects your framework** — Flask, PHP, Node, or React
2. **Finds your session variable** — scans for per-visit identifiers, recommends the best fit or generates a new one
3. **Injects the beacon snippet** — into shared layouts only (not page-by-page), removes any stale/broken prior beacon
4. **Verifies with 3 layers of checks:**
   - Layer 1: curl smoke checks on every instrumented page
   - Layer 2: generated test suite (pytest / PHPUnit / Jest)
   - Layer 3: generated Playwright behavioral tests (requires registered shop)

---

## Supported frameworks

This plugin has been tested and validated on the following stacks only:

| Framework | Version tested | Templates | Session mechanism |
|-----------|---------------|-----------|-------------------|
| Flask | 2.x / 3.x | Jinja2 (`templates/`) | `session[...]` |
| PHP | 7.4 – 8.3 | `.php` files | `$_SESSION[...]` |
| Node / Express | 18 LTS+ | EJS / Handlebars | `req.session.*` |
| React + Vite | React 18, Vite 5 | `index.html` + SPA | `sessionStorage` |

**Not supported:** Django, Rails, Laravel, Next.js SSR, Nuxt, Shopify Liquid, Magento, WooCommerce, or any framework not listed above. Running the plugin on an unsupported stack may produce incorrect results or no changes. If you need support for another framework, open an issue.

---

## Requirements

- [Claude Code](https://claude.ai/download) installed and authenticated
- Your storefront codebase accessible locally
- A Riskified merchant account with your shop domain registered

---

## Install

**From the marketplace** *(coming soon)*
Search for `Riskified Beacon` in the Claude Code integrations marketplace and click Install.
The acknowledgment prompt will appear the first time you run `/beacon-integrate`.

**Manual install** *(use until marketplace listing is live)*

Download and inspect the script before running — never pipe an unreviewed script directly to bash:

```bash
curl -fsSL https://raw.githubusercontent.com/riskified/beacon-agent/main/install.sh \
  -o /tmp/riskified-beacon-install.sh
# Review the script, then run it:
bash /tmp/riskified-beacon-install.sh
```

Expected SHA256 of `install.sh`: `a455886622c4d16f975befa7ee9dd7517357b918964a5e3b1aff2a73e83625dc`

Or copy the skill file directly:

```bash
mkdir -p ~/.claude/commands
curl -fsSL https://raw.githubusercontent.com/riskified/beacon-agent/main/beacon-integrate.md \
  -o ~/.claude/commands/beacon-integrate.md
```

> Regardless of how you install, the first time you run `/beacon-integrate` Claude will
> display a disclaimer and require you to type `AGREE` before any files are touched.

---

## Usage

Open Claude Code in your project directory and run:

```
/beacon-integrate /path/to/your/store www.yourshop.com
```

Claude will ask you two questions:
1. Which session variable to use (or whether to generate a new one)
2. Which pages to instrument

Review every file change Claude proposes before accepting. Claude Code will prompt for your approval on each write.

---

## After the run

- ✅ Beacon injected and verified across all instrumented pages
- 📄 `tests/` directory with smoke tests and Playwright tests
- 📋 `beacon_audit.json` with the full run record

**One manual step remains:** pass the session variable as `cart_token` when submitting orders to the [Riskified Order API](https://www.riskified.com/developer). This ties the beacon fingerprint to each order for fraud scoring.

---

## Disclaimer

This plugin is provided **as-is** for integration assistance only.

- **No warranty.** Riskified makes no guarantees that the generated code is correct, complete, or suitable for your specific environment.
- **Review before deploying.** Always test in a staging environment and have a developer review the changes before pushing to production. The plugin writes files to your codebase — you are responsible for what gets deployed.
- **Supported stacks only.** Results on unsupported frameworks are undefined. See [Supported frameworks](#supported-frameworks) above.
- **No liability.** Riskified is not liable for outages, data loss, or other issues arising from use of this plugin.

For production-critical integrations, engage Riskified's [Partner Engineering team](https://www.riskified.com/contact).

---

## Security

If you discover a security issue in this plugin, please report it privately to security@riskified.com rather than opening a public issue. See [SECURITY.md](SECURITY.md).
