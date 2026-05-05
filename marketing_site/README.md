# Al-Mohaffez Marketing Site

Marketing website for Al-Mohaffez (المحفظ) - Quran tutoring platform.

## Deployment Instructions

### Prerequisites

1. Install Firebase CLI:
```bash
npm install -g firebase-tools
```

2. Login to Firebase:
```bash
firebase login
```

### Initialize Hosting (First Time Only)

From repo root:
```bash
firebase init hosting
```
- Select existing project
- Set public directory to: `marketing_site`
- Configure as single-page app: **No**
- Set up GitHub deploys: Optional

### Deploy to Production

```bash
firebase deploy --only hosting:marketing
```

Or if using default hosting:
```bash
firebase deploy --only hosting
```

### Deploy Both App and Marketing

```bash
firebase deploy --only hosting:app,hosting:marketing
```

## File Structure

```
marketing_site/
├── index.html          # Main landing page
├── robots.txt          # SEO robots
├── sitemap.xml         # SEO sitemap
├── assets/
│   ├── logo.svg        # Brand logo
│   ├── hero-mockup.png # Hero image placeholder
│   └── icons/          # Favicon set
└── README.md           # This file
```

## Development

Open `index.html` directly in browser for local testing.

## Performance Checklist

- [ ] Total page weight < 200KB (excluding hero image)
- [ ] Lighthouse Performance ≥ 95
- [ ] Lighthouse Accessibility ≥ 95
- [ ] Lighthouse Best Practices ≥ 95
- [ ] Lighthouse SEO = 100
