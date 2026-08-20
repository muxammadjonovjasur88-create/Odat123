import React, { useState, useEffect } from "react";
import { 
  Sparkles, Play, Pause, RotateCcw, CheckCircle2, Flame, Trophy, 
  Shield, Smartphone, Compass, Clock, Zap, Target, Moon, Sun, ArrowRight,
  TrendingUp, Activity, Bell, Calendar, Cpu
} from "lucide-react";

export function ShowcaseTab() {
  const [activeMode, setActiveMode] = useState("ai_planner"); // "ai_planner", "pomodoro", "gamification", "blocker"
  const [aiPrompt, setAiPrompt] = useState("Bugun 2 soat Flutter kod yozish, 30 daqiqa yugurish va ingliz tili o'qish rejam bor");
  const [isGenerating, setIsGenerating] = useState(false);
  const [schedule, setSchedule] = useState([
    { id: 1, time: "09:00 - 10:30", title: "Flutter Architecture Refactor", tag: "Study / Code", color: "cyan", duration: "90 min", completed: true },
    { id: 2, time: "11:00 - 11:30", title: "Ingliz tili Speaking & Vocabulary", tag: "Learning", color: "gold", duration: "30 min", completed: false },
    { id: 3, time: "17:00 - 17:45", title: "Ochiq havoda 5km yugurish", tag: "Sport / Workout", color: "lime", duration: "45 min", completed: false },
    { id: 4, time: "21:00 - 21:30", title: "Kunlik hisobot & Meditatsiya", tag: "Zen Ritual", color: "jade", duration: "30 min", completed: false },
  ]);

  // Pomodoro State
  const [timerSeconds, setTimerSeconds] = useState(25 * 60);
  const [timerRunning, setTimerRunning] = useState(false);
  const [completedSessions, setCompletedSessions] = useState(3);

  // Gamification State
  const [userScore, setUserScore] = useState(1450);
  const [streakDays, setStreakDays] = useState(14);
  const [coins, setCoins] = useState(320);

  useEffect(() => {
    let interval = null;
    if (timerRunning && timerSeconds > 0) {
      interval = setInterval(() => {
        setTimerSeconds(s => s - 1);
      }, 1000);
    } else if (timerSeconds === 0) {
      setTimerRunning(false);
    }
    return () => clearInterval(interval);
  }, [timerRunning, timerSeconds]);

  const handleGenerateSchedule = () => {
    setIsGenerating(true);
    setTimeout(() => {
      setSchedule([
        { id: 1, time: "08:30 - 09:00", title: "Ertalabki Yoga & Nafas mashqi", tag: "Zen Ritual", color: "jade", duration: "30 min", completed: false },
        { id: 2, time: "09:30 - 11:30", title: "Flowa 2.0 Core Feature Coding", tag: "Study / Code", color: "cyan", duration: "120 min", completed: false },
        { id: 3, time: "14:00 - 15:00", title: "Ingliz tili Reading & Grammar", tag: "Learning", color: "gold", duration: "60 min", completed: false },
        { id: 4, time: "17:30 - 18:15", title: "Interval Yugurish & Territory Quest", tag: "Sport / Workout", color: "lime", duration: "45 min", completed: false },
      ]);
      setIsGenerating(false);
    }, 900);
  };

  const toggleTaskComplete = (id) => {
    setSchedule(schedule.map(item => {
      if (item.id === id) {
        const next = !item.completed;
        if (next) {
          setUserScore(prev => prev + 50);
          setCoins(prev => prev + 15);
        }
        return { ...item, completed: next };
      }
      return item;
    }));
  };

  const formatTimer = (total) => {
    const mins = Math.floor(total / 60);
    const secs = total % 60;
    return `${mins.toString().padStart(2, "0")}:${secs.toString().padStart(2, "0")}`;
  };

  return (
    <div className="space-y-6 pb-12">
      {/* Hero Showcase Banner */}
      <div className="relative overflow-hidden rounded-3xl bg-gradient-to-r from-zen-surface via-zen-muted to-zen-surface border border-zen-border p-6 md:p-8 shadow-glass-card">
        <div className="absolute top-0 right-0 -mt-8 -mr-8 w-64 h-64 rounded-full bg-zen-cyan/10 blur-3xl pointer-events-none"></div>
        <div className="absolute bottom-0 left-1/3 -mb-8 w-64 h-64 rounded-full bg-zen-lime/10 blur-3xl pointer-events-none"></div>
        
        <div className="relative z-10 flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
          <div>
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-zen-lime/10 border border-zen-lime/30 text-zen-lime text-xs font-bold uppercase tracking-wider mb-3">
              <Sparkles size={13} className="animate-spin" />
              Stitch 2026 Zen Kinetic Engine
            </div>
            <h2 className="text-2xl md:text-3xl font-extrabold text-zen-text tracking-tight">
              Flowa Zamonaviy Interaktiv Dizayn Studio
            </h2>
            <p className="text-zen-subtext text-sm md:text-base mt-1.5 max-w-xl">
              Figma ekranlari, Gemini AI jadval generatsiyasi, Pomodoro fokus sessiyalari va gamifikatsiyalangan mukofotlar tizimini jonli boshqaring.
            </p>
          </div>

          {/* Quick Stats Pill Group */}
          <div className="flex items-center gap-3 self-stretch md:self-auto overflow-x-auto">
            <div className="flex-1 md:flex-none p-3.5 rounded-2xl bg-zen-void/60 border border-zen-border/80 min-w-[110px] text-center">
              <div className="flex items-center justify-center gap-1 text-amber-400 text-xs font-medium">
                <Flame size={14} /> Streak
              </div>
              <p className="text-xl font-bold text-zen-text mt-1">{streakDays} Kun</p>
            </div>

            <div className="flex-1 md:flex-none p-3.5 rounded-2xl bg-zen-void/60 border border-zen-border/80 min-w-[110px] text-center">
              <div className="flex items-center justify-center gap-1 text-zen-lime text-xs font-medium">
                <Trophy size={14} /> Ballar
              </div>
              <p className="text-xl font-bold text-zen-lime mt-1">{userScore} XP</p>
            </div>

            <div className="flex-1 md:flex-none p-3.5 rounded-2xl bg-zen-void/60 border border-zen-border/80 min-w-[110px] text-center">
              <div className="flex items-center justify-center gap-1 text-zen-cyan text-xs font-medium">
                <Zap size={14} /> Tangalar
              </div>
              <p className="text-xl font-bold text-zen-cyan mt-1">{coins} 🪙</p>
            </div>
          </div>
        </div>

        {/* Mode Selector Tabs */}
        <div className="mt-6 flex flex-wrap gap-2 pt-4 border-t border-zen-border/60">
          {[
            { id: "ai_planner", name: "AI Zen Schedule", icon: Sparkles },
            { id: "pomodoro", name: "Deep Focus Pomodoro", icon: Clock },
            { id: "gamification", name: "Quests & Leaderboard", icon: Trophy },
            { id: "blocker", name: "App Blocker & Zen Shield", icon: Shield },
          ].map((mode) => {
            const Icon = mode.icon;
            const isSelected = activeMode === mode.id;
            return (
              <button
                key={mode.id}
                onClick={() => setActiveMode(mode.id)}
                className={`px-4 py-2.5 rounded-xl text-xs font-bold flex items-center gap-2 transition-all duration-200 ${
                  isSelected
                    ? "bg-zen-lime text-zen-void shadow-glow-lime scale-105"
                    : "bg-zen-surface hover:bg-zen-muted text-zen-subtext hover:text-zen-text border border-zen-border"
                }`}
              >
                <Icon size={15} />
                <span>{mode.name}</span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Main Interactive Workspace Area */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        
        {/* Left Interactive Control Panel (7 cols) */}
        <div className="lg:col-span-7 space-y-6">

          {/* MODE 1: AI ZEN SCHEDULE */}
          {activeMode === "ai_planner" && (
            <div className="glass-panel p-6 rounded-3xl space-y-5">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <div className="w-8 h-8 rounded-xl bg-zen-cyan/20 border border-zen-cyan/40 flex items-center justify-center text-zen-cyan">
                    <Sparkles size={16} />
                  </div>
                  <div>
                    <h3 className="font-bold text-zen-text text-base">Gemini Zen Schedule Generator</h3>
                    <p className="text-xs text-zen-subtext">Kunlik maqsadlaringizni yozing va AI mukammal vaqt taqsimoti tuzadi</p>
                  </div>
                </div>
              </div>

              <div className="relative">
                <textarea
                  value={aiPrompt}
                  onChange={(e) => setAiPrompt(e.target.value)}
                  rows={3}
                  className="w-full glass-input rounded-2xl p-4 text-sm text-zen-text placeholder-zen-subtext/60 focus:ring-2 focus:ring-zen-cyan"
                  placeholder="Masalan: Bugun 2 soat dasturlash, 1 soat sport va kitob o'qish..."
                />
                <button
                  onClick={handleGenerateSchedule}
                  disabled={isGenerating}
                  className="mt-3 w-full py-3 px-4 rounded-xl bg-gradient-to-r from-zen-cyan via-zen-jade to-zen-lime text-zen-void font-extrabold text-sm flex items-center justify-center gap-2 shadow-glow-lime hover:opacity-95 active:scale-98 transition disabled:opacity-50"
                >
                  <Cpu size={16} className={isGenerating ? "animate-spin" : ""} />
                  <span>{isGenerating ? "AI Jadval tuzmoqda..." : "Zen Jadvalni Generatsiya Qilish ✨"}</span>
                </button>
              </div>

              {/* Dynamic Task Timeline */}
              <div className="space-y-3 pt-2">
                <div className="flex items-center justify-between text-xs font-semibold text-zen-subtext">
                  <span>Generatsiya qilingan rejalar ({schedule.length})</span>
                  <span>Bajarilgan: {schedule.filter(s => s.completed).length}/{schedule.length}</span>
                </div>

                <div className="space-y-2.5">
                  {schedule.map((item) => (
                    <div
                      key={item.id}
                      onClick={() => toggleTaskComplete(item.id)}
                      className={`glass-panel-interactive p-4 rounded-2xl flex items-center justify-between cursor-pointer border ${
                        item.completed ? "border-zen-lime/40 bg-zen-lime/5" : "border-zen-border"
                      }`}
                    >
                      <div className="flex items-center gap-3.5">
                        <div className={`w-6 h-6 rounded-lg flex items-center justify-center transition-all ${
                          item.completed ? "bg-zen-lime text-zen-void" : "border-2 border-zen-border text-transparent"
                        }`}>
                          <CheckCircle2 size={16} />
                        </div>
                        <div>
                          <h4 className={`text-sm font-bold transition ${
                            item.completed ? "line-through text-zen-subtext" : "text-zen-text"
                          }`}>
                            {item.title}
                          </h4>
                          <div className="flex items-center gap-2 mt-1">
                            <span className="text-xs font-mono text-zen-cyan">{item.time}</span>
                            <span className="text-[10px] px-2 py-0.5 rounded-md bg-zen-surface text-zen-subtext border border-zen-border font-medium">
                              {item.tag}
                            </span>
                          </div>
                        </div>
                      </div>

                      <div className="text-right">
                        <span className="text-xs font-bold text-zen-lime font-mono">+{item.completed ? "50 XP" : item.duration}</span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* MODE 2: DEEP FOCUS POMODORO */}
          {activeMode === "pomodoro" && (
            <div className="glass-panel p-8 rounded-3xl text-center space-y-6">
              <div className="max-w-md mx-auto">
                <h3 className="text-xl font-bold text-zen-text">Zen Deep Focus Sessiyasi</h3>
                <p className="text-xs text-zen-subtext mt-1">Chalg'ituvchi barcha narsalardan uzilib, 25 daqiqa chuqur diqqatni jamlang</p>
              </div>

              {/* Glowing Circular Timer Mock */}
              <div className="relative w-56 h-56 mx-auto flex items-center justify-center">
                <div className={`absolute inset-0 rounded-full border-4 border-dashed transition-all duration-1000 ${
                  timerRunning ? "border-zen-lime animate-spin text-glow-lime shadow-glow-lime" : "border-zen-border"
                }`}></div>
                <div className="absolute inset-3 rounded-full bg-zen-surface/90 flex flex-col items-center justify-center">
                  <span className="text-4xl font-extrabold font-mono text-zen-lime tracking-wider">
                    {formatTimer(timerSeconds)}
                  </span>
                  <span className="text-xs font-medium text-zen-subtext mt-1 flex items-center gap-1">
                    <Zap size={12} className="text-zen-cyan" /> Pomodoro # {completedSessions + 1}
                  </span>
                </div>
              </div>

              {/* Timer Controls */}
              <div className="flex items-center justify-center gap-4">
                <button
                  onClick={() => setTimerRunning(!timerRunning)}
                  className={`px-8 py-3.5 rounded-2xl font-extrabold text-sm flex items-center gap-2 transition duration-200 active:scale-95 ${
                    timerRunning
                      ? "bg-rose-500/20 text-rose-400 border border-rose-500/40 hover:bg-rose-500/30"
                      : "bg-zen-lime text-zen-void shadow-glow-lime hover:bg-zen-lime/90"
                  }`}
                >
                  {timerRunning ? <Pause size={18} /> : <Play size={18} />}
                  <span>{timerRunning ? "Tanaffus" : "Fokusni Boshlash"}</span>
                </button>

                <button
                  onClick={() => {
                    setTimerRunning(false);
                    setTimerSeconds(25 * 60);
                  }}
                  className="p-3.5 rounded-2xl bg-zen-surface hover:bg-zen-muted border border-zen-border text-zen-subtext hover:text-zen-text transition"
                  title="Qayta o'rnatish"
                >
                  <RotateCcw size={18} />
                </button>
              </div>
            </div>
          )}

          {/* MODE 3: GAMIFICATION & LEADERBOARD */}
          {activeMode === "gamification" && (
            <div className="glass-panel p-6 rounded-3xl space-y-6">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="font-bold text-zen-text text-base">Growth Circle — Haftalik Leaderboard</h3>
                  <p className="text-xs text-zen-subtext">Dushanba kuni yangilanadigan do'stona musobaqa</p>
                </div>
                <span className="px-2.5 py-1 rounded-xl bg-amber-400/10 border border-amber-400/30 text-amber-400 font-bold text-xs">
                  🏆 Top 3
                </span>
              </div>

              <div className="space-y-2.5">
                {[
                  { rank: 1, name: "Jasur Muxammadjonov (Siz)", score: userScore, streak: `${streakDays} kun`, badge: "👑 Chempion", isMe: true },
                  { rank: 2, name: "Azizbek Rahimov", score: 1390, streak: "11 kun", badge: "⚡ Zen Master", isMe: false },
                  { rank: 3, name: "Madina Karimova", score: 1250, streak: "8 kun", badge: "🌿 Flow Seeker", isMe: false },
                  { rank: 4, name: "Bobur Aliyev", score: 980, streak: "5 kun", badge: "🚀 Explorer", isMe: false },
                ].map((user) => (
                  <div
                    key={user.rank}
                    className={`p-4 rounded-2xl flex items-center justify-between border transition ${
                      user.isMe ? "bg-zen-lime/10 border-zen-lime/50 shadow-glow-lime/20" : "bg-zen-surface/60 border-zen-border"
                    }`}
                  >
                    <div className="flex items-center gap-3.5">
                      <div className={`w-8 h-8 rounded-xl flex items-center justify-center font-extrabold text-sm ${
                        user.rank === 1 ? "bg-amber-400 text-zinc-950 shadow-md shadow-amber-400/30" :
                        user.rank === 2 ? "bg-slate-300 text-zinc-950" :
                        user.rank === 3 ? "bg-amber-700 text-white" : "bg-zen-muted text-zen-subtext"
                      }`}>
                        #{user.rank}
                      </div>
                      <div>
                        <h4 className="font-bold text-sm text-zen-text flex items-center gap-2">
                          {user.name}
                        </h4>
                        <p className="text-xs text-zen-subtext font-mono mt-0.5">{user.badge} • Streak: {user.streak}</p>
                      </div>
                    </div>

                    <div className="text-right font-mono font-bold text-zen-lime text-sm">
                      {user.score} XP
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* MODE 4: APP BLOCKER & ZEN SHIELD */}
          {activeMode === "blocker" && (
            <div className="glass-panel p-6 rounded-3xl space-y-5">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl bg-rose-500/20 border border-rose-500/40 flex items-center justify-center text-rose-400">
                  <Shield size={20} />
                </div>
                <div>
                  <h3 className="font-bold text-zen-text text-base">Starting Soon — Ilovalarni Bloklash</h3>
                  <p className="text-xs text-zen-subtext">Vazifa boshlanishiga 5 daqiqa qolganda chalg'ituvchi ilovalar avtomatik qulflanadi</p>
                </div>
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 pt-2">
                {[
                  { name: "Instagram", icon: "📸", blocked: true },
                  { name: "Telegram", icon: "✈️", blocked: true },
                  { name: "YouTube", icon: "▶️", blocked: true },
                  { name: "TikTok", icon: "🎵", blocked: true },
                ].map((app) => (
                  <div key={app.name} className="p-4 rounded-2xl bg-zen-surface border border-rose-500/30 text-center space-y-2 relative overflow-hidden">
                    <div className="absolute top-2 right-2 w-2 h-2 rounded-full bg-rose-500 animate-ping"></div>
                    <span className="text-2xl block">{app.icon}</span>
                    <p className="text-xs font-bold text-zen-text">{app.name}</p>
                    <span className="inline-block text-[10px] px-2 py-0.5 rounded-full bg-rose-500/10 text-rose-400 font-bold border border-rose-500/20">
                      BLOKLANGAN
                    </span>
                  </div>
                ))}
              </div>

              <div className="p-4 rounded-2xl bg-zen-cyan/5 border border-zen-cyan/30 flex items-center gap-3 text-xs text-zen-subtext">
                <Zap size={18} className="text-zen-cyan shrink-0" />
                <span>Android Kotlin Accessibility Service va MethodChannel orqali to'liq avtonom ishlaydi.</span>
              </div>
            </div>
          )}

        </div>

        {/* Right Mobile App Live Mockup Simulator (5 cols) */}
        <div className="lg:col-span-5">
          <div className="sticky top-28">
            <div className="text-center mb-2">
              <span className="text-xs font-bold uppercase tracking-wider text-zen-subtext font-mono flex items-center justify-center gap-1.5">
                <Smartphone size={13} className="text-zen-cyan" /> Flowa Android Mockup
              </span>
            </div>

            {/* Mobile Device Frame */}
            <div className="mx-auto w-[310px] h-[630px] rounded-[48px] bg-black p-3 border-4 border-zen-border/90 shadow-2xl shadow-zen-cyan/10 relative overflow-hidden flex flex-col justify-between">
              
              {/* Dynamic Island / Speaker */}
              <div className="absolute top-4 left-1/2 -translate-x-1/2 w-24 h-4 bg-zinc-900 rounded-full z-30 flex items-center justify-center">
                <div className="w-2.5 h-2.5 rounded-full bg-zinc-800"></div>
              </div>

              {/* App Screen Content */}
              <div className="flex-1 bg-zen-void rounded-[36px] overflow-hidden p-4 pt-8 flex flex-col justify-between relative">
                
                {/* Status Bar */}
                <div className="flex items-center justify-between text-[11px] text-zen-subtext px-1 mb-2 font-mono">
                  <span>09:41</span>
                  <div className="flex items-center gap-1">
                    <Activity size={12} className="text-zen-lime" />
                    <span>100%</span>
                  </div>
                </div>

                {/* App Screen Dynamic Body based on Active Mode */}
                <div className="flex-1 overflow-y-auto space-y-3 pr-0.5">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-[10px] text-zen-subtext font-semibold uppercase tracking-wider">Bugungi Rejangiz</p>
                      <h4 className="text-sm font-extrabold text-zen-text">Salom, Jasur 🌿</h4>
                    </div>
                    <div className="w-8 h-8 rounded-full bg-zen-surface border border-zen-lime/40 flex items-center justify-center text-xs font-bold text-zen-lime">
                      14🔥
                    </div>
                  </div>

                  {/* Daily Quests Widget Mock */}
                  <div className="p-3 rounded-2xl bg-gradient-to-r from-zen-surface to-zen-muted border border-zen-border">
                    <div className="flex items-center justify-between text-[11px] font-bold text-zen-text mb-1.5">
                      <span className="flex items-center gap-1"><Target size={11} className="text-zen-cyan" /> Kunlik Kvest</span>
                      <span className="text-zen-lime font-mono">2/3</span>
                    </div>
                    <div className="w-full h-1.5 rounded-full bg-zen-void overflow-hidden">
                      <div className="h-full bg-gradient-to-r from-zen-cyan to-zen-lime w-2/3 rounded-full"></div>
                    </div>
                  </div>

                  {/* Next Focus Task Card */}
                  <div className="p-3.5 rounded-2xl bg-zen-lime/10 border border-zen-lime/40 relative overflow-hidden">
                    <span className="text-[9px] font-bold text-zen-lime uppercase px-1.5 py-0.5 rounded bg-zen-lime/20 inline-block mb-1">
                      Hozirgi Fokus
                    </span>
                    <p className="text-xs font-bold text-zen-text">Flutter Architecture Refactor</p>
                    <p className="text-[10px] text-zen-subtext mt-0.5">09:00 - 10:30 • 90 daqiqa qoldi</p>
                    
                    <button className="mt-2.5 w-full py-1.5 rounded-xl bg-zen-lime text-zen-void font-extrabold text-[11px] flex items-center justify-center gap-1 shadow-glow-lime">
                      <Play size={10} /> Focus Boshlash
                    </button>
                  </div>

                  {/* Mini Schedule List */}
                  <div className="space-y-1.5 pt-1">
                    <p className="text-[10px] font-bold text-zen-subtext uppercase tracking-wider">Keyingi Maqsadlar</p>
                    {schedule.slice(1, 3).map(item => (
                      <div key={item.id} className="p-2.5 rounded-xl bg-zen-surface/70 border border-zen-border flex items-center justify-between text-[11px]">
                        <div className="truncate pr-2">
                          <p className="font-semibold text-zen-text truncate">{item.title}</p>
                          <p className="text-[9px] text-zen-cyan font-mono">{item.time}</p>
                        </div>
                        <span className="text-[9px] font-bold text-zen-subtext shrink-0">{item.duration}</span>
                      </div>
                    ))}
                  </div>

                </div>

                {/* Mobile Bottom Navigation Bar */}
                <div className="mt-2 py-2 px-3 bg-zen-surface/90 rounded-2xl border border-zen-border flex items-center justify-between text-zen-subtext">
                  <Calendar size={16} className="text-zen-lime" />
                  <Sparkles size={16} />
                  <Clock size={16} />
                  <Trophy size={16} />
                </div>

              </div>

              {/* Bottom Home Indicator */}
              <div className="w-28 h-1 bg-zinc-700 rounded-full mx-auto mt-2"></div>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}
