// seed_exam_questions.js
// Run from your project root:
//   node seed_exam_questions.js
//
// Prerequisites:
//   1. npm install firebase-admin
//   2. Download your Firebase service account key from:
//      Firebase Console → Project Settings → Service Accounts → Generate New Private Key
//   3. Save it as "serviceAccountKey.json" in the same directory
//
// OR if you already have the Firebase CLI authenticated, use the Firestore shell method below.

const admin = require('firebase-admin');

// Option A: Use service account key file
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'mohaffez-ba2ec',
});

// Option B: Use default credentials (Firebase CLI authenticated users)
// admin.initializeApp({
//   projectId: 'mohaffez-ba2ec',
// });

const db = admin.firestore();

const questions = [
  {
    questionText: "ما حكم النون الساكنة إذا جاء بعدها حرف الباء؟",
    options: ["إقلاب", "إخفاء", "إدغام", "إظهار"],
    correctOptionIndex: 0,
    category: "tajweed",
    difficulty: "easy",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: "كم عدد أجزاء القرآن الكريم؟",
    options: ["28", "30", "32", "25"],
    correctOptionIndex: 1,
    category: "general",
    difficulty: "easy",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: "ما هي أطول سورة في القرآن الكريم؟",
    options: ["آل عمران", "النساء", "البقرة", "الأعراف"],
    correctOptionIndex: 2,
    category: "general",
    difficulty: "easy",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: "ما هو حكم المد المتصل؟",
    options: ["مد جائز", "مد واجب", "مد لازم", "مد طبيعي"],
    correctOptionIndex: 1,
    category: "tajweed",
    difficulty: "medium",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: "ما هو مقدار المد الطبيعي؟",
    options: ["حركة واحدة", "حركتان", "أربع حركات", "ست حركات"],
    correctOptionIndex: 1,
    category: "tajweed",
    difficulty: "easy",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: "أي من الحروف التالية هي حروف الإظهار الحلقي؟",
    options: ["ب ت ث", "ي ن م و", "ء هـ ع ح غ خ", "ص ض ط ظ"],
    correctOptionIndex: 2,
    category: "tajweed",
    difficulty: "medium",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: 'ما هو حكم لام "أل" إذا جاء بعدها حرف الشمس؟',
    options: ["إظهار", "إدغام", "إخفاء", "إقلاب"],
    correctOptionIndex: 1,
    category: "tajweed",
    difficulty: "medium",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: "في أي سورة وردت آية الكرسي؟",
    options: ["آل عمران", "البقرة", "النساء", "المائدة"],
    correctOptionIndex: 1,
    category: "hifz",
    difficulty: "easy",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: "ما معنى الإدغام بغنة؟",
    options: ["إدخال حرف بحرف مع صوت أنفي", "إدخال حرف بحرف بدون غنة", "إخفاء الحرف", "قلب الحرف"],
    correctOptionIndex: 0,
    category: "tajweed",
    difficulty: "medium",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: "كم عدد سور القرآن الكريم؟",
    options: ["112", "114", "116", "120"],
    correctOptionIndex: 1,
    category: "general",
    difficulty: "easy",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: 'ما هو حكم الراء في كلمة "بصيرٍ" عند الوقف؟',
    options: ["تفخيم", "ترقيق", "جواز الوجهين", "سكون فقط"],
    correctOptionIndex: 1,
    category: "tajweed",
    difficulty: "hard",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: "ما هو الفرق بين المد اللازم الكلمي والحرفي؟",
    options: ["الكلمي في كلمة والحرفي في حرف من فواتح السور", "لا فرق بينهما", "الكلمي أطول", "الحرفي واجب والكلمي جائز"],
    correctOptionIndex: 0,
    category: "tajweed",
    difficulty: "hard",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: 'ما هي السورة التي تبدأ بـ "طسم"؟',
    options: ["الشعراء", "النمل", "الشعراء والقصص", "يس"],
    correctOptionIndex: 2,
    category: "hifz",
    difficulty: "hard",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: "ما حكم النون والميم المشددتين؟",
    options: ["إخفاء", "غنة بمقدار حركتين", "إظهار", "إدغام"],
    correctOptionIndex: 1,
    category: "tajweed",
    difficulty: "medium",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: "ما هو حكم الميم الساكنة قبل حرف الباء؟",
    options: ["إخفاء شفوي", "إدغام شفوي", "إظهار شفوي", "إقلاب"],
    correctOptionIndex: 0,
    category: "tajweed",
    difficulty: "medium",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: 'كم مرة ذُكر اسم "محمد" صراحةً في القرآن؟',
    options: ["3 مرات", "4 مرات", "5 مرات", "6 مرات"],
    correctOptionIndex: 1,
    category: "hifz",
    difficulty: "medium",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: 'ما هو السجود في سورة "ص"؟',
    options: ["سجدة تلاوة واجبة", "سجدة شكر", "سجدة تلاوة مستحبة عند الجمهور", "لا يوجد سجود"],
    correctOptionIndex: 2,
    category: "fiqh_tilawa",
    difficulty: "hard",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: "ما هو التقاء الساكنين؟",
    options: ["وجود حرفين ساكنين متتاليين", "وجود حرفين متحركين", "إدغام حرفين", "مد الحرف"],
    correctOptionIndex: 0,
    category: "tajweed",
    difficulty: "medium",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: "أي رواية يُقرأ بها في معظم البلاد العربية؟",
    options: ["رواية ورش", "رواية حفص عن عاصم", "رواية قالون", "رواية الدوري"],
    correctOptionIndex: 1,
    category: "general",
    difficulty: "easy",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
  {
    questionText: "ما حكم إخفاء النون الساكنة عند حرف القاف؟",
    options: ["إظهار", "إخفاء حقيقي", "إدغام", "إقلاب"],
    correctOptionIndex: 1,
    category: "tajweed",
    difficulty: "hard",
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: "seed_script",
  },
];

async function seed() {
  const batch = db.batch();

  for (const q of questions) {
    const ref = db.collection('examQuestions').doc();
    batch.set(ref, q);
  }

  await batch.commit();
  console.log(`✅ Seeded ${questions.length} exam questions successfully.`);
  
  // Verify
  const snap = await db.collection('examQuestions').where('isActive', '==', true).get();
  console.log(`📊 Total active questions in Firestore: ${snap.size}`);
  
  const easy = snap.docs.filter(d => d.data().difficulty === 'easy').length;
  const medium = snap.docs.filter(d => d.data().difficulty === 'medium').length;
  const hard = snap.docs.filter(d => d.data().difficulty === 'hard').length;
  console.log(`   Easy: ${easy} | Medium: ${medium} | Hard: ${hard}`);
  
  process.exit(0);
}

seed().catch((err) => {
  console.error('❌ Seed failed:', err);
  process.exit(1);
});
