# Mohaffez App - Post-Launch Cost Analysis

## Executive Summary

This document outlines the estimated monthly operating costs for the Mohaffez app after launch, based on Firebase services and expected user growth scenarios.

---

## Firebase Services Breakdown

### 1. Firestore Database

**Pricing Model:**
- **Free Tier (Spark Plan):**
  - 50,000 reads/day
  - 20,000 writes/day
  - 20,000 deletes/day
  - 1 GB stored data

- **Pay-as-you-go (Blaze Plan):**
  - Reads: $0.06 per 100,000 documents
  - Writes: $0.18 per 100,000 documents
  - Deletes: $0.02 per 100,000 documents
  - Storage: $0.18 per GB/month
  - Network egress: $0.12 per GB

**Estimated Usage Scenarios:**

| Metric | Conservative (100 users) | Moderate (1,000 users) | High Growth (10,000 users) |
|--------|---------------------------|------------------------|----------------------------|
| Daily Active Users (DAU) | 30 | 300 | 3,000 |
| Avg reads per user/day | 50 | 50 | 50 |
| Avg writes per user/day | 10 | 10 | 10 |
| Monthly reads | 45,000 | 450,000 | 4,500,000 |
| Monthly writes | 9,000 | 90,000 | 900,000 |
| Data stored | 500 MB | 2 GB | 15 GB |
| **Firestore Cost** | **$0 (free tier)** | **~$5-10** | **~$80-120** |

---

### 2. Cloud Functions

**Pricing Model:**
- **Free Tier:**
  - 2 million invocations/month
  - 400,000 GB-seconds of compute time
  - 200,000 CPU-seconds of compute time
  - 5 GB of internet egress

- **Pay-as-you-go:**
  - Invocations: $0.40 per million
  - Compute time: $0.0000025 per GB-second
  - Networking: $0.12 per GB egress

**Estimated Usage:**

| Function | Invocations/Month | Cost |
|----------|-------------------|------|
| getMohaffezStudentCount | 10,000 | $0.004 |
| Session notifications | 5,000 | $0.002 |
| Payment processing | 1,000 | $0.0004 |
| Admin functions | 500 | $0.0002 |
| **Total Functions Cost** | | **~$0.01-5** |

---

### 3. Firebase Authentication

**Pricing Model:**
- **Free:** First 10,000 verifications/month
- **Pay-as-you-go:**
  - Phone auth: $0.01 per verification (after 10,000)
  - Email/Password: Free

**Estimated Cost:**
- Conservative: $0
- Moderate: $0
- High Growth: $0 (until 10,000+ new users/month)

---

### 4. Firebase Storage

**Pricing Model:**
- **Free Tier:**
  - 5 GB stored
  - 1 GB/day download
  - 50,000 upload operations/month
  
- **Pay-as-you-go:**
  - Storage: $0.026 per GB/month
  - Downloads: $0.12 per GB
  - Uploads: $0.05 per 10,000 operations

**Estimated Usage:**

| Scenario | Profile Photos | Documents | Total Cost |
|----------|----------------|-------------|------------|
| Conservative | 100 MB | 200 MB | $0 |
| Moderate | 1 GB | 2 GB | ~$0.08 |
| High Growth | 5 GB | 10 GB | ~$0.40 |

---

### 5. Firebase Hosting (Optional if using web)

**Pricing Model:**
- **Free:** 1 GB stored, 10 GB/month transfer
- **Pay-as-you-go:**
  - Storage: $0.026 per GB
  - Transfer: $0.15 per GB

