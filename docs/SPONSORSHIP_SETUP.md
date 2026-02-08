# Sponsorship Platform Setup Guide

How to configure each donation/sponsorship platform for Flutter Skill.

---

## 1. GitHub Sponsors

**URL**: https://github.com/sponsors/ai-dashboad

### Setup Steps

1. Go to https://github.com/sponsors and click **"Get started"**
2. Fill in your profile:
   - Country/region for tax purposes
   - Bank account or Stripe Connect for payouts
3. Create sponsor tiers (suggested):
   | Tier | Price | Perks |
   |------|-------|-------|
   | Supporter | $3/month | Name in README sponsors list |
   | Backer | $10/month | Priority issue response |
   | Sponsor | $25/month | Logo in README + priority support |
   | Gold Sponsor | $100/month | Logo + dedicated support channel |
4. Add a `.github/FUNDING.yml` to the repo:
   ```yaml
   github: ai-dashboad
   buy_me_a_coffee: ai-dashboad
   ko_fi: flutter-skill
   ```
   This adds a **"Sponsor"** button on the GitHub repo page.

5. Submit for review (GitHub reviews within 1-2 business days)

### Payout
- Stripe Connect: direct to bank account
- Minimum payout: $0 (no minimum)
- Payout schedule: monthly

---

## 2. Buy Me a Coffee

**URL**: https://buymeacoffee.com/ai-dashboad

### Setup Steps

1. Go to https://www.buymeacoffee.com and sign up
2. Choose username: `ai-dashboad`
3. Complete profile:
   - Display name: **Flutter Skill**
   - Bio: "AI Agent Bridge for Flutter Apps - Open source MCP server for Flutter app automation"
   - Profile image: Flutter Skill logo
4. Set up payment receiving:
   - Connect **Stripe** (recommended) or **PayPal**
   - Stripe supports 135+ countries
5. Configure pricing:
   - Default coffee price: $5 (adjustable)
   - Enable **memberships** for recurring support (optional)
6. Customize your page:
   - Add a thank-you message
   - Add supporters wall widget

### Embed Badge in README
```markdown
[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=flat&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/ai-dashboad)
```

### Payout
- Stripe: instant to bank (1-7 days processing)
- PayPal: instant
- Platform fee: 5%

---

## 3. Ko-fi

**URL**: https://ko-fi.com/flutter-skill

### Setup Steps

1. Go to https://ko-fi.com and sign up
2. Choose username: `flutter-skill`
3. Complete profile:
   - Display name: **Flutter Skill**
   - Bio: "Open source MCP server for Flutter app automation"
   - Category: **Software & Technology**
4. Connect payment method:
   - **PayPal** (available everywhere) or **Stripe** (recommended)
5. Configure:
   - Ko-fi price: $5 per coffee (default)
   - Enable **Ko-fi Gold** ($6/month) for membership tiers (optional)
   - Enable **Shop** to sell digital goods (optional)
6. Customize page colors to match Flutter Skill branding

### Embed Badge in README
```markdown
[![Ko-fi](https://img.shields.io/badge/Ko--fi-F16061?style=flat&logo=ko-fi&logoColor=white)](https://ko-fi.com/flutter-skill)
```

### Payout
- PayPal/Stripe: instant (no holding period)
- Platform fee: **0%** (Ko-fi takes no cut on donations!)
- Ko-fi Gold: 5% fee on membership payments

---

## 4. WeChat Pay / Alipay (QR Codes)

### Setup Steps

1. **Generate QR codes**:
   - **WeChat Pay**: Open WeChat > Me > Services > Money > Receive Money > Save QR Code
   - **Alipay**: Open Alipay > Collect > Save QR Code

2. **Save QR images** to the repo:
   ```
   docs/assets/wechat-pay.png    (recommended: 500x500px)
   docs/assets/alipay.png        (recommended: 500x500px)
   ```

3. **Image optimization** (optional):
   ```bash
   # Resize to 500x500 if too large
   sips -Z 500 docs/assets/wechat-pay.png
   sips -Z 500 docs/assets/alipay.png
   ```

4. The README already references these images:
   ```html
   <img src="docs/assets/wechat-pay.png" width="200"/>
   <img src="docs/assets/alipay.png" width="200"/>
   ```

### Security Notes
- QR codes are **receive-only** (safe to publish publicly)
- They cannot be used to withdraw money from your account
- You can regenerate QR codes anytime if needed

---

## 5. Add FUNDING.yml to GitHub

Create `.github/FUNDING.yml`:

```yaml
github: ai-dashboad
buy_me_a_coffee: ai-dashboad
ko_fi: flutter-skill
custom:
  - https://raw.githubusercontent.com/ai-dashboad/flutter-skill/main/docs/assets/wechat-pay.png
```

This enables the **"Sponsor"** button on the GitHub repo page with links to all platforms.

---

## Quick Checklist

- [ ] GitHub Sponsors: Submit application at github.com/sponsors
- [ ] Buy Me a Coffee: Create page at buymeacoffee.com/ai-dashboad
- [ ] Ko-fi: Create page at ko-fi.com/flutter-skill
- [ ] WeChat Pay: Save receive QR to `docs/assets/wechat-pay.png`
- [ ] Alipay: Save receive QR to `docs/assets/alipay.png`
- [ ] Create `.github/FUNDING.yml`
- [ ] Verify README sponsorship section renders correctly
