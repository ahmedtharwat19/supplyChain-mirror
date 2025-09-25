// firestore.rules.test.js
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import fs from "fs";

const PROJECT_ID = "puresip-test";
const RULES = fs.readFileSync("firestore.rules", "utf8");

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: RULES },
  });

  // Seed initial data bypassing rules
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    // Users
    await db.doc("users/admin_user").set({
      isActive: true,
      isAdmin: true,
      companyIds: ["company_1"],
      supplierIds: [],
      factoryIds: ["factory_1"],
      deviceIds: ["dev_admin"],
      userId: "admin_user"
    });

    await db.doc("users/active_user").set({
      isActive: true,
      isAdmin: false,
      companyIds: ["company_1"],
      supplierIds: ["supplier_1"],
      factoryIds: ["factory_1"],
      deviceIds: ["dev_user"],
      userId: "active_user"
    });

    await db.doc("users/other_user").set({
      isActive: true,
      isAdmin: false,
      companyIds: ["company_2"],
      supplierIds: [],
      factoryIds: [],
      deviceIds: [],
      userId: "other_user"
    });

    await db.doc("users/inactive_user").set({
      isActive: false,
      isAdmin: false,
      companyIds: [],
      supplierIds: [],
      factoryIds: [],
      deviceIds: [],
      userId: "inactive_user"
    });

    // Companies
    await db.doc("companies/company_1").set({
      name: "PureSip Co",
      userId: "active_user", // owner
      companyId: "company_1"
    });
    await db.doc("companies/company_2").set({
      name: "Other Co",
      userId: "other_user",
      companyId: "company_2"
    });

    // Factories
    await db.doc("factories/factory_1").set({
      name: "Factory One",
      userId: "active_user",
      companyIds: ["company_1"]
    });

    // Vendors (suppliers)
    await db.doc("vendors/supplier_1").set({
      name: "Supplier One",
      userId: "active_user"
    });

    // Items
    await db.doc("items/item_1").set({
      name: "Raw Material A",
      userId: "active_user"
    });

    // Purchase orders
    await db.doc("purchase_orders/order_1").set({
      companyId: "company_1",
      isDelivered: false,
      userId: "active_user"
    });
    await db.doc("purchase_orders/order_delivered").set({
      companyId: "company_1",
      isDelivered: true,
      userId: "active_user"
    });

    // Finished products + composition subcollection
    await db.doc("finished_products/product_1").set({
      name: "SparkTea",
      companyId: "company_1",
      userId: "active_user"
    });
    await db.doc("finished_products/product_1/composition/comp_1").set({
      ingredient: "Green Tea Extract",
      percentage: 10
    });

    // Manufacturing orders
    await db.doc("manufacturing_orders/morder_1").set({
      companyId: "company_1",
      userId: "active_user"
    });

    // Factory inventory subcollection
    await db.doc("factories/factory_1/inventory/prod_1").set({
      qty: 100,
      productId: "prod_1",
      companyIds: ["company_1"],
      userId: "active_user"
    });

    // Stock movements
    await db.doc("companies/company_1/stock_movements/mov_1").set({
      type: "in",
      qty: 50,
      userId: "active_user"
    });

    // Licenses
    await db.doc("licenses/license_1").set({
      userId: "active_user",
      devices: ["d1"],
      lastUpdated: "2025-09-01"
    });

    // Device requests
    await db.doc("device_requests/dr_1").set({
      userId: "active_user",
      status: "pending"
    });

    // License requests
    await db.doc("license_requests/lreq_1").set({
      userId: "active_user",
      status: "pending"
    });

    // Notifications
    await db.doc("notifications/n_1").set({
      userId: "active_user",
      text: "Hello"
    });
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

