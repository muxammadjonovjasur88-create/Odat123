#!/usr/bin/env node
/**
 * check-fix-user.js
 * -----------------
 * Ishlatish:
 *   node server/scripts/check-fix-user.js <UID>
 */

'use strict';

const path = require('path');

// 1. UID argumentini olish
const uid = process.argv[2];

if (!uid) {
  console.error('\n❌  Xato: UID kiritilmadi.');
  console.error('   Ishlatish: node server/scripts/check-fix-user.js <UID>\n');
  process.exit(1);
}

// 2. Firebase Admin SDK (server/utils/firebase.js dan)
const { db, FieldValue } = require('../utils/firebase');
const { Timestamp } = require('firebase-admin/firestore');

function formatValue(val) {
  if (val === null || val === undefined) return 'null';
  if (val && typeof val.toDate === 'function') {
    return val.toDate().toISOString();
  }
  if (Array.isArray(val)) {
    return val.length === 0 ? '[]' : `[${val.join(', ')}]`;
  }
  if (typeof val === 'object') {
    return JSON.stringify(val);
  }
  return String(val);
}

function buildDefaultUserDoc(userUid) {
  const now = Timestamp.now();
  const d = new Date();
  const dayOfWeek = d.getDay() === 0 ? 7 : d.getDay();
  const monday = new Date(d);
  monday.setDate(d.getDate() - (dayOfWeek - 1));
  const pad = (n) => String(n).padStart(2, '0');
  const weekId = `${monday.getFullYear()}-${pad(monday.getMonth() + 1)}-${pad(monday.getDate())}`;

  return {
    uid: userUid,
    name: 'Friend',
    displayName: 'Friend',
    email: '',
    photoUrl: null,
    photoBase64: null,
    avatar: 'leaf',
    bio: null,
    focusType: 'Study',
    streak: 0,
    longestStreak: 0,
    lastActiveDate: null,
    freezes: 1,
    earnedBadges: [],
    totalPoints: 0,
    weeklyPoints: 0,
    totalFocusMinutes: 0,
    weeklyFocusMinutes: 0,
    totalDeepSessions: 0,
    currentWeekId: weekId,
    isPremium: false,
    likesCount: 0,
    sharedWith: [],
    createdAt: now,
    fcmToken: null,
    telegramChatId: null,
  };
}

async function run() {
  const divider = '─'.repeat(65);

  console.log('\n' + divider);
  console.log(`🔍  Tekshirilayotgan UID: ${uid}`);
  console.log(divider);

  // 1. users/{uid} tekshiruvi
  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();

  if (userSnap.exists) {
    const data = userSnap.data();
    console.log('\n✅  users/{uid} hujjati MAVJUD:\n');

    const groups = {
      '👤 Profil': ['uid', 'name', 'displayName', 'email', 'avatar', 'focusType', 'bio', 'isPremium'],
      '🔥 Streak': ['streak', 'longestStreak', 'lastActiveDate', 'freezes', 'earnedBadges'],
      '🏆 Ochkolar': ['totalPoints', 'weeklyPoints', 'currentWeekId', 'totalFocusMinutes', 'weeklyFocusMinutes', 'totalDeepSessions'],
      '👥 Ijtimoiy': ['likesCount', 'sharedWith', 'goalTitle', 'goalWhy', 'goalTargetDate'],
      '🔔 Bildirishnomalar': ['fcmToken', 'telegramChatId'],
      '⏱️  Meta': ['createdAt'],
    };

    const printedFields = new Set();
    for (const [groupName, fields] of Object.entries(groups)) {
      console.log(`  ${groupName}`);
      for (const field of fields) {
        if (Object.prototype.hasOwnProperty.call(data, field)) {
          console.log(`    ${field.padEnd(24)} = ${formatValue(data[field])}`);
          printedFields.add(field);
        }
      }
      console.log('');
    }

    const extra = Object.keys(data).filter((k) => !printedFields.has(k));
    if (extra.length > 0) {
      console.log('  📦 Qo\'shimcha maydonlar:');
      for (const field of extra) {
        console.log(`    ${field.padEnd(24)} = ${formatValue(data[field])}`);
      }
      console.log('');
    }
  } else {
    console.log('\n⚠️   users/{uid} hujjati TOPILMADI — yangi hujjat yaratilmoqda...\n');

    const defaultDoc = buildDefaultUserDoc(uid);
    await userRef.set(defaultDoc);

    console.log('🎉  Hujjat yaratildi! Standart maydonlar:');
    for (const [k, v] of Object.entries(defaultDoc)) {
      console.log(`    ${k.padEnd(24)} = ${formatValue(v)}`);
    }
    console.log('');
  }

  // 2. tasks subkolleksiyasi
  console.log(divider);
  console.log('📋  users/{uid}/tasks subkolleksiyasi:\n');

  const tasksSnap = await db.collection('users').doc(uid).collection('tasks').get();

  if (tasksSnap.empty) {
    console.log('    Vazifalar yo\'q (bo\'sh subkolleksiya).');
  } else {
    console.log(`    Jami vazifalar soni: ${tasksSnap.size}`);

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(today.getDate() + 1);

    const todayTasks = tasksSnap.docs.filter((d) => {
      const ts = d.data().date;
      if (!ts || typeof ts.toDate !== 'function') return false;
      const taskDate = ts.toDate();
      return taskDate >= today && taskDate < tomorrow;
    });

    console.log(`    Bugungi vazifalar soni: ${todayTasks.length}`);

    if (todayTasks.length > 0) {
      console.log('\n    Bugungi vazifalar:');
      todayTasks.forEach((d, i) => {
        const data = d.data();
        const status = data.isCompleted ? '✅' : '⏳';
        const awarded = data.pointsAwarded ? ' [ochko berilgan]' : '';
        console.log(`      ${i + 1}. ${status} ${data.title ?? '(nomsiz)'} [ID: ${d.id}]${awarded}`);
      });
    }
  }

  // 3. lobbies kolleksiyasi
  console.log('\n' + divider);
  console.log('🏟️   lobbies kolleksiyasi (foydalanuvchi a\'zo bo\'lgan):\n');

  const lobbiesSnap = await db
    .collection('lobbies')
    .where('memberUids', 'array-contains', uid)
    .get();

  if (lobbiesSnap.empty) {
    console.log('    Hech qanday lobbyga a\'zo emas.');
  } else {
    console.log(`    A'zo bo'lgan lobbylar soni: ${lobbiesSnap.size}\n`);
    lobbiesSnap.docs.forEach((d, i) => {
      const data = d.data();
      const memberCount = Array.isArray(data.memberUids) ? data.memberUids.length : 0;
      console.log(`    ${i + 1}. "${data.name ?? '(nomsiz)'}" [ID: ${d.id}]`);
      console.log(`       Kod: ${data.code ?? '?'}  |  A'zolar: ${memberCount}`);
    });
  }

  console.log('\n' + divider);
  console.log('✨  Tekshiruv va operatsiyalar muvaffaqiyatli yakunlandi.\n');
}

run().catch((err) => {
  console.error('\n💥  Xatolik yuz berdi:', err);
  process.exit(1);
});
