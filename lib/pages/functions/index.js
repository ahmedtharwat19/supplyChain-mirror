const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp();

/**
 * deleteUser — Cloud Function (v2)
 * تُستدعى من Flutter لحذف مستخدم بالكامل من Auth + Firestore
 * الشروط: المستدعي لازم يكون Admin
 */
exports.deleteUser = onCall(async (request) => {
  // ── 1. التحقق من أن المستدعي مسجّل دخول ──
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً");
  }

  const callerUid = request.auth.uid;
  const targetUid = request.data.userId;

  if (!targetUid) {
    throw new HttpsError("invalid-argument", "userId مطلوب");
  }

  if (callerUid === targetUid) {
    throw new HttpsError("failed-precondition", "لا يمكنك حذف حسابك الخاص من هنا");
  }

  const db = getFirestore();
  const auth = getAuth();

  // ── 2. التحقق أن المستدعي Admin فعلاً ──
  const callerDoc = await db.collection("users").doc(callerUid).get();
  if (!callerDoc.exists || callerDoc.data().isAdmin !== true) {
    throw new HttpsError("permission-denied", "ليس لديك صلاحية حذف المستخدمين");
  }

  // ── 3. جلب بيانات المستخدم المراد حذفه ──
  const targetDoc = await db.collection("users").doc(targetUid).get();
  if (!targetDoc.exists) {
    throw new HttpsError("not-found", "المستخدم غير موجود");
  }

  const userData = targetDoc.data();

  // ── 4. حذف بيانات Firestore المرتبطة ──
  const batch = db.batch();

  // أ) user document نفسه
  batch.delete(db.collection("users").doc(targetUid));

  // ب) الترخيص الخاص بالمستخدم
  const licenseKey = userData.licenseKey;
  if (licenseKey) {
    batch.delete(db.collection("licenses").doc(licenseKey));
  }

  // ج) طلبات الترخيص
  const licenseRequests = await db
    .collection("license_requests")
    .where("userId", "==", targetUid)
    .get();
  licenseRequests.forEach((doc) => batch.delete(doc.ref));

  // د) الشركات الخاصة به (لو موجودة)
  const companyIds = userData.companyIds ?? [];
  for (const companyId of companyIds) {
    batch.delete(db.collection("companies").doc(companyId));
  }

  // هـ) المصانع
  const factoryIds = userData.factoryIds ?? [];
  for (const factoryId of factoryIds) {
    batch.delete(db.collection("factories").doc(factoryId));
  }

  // و) user_stats لو موجودة
  const statsDoc = await db.collection("user_stats").doc(targetUid).get();
  if (statsDoc.exists) {
    batch.delete(statsDoc.ref);
  }

  await batch.commit();

  // ── 5. حذف من Firebase Authentication ──
  await auth.deleteUser(targetUid);

  return { success: true, message: "تم حذف المستخدم بنجاح" };
});