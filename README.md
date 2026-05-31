# 🚗💦 CarWash Pro — Sales Tracker

A modern, mobile-first Car Wash Business Management System built for speed, simplicity, and employee gamification.

## 🌐 Live App
[**Open CarWash Pro →**](https://xbalzerianx.github.io/Carwash-x-Vulcanizing/)

---

## 🎯 Features

- **⚡ Quick Transaction Entry** — Record a car wash in under 10 seconds
- **🏆 Employee Rankings** — Daily & monthly leaderboards with podium view
- **💰 Auto Commission Calc** — Commission calculated automatically per employee rate
- **📊 Dashboard** — Real-time stats: cars washed, sales, commissions, top performer
- **📋 Transactions** — Full history with search, filter by day/week/month, delete
- **📈 Reports** — Daily/weekly/monthly/custom reports with CSV export
- **👨‍🔧 Employee Management** — Add/edit employees, set commission rates
- **🛁 Service Management** — Add/edit services and pricing
- **🎁 Reward Campaigns** — Monthly bonus campaigns for top performers

---

## 🎨 Design

- **Dark glassmorphism UI** with bright blue accents
- **Mobile-first** responsive design
- **Large tap targets** — optimized for staff use on phones/tablets
- Fun animations, trophy icons, podium ranking visuals

---

## 🗄️ Backend

Powered by [Base44](https://base44.com) — fully managed database & API.

**Entities:**
- `Employee` — staff profiles, commission rates, avatar colors
- `Service` — car wash service types and pricing
- `CarWash` — transaction records with services, amounts, commissions
- `RewardCampaign` — monthly reward bonus campaigns

---

## 🚀 Deployment

This app is deployed as a static single-page HTML file.

**To host on GitHub Pages:**
1. Go to **Settings → Pages**
2. Source: **Deploy from branch**
3. Branch: `main` / `root`
4. Your app will be live at `https://xbalzerianx.github.io/Carwash-x-Vulcanizing/`

---

## 📁 Project Structure

```
/
├── index.html          # Main app (React SPA — no build step needed)
├── carwash-app/
│   └── index.html      # App source
├── entities/           # Database schema definitions
│   ├── CarWash.json
│   ├── Employee.json
│   ├── Service.json
│   └── RewardCampaign.json
├── functions/          # Backend API functions (Deno)
│   ├── apiHandler.ts
│   └── generateReport.ts
└── README.md
```

---

## 🔧 Tech Stack

- **Frontend:** React 18 (CDN, no build step), vanilla CSS
- **Backend:** Deno + Base44 SDK
- **Database:** Base44 managed entities
- **Hosting:** GitHub Pages (static)

---

*Built with ❤️ for a car wash business in the Philippines 🇵🇭*
