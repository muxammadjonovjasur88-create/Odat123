import React, { useState } from "react";

export function LandingPage() {
  const [lang, setLang] = useState("uz"); // 'uz' or 'en'

  const t = {
    uz: {
      appName: "ODAT",
      appSubtitle: "Foydali Odatlar va Fokus Ilovasi",
      navFeatures: "Imkoniyatlar",
      navDataSafety: "Ma'lumotlar Xavfsizligi",
      navPrivacy: "Maxfiylik Siyosati",
      navContact: "Bog'lanish",
      downloadApp: "Ilovani Yuklab Olish",
      heroBadge: "Rasmiy ODAT Mobil Ilovasi",
      heroTitle1: "Intizom, Fokus va",
      heroTitle2: "Foydali Odatlar Platformasi",
      heroDesc:
        "ODAT — foydalanuvchilarga kundalik foydali odatlarni shakllantirish, diqqatni jamlash (Fokus taymer), chalg'ituvchi omillarni kamaytirish va shaxsiy intizomni oshirishda yordam beruvchi zamonaviy mobil dasturdir.",
      featuresTitle: "Ilovaning Asosiy Funksiyalari",
      featuresSubtitle: "ODAT ilovasi sizga qanday yordam beradi?",
      feat1Title: "Kunlik Odatlar va Zanjir (Streaks)",
      feat1Desc: "Yangi odatlarni rejalashtiring, har kuni bajaring va doimiy intizom zanjirini mustahkamlang.",
      feat2Title: "Chuqur Fokus & Pomodoro",
      feat2Desc: "Ish va o'qish paytida diqqatni jamlash uchun maxsus taymer va chalg'ituvchi ilovalarni cheklovchi tizim.",
      feat3Title: "Rivojlanish Statistikasi",
      feat3Desc: "Haftalik va oylik tahlillar orqali o'z o'sishingizni vizual grafiklar yordamida kuzatib boring.",
      oauthSectionTitle: "Google Ma'lumotlaridan Foydalanish & Maxfiylik",
      oauthSectionSubtitle: "Google User Data & OAuth 2.0 Transparency",
      oauthDesc:
        "ODAT ilovasi foydalanuvchi xavfsizligini birinchi o'ringa qo'yadi. Biz Google hisobingizdan faqat quyidagi maqsadlarda foydalanamiz:",
      oauthPoint1Title: "Xavfsiz Kirish (Authentication)",
      oauthPoint1Desc:
        "Parol eslab qolish shart bo'lmagan holda ilovaga tez va xavfsiz kirishingizni ta'minlash.",
      oauthPoint2Title: "Odatlar Bulutli Sinxronizatsiyasi",
      oauthPoint2Desc:
        "Odatlaringiz va fokus tarixingiz qurilma o'zgarganda ham yo'qolmasligi uchun Firebase bulutida ishonchli saqlash.",
      oauthPoint3Title: "Hech Qanday Qo'shimcha Ruxsatsiz",
      oauthPoint3Desc:
        "Biz sizning elektron xatlaringiz, Google Drive fayllaringiz yoki kontaktlaringizga HECH QACHON kirmaymiz va so'ramaymiz.",
      contactTitle: "Dasturchi va Aloqa",
      contactDesc: "Savollar, takliflar yoki qo'llab-quvvatlash uchun biz bilan bog'laning:",
      rights: "Barcha huquqlar himoyalangan.",
    },
    en: {
      appName: "ODAT",
      appSubtitle: "Habit Tracker & Focus App",
      navFeatures: "Features",
      navDataSafety: "Data Safety",
      navPrivacy: "Privacy Policy",
      navContact: "Contact",
      downloadApp: "Download on Google Play",
      heroBadge: "Official ODAT Mobile App",
      heroTitle1: "Discipline, Focus &",
      heroTitle2: "Habit Building Platform",
      heroDesc:
        "ODAT is a modern mobile habit tracking and focus management app designed to help individuals build productive daily routines, enhance deep focus, and track long-term personal growth.",
      featuresTitle: "Core Application Functionality",
      featuresSubtitle: "Everything you need to master your daily routines",
      feat1Title: "Daily Habit Streaks",
      feat1Desc: "Create custom habits, check in daily, and maintain streaks to build unstoppable discipline.",
      feat2Title: "Deep Focus & Pomodoro",
      feat2Desc: "Customizable focus sessions and app blockers to eliminate distractions during work and study.",
      feat3Title: "Growth Analytics",
      feat3Desc: "Detailed visual charts and consistency scores to measure your progress over time.",
      oauthSectionTitle: "Google User Data Usage & Transparency",
      oauthSectionSubtitle: "OAuth 2.0 Compliance & Data Protection",
      oauthDesc:
        "ODAT complies strictly with Google API Services User Data Policy. We request Google OAuth access solely for:",
      oauthPoint1Title: "Secure Identity Verification",
      oauthPoint1Desc:
        "Allowing seamless and secure sign-in without requiring you to create or memorize separate passwords.",
      oauthPoint2Title: "Cloud Backup & Multi-Device Sync",
      oauthPoint2Desc:
        "Syncing your habit streaks, statistics, and focus logs safely across your devices via Google Firebase.",
      oauthPoint3Title: "Strict Zero-Access Guarantee",
      oauthPoint3Desc:
        "We NEVER request or access sensitive Google user data such as Gmail emails, Google Drive files, contacts, or calendar events.",
      contactTitle: "Developer & Support Contact",
      contactDesc: "For any inquiries, data deletion requests, or support, please reach out to us:",
      rights: "All rights reserved.",
    },
  };

  const cur = t[lang];

  return (
    <div className="min-h-screen bg-[#0d1117] text-gray-100 font-sans selection:bg-[#10b981] selection:text-black">
      {/* Navigation Header */}
      <header className="sticky top-0 z-50 backdrop-blur-md bg-[#0d1117]/85 border-b border-gray-800">
        <div className="max-w-6xl mx-auto px-6 h-20 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-2xl bg-gradient-to-tr from-[#10b981] to-[#047857] flex items-center justify-center shadow-lg shadow-[#10b981]/20">
              <span className="text-2xl">🌿</span>
            </div>
            <div>
              <span className="text-2xl font-black tracking-wider text-white">{cur.appName}</span>
              <span className="block text-[11px] font-bold text-[#10b981] tracking-widest uppercase">
                {cur.appSubtitle}
              </span>
            </div>
          </div>

          <nav className="hidden md:flex items-center gap-8 text-sm font-medium text-gray-400">
            <a href="#features" className="hover:text-white transition-colors">
              {cur.navFeatures}
            </a>
            <a href="#data-safety" className="hover:text-white transition-colors">
              {cur.navDataSafety}
            </a>
            <a href="/privacy.html" className="hover:text-white transition-colors">
              {cur.navPrivacy}
            </a>
            <a href="#contact" className="hover:text-white transition-colors">
              {cur.navContact}
            </a>
          </nav>

          <div className="flex items-center gap-4">
            {/* Language Switcher */}
            <button
              onClick={() => setLang(lang === "uz" ? "en" : "uz")}
              className="px-3 py-1.5 rounded-lg bg-gray-800 hover:bg-gray-700 text-xs font-bold text-gray-300 border border-gray-700 transition-colors"
            >
              {lang === "uz" ? "🇺🇿 UZ / EN" : "🇬🇧 EN / UZ"}
            </button>

            <a
              href="https://play.google.com/store/apps/details?id=com.company.flova"
              target="_blank"
              rel="noreferrer"
              className="px-4 py-2 bg-[#10b981] hover:bg-[#059669] text-black font-extrabold text-xs md:text-sm rounded-xl transition-all shadow-lg shadow-[#10b981]/25 flex items-center gap-2"
            >
              <span>📱</span>
              <span>Google Play</span>
            </a>
          </div>
        </div>
      </header>

      {/* Hero Section */}
      <section className="relative pt-16 pb-20 px-6 overflow-hidden">
        <div className="absolute top-1/4 left-1/2 -translate-x-1/2 w-[650px] h-[380px] bg-[#10b981]/15 blur-[130px] rounded-full pointer-events-none"></div>

        <div className="max-w-4xl mx-auto text-center relative z-10">
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-[#10b981]/10 border border-[#10b981]/30 text-[#10b981] text-xs font-black tracking-wider uppercase mb-8">
            <span className="w-2 h-2 rounded-full bg-[#10b981] animate-ping"></span>
            {cur.heroBadge}
          </div>

          <h1 className="text-4xl md:text-6xl font-black text-white tracking-tight leading-[1.15] mb-6">
            {cur.heroTitle1} <br />
            <span className="bg-gradient-to-r from-[#10b981] via-[#34d399] to-[#6ee7b7] bg-clip-text text-transparent">
              {cur.heroTitle2}
            </span>
          </h1>

          <p className="text-lg md:text-xl text-gray-300 max-w-2xl mx-auto leading-relaxed mb-10">
            {cur.heroDesc}
          </p>

          <div className="flex flex-wrap items-center justify-center gap-4">
            <a
              href="https://play.google.com/store/apps/details?id=com.company.flova"
              target="_blank"
              rel="noreferrer"
              className="px-8 py-4 bg-[#10b981] hover:bg-[#059669] text-black font-black text-base rounded-2xl shadow-xl shadow-[#10b981]/30 hover:scale-[1.02] active:scale-[0.98] transition-all flex items-center gap-3"
            >
              <span className="text-xl">🚀</span>
              <span>{cur.downloadApp}</span>
            </a>
            <a
              href="/privacy.html"
              className="px-8 py-4 bg-gray-800/80 hover:bg-gray-700/80 text-white font-bold text-base rounded-2xl border border-gray-700 hover:scale-[1.02] active:scale-[0.98] transition-all flex items-center gap-3"
            >
              <span className="text-xl">📄</span>
              <span>{cur.navPrivacy}</span>
            </a>
          </div>
        </div>
      </section>

      {/* Features Grid */}
      <section id="features" className="py-20 px-6 bg-[#0a0d12] border-t border-b border-gray-800/60">
        <div className="max-w-6xl mx-auto">
          <div className="text-center max-w-2xl mx-auto mb-16">
            <h2 className="text-xs font-black tracking-widest text-[#10b981] uppercase mb-3">
              {cur.featuresTitle}
            </h2>
            <h3 className="text-3xl font-black text-white">{cur.featuresSubtitle}</h3>
          </div>

          <div className="grid md:grid-cols-3 gap-8">
            <div className="p-8 rounded-3xl bg-[#131922] border border-gray-800 hover:border-[#10b981]/50 transition-all group">
              <div className="w-14 h-14 rounded-2xl bg-[#10b981]/10 border border-[#10b981]/20 flex items-center justify-center text-2xl mb-6 group-hover:scale-110 transition-transform">
                🎯
              </div>
              <h4 className="text-xl font-bold text-white mb-3">{cur.feat1Title}</h4>
              <p className="text-sm text-gray-400 leading-relaxed">{cur.feat1Desc}</p>
            </div>

            <div className="p-8 rounded-3xl bg-[#131922] border border-gray-800 hover:border-[#10b981]/50 transition-all group">
              <div className="w-14 h-14 rounded-2xl bg-[#10b981]/10 border border-[#10b981]/20 flex items-center justify-center text-2xl mb-6 group-hover:scale-110 transition-transform">
                ⏱️
              </div>
              <h4 className="text-xl font-bold text-white mb-3">{cur.feat2Title}</h4>
              <p className="text-sm text-gray-400 leading-relaxed">{cur.feat2Desc}</p>
            </div>

            <div className="p-8 rounded-3xl bg-[#131922] border border-gray-800 hover:border-[#10b981]/50 transition-all group">
              <div className="w-14 h-14 rounded-2xl bg-[#10b981]/10 border border-[#10b981]/20 flex items-center justify-center text-2xl mb-6 group-hover:scale-110 transition-transform">
                📊
              </div>
              <h4 className="text-xl font-bold text-white mb-3">{cur.feat3Title}</h4>
              <p className="text-sm text-gray-400 leading-relaxed">{cur.feat3Desc}</p>
            </div>
          </div>
        </div>
      </section>

      {/* Google User Data & OAuth Transparency Section (Google Cloud 13807376 Requirement) */}
      <section id="data-safety" className="py-20 px-6">
        <div className="max-w-5xl mx-auto rounded-3xl p-8 md:p-12 bg-gradient-to-br from-[#131922] via-[#0f141c] to-[#0a0d12] border border-gray-800">
          <div className="flex items-center gap-3 mb-4">
            <span className="text-3xl">🛡️</span>
            <div>
              <h3 className="text-2xl font-black text-white">{cur.oauthSectionTitle}</h3>
              <p className="text-xs font-bold text-[#10b981] tracking-wider uppercase">
                {cur.oauthSectionSubtitle}
              </p>
            </div>
          </div>

          <p className="text-sm text-gray-300 leading-relaxed mb-8 max-w-3xl">
            {cur.oauthDesc}
          </p>

          <div className="grid md:grid-cols-3 gap-6 mb-8">
            <div className="p-6 rounded-2xl bg-[#090c10] border border-gray-800/80">
              <div className="text-xl mb-2">🔑</div>
              <h4 className="text-base font-bold text-white mb-2">{cur.oauthPoint1Title}</h4>
              <p className="text-xs text-gray-400 leading-relaxed">{cur.oauthPoint1Desc}</p>
            </div>

            <div className="p-6 rounded-2xl bg-[#090c10] border border-gray-800/80">
              <div className="text-xl mb-2">☁️</div>
              <h4 className="text-base font-bold text-white mb-2">{cur.oauthPoint2Title}</h4>
              <p className="text-xs text-gray-400 leading-relaxed">{cur.oauthPoint2Desc}</p>
            </div>

            <div className="p-6 rounded-2xl bg-[#090c10] border border-gray-800/80">
              <div className="text-xl mb-2">🔒</div>
              <h4 className="text-base font-bold text-white mb-2">{cur.oauthPoint3Title}</h4>
              <p className="text-xs text-gray-400 leading-relaxed">{cur.oauthPoint3Desc}</p>
            </div>
          </div>

          <div className="flex flex-wrap items-center justify-between gap-4 pt-6 border-t border-gray-800/80 text-xs text-gray-400">
            <div className="flex items-center gap-4 text-[#10b981] font-semibold">
              <span>✓ OAuth 2.0 Compliant</span>
              <span>✓ Google API User Data Policy</span>
              <span>✓ Firebase Protected</span>
            </div>
            <a
              href="/privacy.html"
              className="text-white hover:text-[#10b981] font-bold underline transition-colors"
            >
              {cur.navPrivacy} →
            </a>
          </div>
        </div>
      </section>

      {/* Developer & Contact Section */}
      <section id="contact" className="py-16 px-6 bg-[#0a0d12] border-t border-gray-800/60">
        <div className="max-w-4xl mx-auto text-center">
          <h3 className="text-2xl font-black text-white mb-3">{cur.contactTitle}</h3>
          <p className="text-sm text-gray-400 mb-6">{cur.contactDesc}</p>

          <div className="inline-flex flex-wrap items-center justify-center gap-6 p-6 rounded-2xl bg-[#131922] border border-gray-800 text-sm">
            <div className="flex items-center gap-2">
              <span className="text-gray-400">📧 Email:</span>
              <a
                href="mailto:muxammadjonovjasur88@gmail.com"
                className="text-[#10b981] font-bold hover:underline"
              >
                muxammadjonovjasur88@gmail.com
              </a>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-gray-400">🌐 Domain:</span>
              <span className="text-white font-mono font-bold">flowa-4fca9.web.app</span>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-8 px-6 border-t border-gray-800/80 bg-[#090c10] text-gray-400 text-xs">
        <div className="max-w-6xl mx-auto flex flex-col md:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-2">
            <span className="text-lg">🌿</span>
            <span className="font-bold text-white">ODAT Mobile Application</span>
            <span>— © 2026 {cur.rights}</span>
          </div>

          <div className="flex items-center gap-6">
            <a href="/privacy.html" className="hover:text-white transition-colors">
              {cur.navPrivacy}
            </a>
            <a href="mailto:muxammadjonovjasur88@gmail.com" className="hover:text-white transition-colors">
              Support
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}
