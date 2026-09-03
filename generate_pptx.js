const pptxgen = require('D:\\\\tmp\\\\pptx_gen\\\\node_modules\\\\pptxgenjs');

// 1. Create a new Presentation
let pres = new pptxgen();

// Set slide dimensions (16:9)
pres.layout = 'LAYOUT_16x9';
pres.theme = { headFontFace: "Arial", bodyFontFace: "Arial" };

// Master slides (Background dark, text white/cyan)
pres.defineSlideMaster({
    title: 'MASTER_SLIDE',
    background: { color: '04050D' },
    objects: [
        { rect: { x: 0, y: 0, w: '100%', h: 0.5, fill: { color: '4AADDC' } } },
        { text: { text: 'ODAT - Gamified Habits', options: { x: '80%', y: 0.1, w: 2, h: 0.3, color: 'FFFFFF', fontSize: 10, align: 'right' } } }
    ]
});

// Helper function to create slides
function createSlide(title, contentBullets, color = 'FFFFFF') {
    let slide = pres.addSlide({ masterName: 'MASTER_SLIDE' });
    // Title
    slide.addText(title, {
        x: 0.5, y: 0.8, w: '90%', h: 1,
        fontSize: 36,
        color: '4AADDC',
        bold: true
    });
    // Content
    if (contentBullets && contentBullets.length > 0) {
        slide.addText(contentBullets, {
            x: 0.5, y: 2, w: '90%', h: '60%',
            fontSize: 22,
            color: color,
            bullet: true,
            lineSpacing: 35
        });
    }
    return slide;
}

// SLIDE 1: Cover
let slide1 = pres.addSlide({ masterName: 'MASTER_SLIDE' });
slide1.addText('ODAT', { x: 0.5, y: 2, w: '90%', h: 1.5, fontSize: 60, color: '4AADDC', bold: true, align: 'center' });
slide1.addText('Yaxshi odatlarni o\'yinga aylantiramiz.', { x: 0.5, y: 3.5, w: '90%', h: 1, fontSize: 24, color: 'FFFFFF', align: 'center' });
slide1.addText('Bolalar va o\'smirlar uchun AI qatnashuvidagi gamified intizom ilovasi', { x: 0.5, y: 4, w: '90%', h: 1, fontSize: 18, color: '6B25CC', align: 'center' });

// SLIDE 2: Problem
createSlide('MUAMMO: QARAMLIK VA DANGASALIK', [
    { text: 'Yoshlarning aksariyati ijtimoiy tarmoqlar (TikTok, Instagram) va mobil o\'yinlarga kuchli qaram.' },
    { text: 'Jismoniy faollikning pastligi va kitob mutolaasining keskin tushib ketishi.' },
    { text: 'Ota-onalar farzandlari bilan ekran vaqti bo\'yicha doimiy tushunmovchilik va stress holatida.' },
    { text: 'Bozorda qiziqarli (o\'yin orqali) va ta\'sirchan nazorat mexanizmi yetishmaydi.' }
]);

// SLIDE 3: Solution
createSlide('YECHIM: ODAT ILOVASI', [
    { text: 'ODAT - har qanday majburiyatni qiziqarli RPG (Rolli) o\'yiniga aylantiruvchi platforma.' },
    { text: 'Intizom orqali qulfdan chiqarish: Faqatgina berilgan vazifalar (sport, mutolaa) bajarilgandagina ko\'ngilochar dasturlar ochiladi.' },
    { text: 'O\'yin elementlari orqali g\'alaba: Bolalar o\'z o\'yin darajalarini (Level) va Tangalarini ko\'paytirish uchun majburan emas, o\'z xohishi bilan odat shakllantiradi.' }
]);

// SLIDE 4: How it works & Features
createSlide('QANDAY ISHLAYDI? (ASOSIY IMKONIYATLAR)', [
    { text: 'AI Vision (Kamera bilan kuzatish): Sun\'iy intellekt orqali otjimaniye/press kabi mashqlar avtomatik sanaladi, aldash imkonsiz.' },
    { text: 'App Blocker: Dars paytida chalg\'ituvchi ilovalar yopiladi, vazifa qilingach qulfdan olinadi.' },
    { text: 'PvP va Boss Reydlari: Do\'stlar bilan yakkama-yakka jang (Kim ko\'proq topshiriq bajaradi?) va barcha ishtirokchilar "Dangasalik" maxluqiga qarshi.' },
    { text: 'Ota-ona paneli (Parent Mode): Farzand faoliyatini to\'liq nazorat qilish, GPS orqali kuzatish va mukofot tangalar yuborish.' }
]);

// SLIDE 5: Market Size
createSlide('BOZOR HAJMI (MARKET SIZE)', [
    { text: 'O\'zbekiston miqyosida: 10 milliondan ortiq faol yoshlar, internet va smartfon foydalanuvchilari.' },
    { text: 'MDH va Global bozor: EdTech va Gamified Health/Productivity ilovalari yillik +20% o\'smoqda (bozor hajmi 30 mlrd$+).' },
    { text: 'Ota-onalar farzandining xavfsizligi va ta\'limi uchun raqamli ilovalarga obuna bo\'lishga eng ko\'p pul sarflaydigan segment hisoblanadi.' }
]);

// SLIDE 6: Competitive Advantage
createSlide('RAQOBATDAGI USTUNLIK (UNFAIR ADVANTAGE)', [
    { text: 'Mahalliy madaniyat va o\'zbek tiliga 100% moslashtirilganlik.' },
    { text: 'AI Vision (Sun\'iy intellekt nigohi) orqali vazifalar bajarilishini inson omilisiz tekshirish (faqat ODATda bor!).' },
    { text: 'Mukammal o\'yinlashtirish (Gamification) ekotizimi: Boshqa to-do ilovalar kabi zerikarli emas, foydalanuvchida kuchli "Hook" (ushlab qolish) mexanizmi bor.' },
    { text: 'Avtomatik bloklovchi tizim - dangasalarga variant qoldirmaydi.' }
]);

// Save the Presentation
const outputFile = 'D:\\\\odat123\\\\Flowa\\\\ODAT_Pitch_Deck.pptx';
pres.writeFile({ fileName: outputFile }).then(fileName => {
    console.log('Created: ' + fileName);
}).catch(err => {
    console.error(err);
});