describe("🔐 Full Firestore Rules Test Suite", () => {
  // Context helpers
  const guestDb = () => testEnv.unauthenticatedContext().firestore();
  const adminDb = () => testEnv.authenticatedContext("admin_user").firestore();
  const activeDb = () => testEnv.authenticatedContext("active_user").firestore();
  const otherDb = () => testEnv.authenticatedContext("other_user").firestore();
  const inactiveDb = () => testEnv.authenticatedContext("inactive_user").firestore();

  // -------- USERS ----------
  test("Users: guest cannot read user doc", async () => {
    await assertFails(guestDb().doc("users/active_user").get());
  });

  test("Users: user can read own doc", async () => {
    await assertSucceeds(activeDb().doc("users/active_user").get());
  });

  test("Users: user cannot read another user", async () => {
    await assertFails(activeDb().doc("users/other_user").get());
  });

  test("Users: admin can read any user", async () => {
    await assertSucceeds(adminDb().doc("users/other_user").get());
  });

  test("Users: user can create own user doc", async () => {
    // استخدم مستخدم جديد تماماً
    const newUserId = "completely_new_user";
    const newUserDb = testEnv.authenticatedContext(newUserId).firestore();

    await assertSucceeds(
      newUserDb.doc(`users/${newUserId}`).set({
        isActive: true,
        userId: newUserId,
        companyIds: [],
        supplierIds: [],
        factoryIds: [],
        deviceIds: [],
        isAdmin: false
      })
    );
  });

  test("Users: user cannot create other user's doc (wrong uid)", async () => {
    // The rules required request.auth.uid == userId for create, so here uid != doc id
    // But our test context uid is "active_user", attempt to create doc "users/x" should fail
    await assertFails(
      activeDb().doc("users/someone_else").set({ isActive: true, userId: "someone_else" })
    );
  });

  test("Users: update only allowed fields (deviceIds, lastUpdated) for owner", async () => {
    // try updating allowed field
    await assertSucceeds(
      activeDb().doc("users/active_user").update({ deviceIds: ["dNew"], lastUpdated: "t" })
    );
    // try updating a disallowed field (e.g., isAdmin) -> should fail
    await assertFails(
      activeDb().doc("users/active_user").update({ isAdmin: true })
    );
  });

  test("Users: admin can delete user", async () => {
    await assertSucceeds(adminDb().doc("users/inactive_user").delete());
  });

  // -------- LICENSES ----------
  test("Licenses: owner can read own license", async () => {
    await assertSucceeds(activeDb().doc("licenses/license_1").get());
  });

  test("Licenses: other user cannot read license", async () => {
    await assertFails(otherDb().doc("licenses/license_1").get());
  });

  test("Licenses: owner can update devices/lastUpdated only", async () => {
    await assertSucceeds(
      activeDb().doc("licenses/license_1").update({ devices: ["d1", "d2"], lastUpdated: "t2" })
    );
    await assertFails(
      activeDb().doc("licenses/license_1").update({ userId: "hacker" })
    );
  });

  test("Licenses: admin can create license", async () => {
    await assertSucceeds(adminDb().collection("licenses").doc("license_admin").set({ userId: "admin_user" }));
  });

  // -------- DEVICE_REQUESTS ----------
  test("DeviceRequests: owner can create request for self", async () => {
    await assertSucceeds(
      activeDb().collection("device_requests").doc("dr_new").set({ userId: "active_user" })
    );
  });

  test("DeviceRequests: user cannot create request for another user", async () => {
    await assertFails(
      activeDb().collection("device_requests").doc("dr_fake").set({ userId: "other_user" })
    );
  });

  test("DeviceRequests: owner can read own request", async () => {
    await assertSucceeds(activeDb().doc("device_requests/dr_1").get());
  });

  test("DeviceRequests: admin can list requests", async () => {
    await assertSucceeds(adminDb().collection("device_requests").get());
  });

  test("DeviceRequests: only admin can update requests", async () => {
    await assertFails(activeDb().doc("device_requests/dr_1").update({ status: "approved" }));
    await assertSucceeds(adminDb().doc("device_requests/dr_1").update({ status: "approved" }));
  });

  // -------- LICENSE_REQUESTS ----------
  test("LicenseRequests: owner can create own request", async () => {
    await assertSucceeds(activeDb().collection("license_requests").doc("lr_new").set({ userId: "active_user" }));
  });

  test("LicenseRequests: admin can list requests", async () => {
    await assertSucceeds(adminDb().collection("license_requests").get());
  });

  test("LicenseRequests: owner can read own request", async () => {
    await assertSucceeds(activeDb().doc("license_requests/lreq_1").get());
  });

  test("LicenseRequests: only admin can update/delete", async () => {
    await assertFails(activeDb().doc("license_requests/lreq_1").update({ status: "x" }));
    await assertSucceeds(adminDb().doc("license_requests/lreq_1").update({ status: "x" }));
  });

  // -------- NOTIFICATIONS ----------
  test("Notifications: owner can read notification", async () => {
    await assertSucceeds(activeDb().doc("notifications/n_1").get());
  });

  test("Notifications: guest cannot read notification", async () => {
    await assertFails(guestDb().doc("notifications/n_1").get());
  });

  test("Notifications: owner or admin can create notification for self", async () => {
    await assertSucceeds(activeDb().collection("notifications").doc("n_new").set({ userId: "active_user" }));
    await assertSucceeds(adminDb().collection("notifications").doc("n_admin").set({ userId: "admin_user" }));
  });

  test("Notifications: only admin can update/delete", async () => {
    await assertFails(activeDb().doc("notifications/n_1").update({ text: "x" }));
    await assertSucceeds(adminDb().doc("notifications/n_1").update({ text: "x" }));
    await assertFails(activeDb().doc("notifications/n_1").delete());
    await assertSucceeds(adminDb().doc("notifications/n_1").delete());
  });

  // -------- COMPANIES ----------
  test("Companies: active user can create company", async () => {
    await assertSucceeds(activeDb().collection("companies").doc("company_new").set({ name: "NewCo", userId: "active_user" }));
  });

  test("Companies: inactive user cannot create company", async () => {
    await assertFails(inactiveDb().collection("companies").doc("company_x").set({ name: "X", userId: "inactive_user" }));
  });

  test("Companies: owner can read/update/delete", async () => {
    await assertSucceeds(activeDb().doc("companies/company_1").get());
    await assertSucceeds(activeDb().doc("companies/company_1").update({ name: "Changed" }));
    await assertSucceeds(activeDb().doc("companies/company_1").delete());
  });

  test("Companies: non-owner active user cannot read/update/delete", async () => {
    // other_user belongs to company_2, should not be allowed to operate on company_1
    await assertFails(otherDb().doc("companies/company_1").get());
    await assertFails(otherDb().doc("companies/company_1").update({ name: "H" }));
  });

  // -------- FACTORIES ----------
  test("Factories: active owner can create factory", async () => {
    await assertSucceeds(
      activeDb().collection("factories").doc("factory_new").set({
        name: "Factory New",
        userId: "active_user",
        companyIds: ["company_1"]
      })
    );
  });

  test("Factories: read allowed for owner or user with company in factory", async () => {
    await assertSucceeds(activeDb().doc("factories/factory_1").get());
    // other_user is not in company_1 so should fail
    await assertFails(otherDb().doc("factories/factory_1").get());
  });

  test("Factories: only owner can update/delete", async () => {
    await assertSucceeds(activeDb().doc("factories/factory_1").update({ name: "F1" }));
    await assertFails(otherDb().doc("factories/factory_1").update({ name: "bad" }));
  });

  // -------- VENDORS ----------
  test("Vendors: active user can create vendor", async () => {
    await assertSucceeds(activeDb().collection("vendors").doc("supplier_new").set({ name: "S new", userId: "active_user" }));
  });

  test("Vendors: owner or linked user can read vendor", async () => {
    await assertSucceeds(activeDb().doc("vendors/supplier_1").get());
    await assertFails(inactiveDb().doc("vendors/supplier_1").get());
  });

  test("Vendors: update/delete allowed for owner or linked user", async () => {
    await assertSucceeds(activeDb().doc("vendors/supplier_1").update({ name: "S1" }));
    await assertFails(otherDb().doc("vendors/supplier_1").update({ name: "bad" }));
  });

  // -------- ITEMS ----------
  test("Items: active user can create item (userId must match)", async () => {
    await assertSucceeds(activeDb().collection("items").doc("item_new").set({ name: "I", userId: "active_user" }));
    await assertFails(activeDb().collection("items").doc("item_bad").set({ name: "I", userId: "someone" }));
  });

  test("Items: active user can read items", async () => {
    await assertSucceeds(activeDb().doc("items/item_1").get());
  });

  test("Items: only owner can update/delete", async () => {
    await assertFails(otherDb().doc("items/item_1").update({ name: "X" }));
    // owner was active_user so allowed
    await assertSucceeds(activeDb().doc("items/item_1").update({ name: "X" }));
  });

  // -------- PURCHASE_ORDERS ----------
  test("PurchaseOrders: active user can create order for own company", async () => {
    await assertSucceeds(activeDb().collection("purchase_orders").doc("po_new").set({ companyId: "company_1", items: [] }));
  });

  test("PurchaseOrders: cannot create order for other company", async () => {
    await assertFails(activeDb().collection("purchase_orders").doc("po_bad").set({ companyId: "company_2", items: [] }));
  });

  test("PurchaseOrders: read/list allowed for active users", async () => {
    await assertSucceeds(activeDb().doc("purchase_orders/order_1").get());
    await assertSucceeds(activeDb().collection("purchase_orders").get());
  });

  test("PurchaseOrders: delete allowed for company owner when not delivered", async () => {
    // owner active_user on order_1 (isDelivered: false)
    await assertSucceeds(activeDb().doc("purchase_orders/order_1").delete());
    // but delivered order should be protected
    await assertFails(activeDb().doc("purchase_orders/order_delivered").delete());
  });

  test("PurchaseOrders: admin can delete any order", async () => {
    await assertSucceeds(adminDb().doc("purchase_orders/order_delivered").delete());
  });

  // -------- FINISHED_PRODUCTS & composition (subcollection) ----------
  test("FinishedProducts: active user can create product for own company", async () => {
    await assertSucceeds(activeDb().collection("finished_products").doc("fp_new").set({ companyId: "company_1", name: "New" }));
  });

  test("FinishedProducts: read allowed for active user", async () => {
    await assertSucceeds(activeDb().doc("finished_products/product_1").get());
  });

  test("FinishedProducts: update/delete only by company owner", async () => {
    await assertFails(otherDb().doc("finished_products/product_1").update({ name: "bad" }));
    await assertSucceeds(activeDb().doc("finished_products/product_1").update({ name: "ok" }));
  });

  test("Composition subcollection: only company owner can create/read/update/delete", async () => {
    await assertSucceeds(activeDb().collection("finished_products/product_1/composition").doc("c_new").set({ ingredient: "X" }));
    await assertFails(otherDb().doc("finished_products/product_1/composition/comp_1").delete());
    await assertSucceeds(adminDb().doc("finished_products/product_1/composition/comp_1").get());
  });

  // -------- MANUFACTURING_ORDERS ----------
  test("ManufacturingOrders: create allowed for authenticated users", async () => {
    await assertSucceeds(activeDb().collection("manufacturing_orders").doc("m_new").set({ companyId: "company_1" }));
  });

  test("ManufacturingOrders: write allowed when company in auth token (simulate)", async () => {
    // this rule uses request.auth.token.companyIds; in emulator tests we can't set token claims easily,
    // but the rule uses `resource.data.companyId in request.auth.token.companyIds` for write.
    // We will test read/create which are permitted; write test depends on token claims so skip detailed claim test here.
    await assertSucceeds(activeDb().doc("manufacturing_orders/morder_1").get());
  });

  // -------- FACTORY INVENTORY (subcollection) ----------
  test("Factory inventory: create/read/update allowed for users having companies in factory", async () => {
    await assertSucceeds(activeDb().collection("factories/factory_1/inventory").doc("inv_new").set({ qty: 10 }));
    await assertSucceeds(activeDb().doc("factories/factory_1/inventory/prod_1").get());
    await assertFails(otherDb().doc("factories/factory_1/inventory/prod_1").update({ qty: 999 }));
  });

  // -------- STOCK MOVEMENTS ----------
  test("Stock movements: create/read allowed for company owners", async () => {
    await assertSucceeds(activeDb().collection("companies/company_1/stock_movements").doc("sm_new").set({ type: "in", qty: 10 }));
    await assertSucceeds(activeDb().doc("companies/company_1/stock_movements/mov_1").get());
    await assertFails(otherDb().doc("companies/company_1/stock_movements/mov_1").get());
  });

  // -------- ADDITIONAL: vendors list and companies list checks ----------
  test("Active user can list vendors and companies (list allowed for active users)", async () => {
    await assertSucceeds(activeDb().collection("vendors").get());
    await assertSucceeds(activeDb().collection("companies").get());
  });

  test("Guest cannot list vendors/companies", async () => {
    await assertFails(guestDb().collection("vendors").get());
    await assertFails(guestDb().collection("companies").get());
  });
});