**Estimated Cost:** $0 (mobile app doesn't use hosting)

---

## Third-Party Services

### 1. Paymob Payment Gateway
**Cost:** Transaction fees only (3-5% per transaction)
**No fixed monthly cost**

### 2. Google Maps API (if used for location)
**Pricing:**
- Free tier: $200 credit/month
- Geocoding: $5 per 1,000 requests

**Estimated Cost:** $0 (within free tier for initial scale)

### 3. SendGrid/Email Service (if used)
**Pricing:**
- Free: 100 emails/day
- Paid: Starting at $19.95/month

**Estimated Cost:** $0 initially

---

## Total Monthly Cost Projections

### Scenario 1: Conservative (First 3 months)
- **Users:** 100-200
- **Firebase:** $0 (free tier sufficient)
- **Third-party:** $0
- **Total:** **$0/month**

### Scenario 2: Moderate Growth (Months 4-12)
- **Users:** 1,000-5,000
- **Firebase Firestore:** $5-15
- **Firebase Functions:** $1-5
- **Firebase Storage:** $0-1
- **Third-party:** $0-10
- **Total:** **$6-31/month**

### Scenario 3: High Growth (Year 2+)
- **Users:** 10,000-50,000
- **Firebase Firestore:** $80-300
- **Firebase Functions:** $5-20
- **Firebase Storage:** $2-10
- **Third-party:** $20-50
- **Total:** **$107-380/month**

---

## Cost Optimization Recommendations

### 1. Firestore Optimization
- [ ] Implement query result caching
- [ ] Use pagination for large lists
- [ ] Denormalize data to reduce reads
- [ ] Use client-side caching with Riverpod/Provider
- [ ] Consider using Realtime Database for high-frequency updates (cheaper for small data)

### 2. Cloud Functions Optimization
- [ ] Use Cloud Firestore triggers efficiently
- [ ] Batch operations when possible
- [ ] Cache expensive computations
- [ ] Use minInstances only if needed for latency

### 3. Storage Optimization
- [ ] Compress profile images before upload
- [ ] Use Firebase Storage rules to prevent abuse
- [ ] Implement image resizing with Cloud Functions

### 4. Monitoring Setup
- [ ] Set up Firebase budget alerts at $10, $50, $100
- [ ] Monitor daily usage in Firebase Console
- [ ] Review monthly billing reports

---

## Break-Even Analysis

### Revenue Needed to Cover Costs

| Scenario | Monthly Cost | Avg Revenue/User | Users Needed |
|----------|--------------|------------------|--------------|
| Conservative | $0 | $5 | 0 (no cost) |
| Moderate | $20 | $5 | 4 paying users |
| High Growth | $200 | $5 | 40 paying users |

---

## Action Items

### Pre-Launch (Now)
1. [ ] Set up Firebase budget alerts
2. [ ] Configure Firebase Blaze plan with spending limits
3. [ ] Implement client-side caching in app
4. [ ] Test all Cloud Functions for efficiency
5. [ ] Set up monitoring dashboard

### Post-Launch (Month 1-3)
1. [ ] Monitor actual vs. projected usage weekly
2. [ ] Optimize high-cost queries
3. [ ] Review and adjust Firebase security rules
4. [ ] Document actual costs for future planning

### Growth Phase (Month 4+)
1. [ ] Consider Firebase cost optimization consultation
2. [ ] Evaluate if custom backend becomes cost-effective
3. [ ] Implement advanced caching strategies
4. [ ] Consider geographic distribution if users grow internationally

---

## Appendix: Firebase Blaze Plan Setup

1. Go to Firebase Console → Project Settings → Usage and Billing
2. Click "Modify Plan" → Select "Blaze Plan"
3. Set up budget alerts:
   - Alert 1: $10 (email notification)
   - Alert 2: $50 (email + Slack/Discord)
   - Alert 3: $100 (email + admin notification)
4. Set monthly budget limit (optional but recommended)
5. Add billing account and payment method

---

## Risk Factors

1. **DDoS or Abuse:** Could spike costs unexpectedly
   - Mitigation: Firebase Security Rules, App Check, rate limiting

2. **Inefficient Queries:** Poorly written queries can cause high read costs
   - Mitigation: Code review, query optimization, caching

3. **Rapid User Growth:** Costs can spike faster than revenue
   - Mitigation: Monitor daily, have optimization plan ready

4. **Data Storage Growth:** Old session data accumulates
   - Mitigation: Data retention policies, archiving old data

---

**Document Version:** 1.0  
**Last Updated:** April 2026  
**Next Review:** 1 month post-launch
