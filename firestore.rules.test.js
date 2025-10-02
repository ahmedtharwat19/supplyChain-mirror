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
      userId: "admin_user",
    });

    await db.doc("users/active_user").set({
      isActive: true,
      isAdmin: false,
      companyIds: ["company_1"],
      supplierIds: ["supplier_1"],
      factoryIds: ["factory_1"],
      deviceIds: ["dev_user"],
      userId: "active_user",
    });

    await db.doc("users/other_user").set({
      isActive: true,
      isAdmin: false,
      companyIds: ["company_2"],
      supplierIds: [],
      factoryIds: [],
      deviceIds: [],
      userId: "other_user",
    });

    await db.doc("users/inactive_user").set({
      isActive: false,
      isAdmin: false,
      companyIds: [],
      supplierIds: [],
      factoryIds: [],
      deviceIds: [],
      userId: "inactive_user",
    });

    // Companies
    await db.doc("companies/company_1").set({
      name: "PureSip Co",
      userId: "active_user", // owner
      companyId: "company_1",
    });
    await db.doc("companies/company_2").set({
      name: "Other Co",
      userId: "other_user",
      companyId: "company_2",
    });

    // Factories
    await db.doc("factories/factory_1").set({
      name: "Factory One",
      userId: "active_user",
      companyIds: ["company_1"],
    });

    // Vendors (suppliers)
    await db.doc("vendors/supplier_1").set({
      name: "Supplier One",
      userId: "active_user",
    });

    // Items
    await db.doc("items/item_1").set({
      name: "Raw Material A",
      userId: "active_user",
    });

    // Purchase orders
    await db.doc("purchase_orders/order_1").set({
      companyId: "company_1",
      isDelivered: false,
      userId: "active_user",
    });
    await db.doc("purchase_orders/order_delivered").set({
      companyId: "company_1",
      isDelivered: true,
      userId: "active_user",
    });

    // Finished products + composition subcollection
    await db.doc("finished_products/product_1").set({
      name: "SparkTea",
      companyId: "company_1",
      userId: "active_user",
    });
    await db.doc("finished_products/product_1/composition/comp_1").set({
      ingredient: "Green Tea Extract",
      percentage: 10,
    });

    // Manufacturing orders
    await db.doc("manufacturing_orders/morder_1").set({
      companyId: "company_1",
      userId: "active_user",
    });

    // Factory inventory subcollection
    await db.doc("factories/factory_1/inventory/prod_1").set({
      qty: 100,
      productId: "prod_1",
      companyIds: ["company_1"],
      userId: "active_user",
    });

    // Stock movements
    await db.doc("companies/company_1/stock_movements/mov_1").set({
      type: "in",
      qty: 50,
      userId: "active_user",
    });

    // Licenses
    await db.doc("licenses/license_1").set({
      userId: "active_user",
      devices: ["d1"],
      lastUpdated: "2025-09-01",
    });

    // Device requests
    await db.doc("device_requests/dr_1").set({
      userId: "active_user",
      status: "pending",
    });

    // License requests
    await db.doc("license_requests/lreq_1").set({
      userId: "active_user",
      status: "pending",
    });

    // Notifications
    await db.doc("notifications/n_1").set({
      userId: "active_user",
      text: "Hello",
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
        isAdmin: false,
      })
    );
  });

  test("Users: user cannot create other user's doc (wrong uid)", async () => {
    await assertFails(
      activeDb().doc("users/someone_else").set({ isActive: true, userId: "someone_else" })
    );
  });

  test("Users: update only allowed fields (deviceIds, lastUpdated) for owner", async () => {
    await assertSucceeds(
      activeDb().doc("users/active_user").update({ deviceIds: ["dNew"], lastUpdated: "t" })
    );
    await assertFails(activeDb().doc("users/active_user").update({ isAdmin: true }));
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
    await assertFails(activeDb().doc("licenses/license_1").update({ userId: "hacker" }));
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
    await assertSucceeds(
      activeDb().collection("license_requests").doc("lr_new").set({ userId: "active_user" })
    );
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
    await assertSucceeds(
      activeDb().collection("notifications").doc("n_new").set({ userId: "active_user" })
    );
    await assertSucceeds(
      adminDb().collection("notifications").doc("n_admin").set({ userId: "admin_user" })
    );
  });

  test("Notifications: only admin can update/delete", async () => {
    await assertFails(activeDb().doc("notifications/n_1").update({ text: "x" }));
    await assertSucceeds(adminDb().doc("notifications/n_1").update({ text: "x" }));
    await assertFails(activeDb().doc("notifications/n_1").delete());
    await assertSucceeds(adminDb().doc("notifications/n_1").delete());
  });

  // -------- COMPANIES ----------
  test("Companies: active user can create company", async () => {
    await assertSucceeds(
      activeDb().collection("companies").doc("company_new").set({ name: "NewCo", userId: "active_user" })
    );
  });

  test("Companies: inactive user cannot create company", async () => {
    await assertFails(
      inactiveDb().collection("companies").doc("company_x").set({ name: "X", userId: "inactive_user" })
    );
  });

  test("Companies: owner can read/update/delete", async () => {
    await assertSucceeds(activeDb().doc("companies/company_1").get());
    await assertSucceeds(activeDb().doc("companies/company_1").update({ name: "Changed" }));
    await assertSucceeds(activeDb().doc("companies/company_1").delete());
  });

  test("Companies: non-owner active user cannot read/update/delete", async () => {
    await assertFails(otherDb().doc("companies/company_1").get());
    await assertFails(otherDb().doc("companies/company_1").update({ name: "Bad" }));
    await assertFails(otherDb().doc("companies/company_1").delete());
  });

  // -------- FINISHED_PRODUCTS + composition subcollection ----------
  test("FinishedProducts: owner can create finished product", async () => {
    await assertSucceeds(
      activeDb().collection("finished_products").doc("fp_new").set({
        companyId: "company_1",
        userId: "active_user",
        name: "FP New",
      })
    );
  });

  test("FinishedProducts: owner can read/update/delete", async () => {
    await assertSucceeds(activeDb().doc("finished_products/product_1").get());
    await assertSucceeds(activeDb().doc("finished_products/product_1").update({ name: "Changed FP" }));
    await assertSucceeds(activeDb().doc("finished_products/product_1").delete());
  });

  test("FinishedProducts: non-owner cannot read/update/delete", async () => {
    await assertFails(otherDb().doc("finished_products/product_1").get());
    await assertFails(otherDb().doc("finished_products/product_1").update({ name: "Bad" }));
    await assertFails(otherDb().doc("finished_products/product_1").delete());
  });

  // composition subcollection inside finished_products
  test("Composition: owner can read/write/delete composition subcollection", async () => {
    // ✓ GET
    await assertSucceeds(
      activeDb()
        .collection("finished_products")
        .doc("product_1")
        .collection("composition")
        .doc("comp_1")
        .get()
    );

    // ✓ SET
    await assertSucceeds(
      activeDb()
        .collection("finished_products")
        .doc("product_1")
        .collection("composition")
        .doc("comp_2")
        .set({ ingredient: "X", percentage: 5 })
    );

    // ✓ DELETE
    await assertSucceeds(
      activeDb()
        .collection("finished_products")
        .doc("product_1")
        .collection("composition")
        .doc("comp_1")
        .delete()
    );
  });

  test("Composition: non-owner cannot read/write/delete", async () => {
    await assertFails(
      otherDb()
        .collection("finished_products")
        .doc("product_1")
        .collection("composition")
        .doc("comp_1")
        .get()
    );

    await assertFails(
      otherDb()
        .collection("finished_products")
        .doc("product_1")
        .collection("composition")
        .doc("comp_3")
        .set({ ingredient: "X", percentage: 5 })
    );

    await assertFails(
      otherDb()
        .collection("finished_products")
        .doc("product_1")
        .collection("composition")
        .doc("comp_1")
        .delete()
    );
  });

  // -------- FACTORIES + inventory subcollection ----------
  test("Factories: owner can create factory", async () => {
    await assertSucceeds(
      activeDb().collection("factories").doc("factory_new").set({
        userId: "active_user",
        companyIds: ["company_1"],
        name: "Factory New",
      })
    );
  });

  test("Factories: owner can read/update/delete", async () => {
    await assertSucceeds(activeDb().doc("factories/factory_1").get());
    await assertSucceeds(activeDb().doc("factories/factory_1").update({ name: "New Name" }));
    await assertSucceeds(activeDb().doc("factories/factory_1").delete());
  });

  test("Factories: non-owner cannot read/update/delete", async () => {
    await assertFails(otherDb().doc("factories/factory_1").get());
    await assertFails(otherDb().doc("factories/factory_1").update({ name: "X" }));
    await assertFails(otherDb().doc("factories/factory_1").delete());
  });

  // inventory subcollection inside factories
test("Inventory: owner can read/write/delete inventory docs", async () => {
  await assertSucceeds(
    activeDb()
      .collection("factories")
      .doc("factory_1")
      .collection("inventory")
      .doc("prod_1")
      .get()
  );

  await assertSucceeds(
    activeDb()
      .collection("factories")
      .doc("factory_1")
      .collection("inventory")
      .doc("prod_2")
      .set({ qty: 50, productId: "prod_2", companyIds: ["company_1"], userId: "active_user" })
  );

  await assertSucceeds(
    activeDb()
      .collection("factories")
      .doc("factory_1")
      .collection("inventory")
      .doc("prod_1")
      .delete()
  );
});


  test("Inventory: non-owner cannot read/write/delete inventory docs", async () => {
    await assertFails(
      otherDb()
        .collection("factories")
        .doc("factory_1")
        .collection("inventory")
        .doc("prod_1")
        .get()
    );
    await assertFails(
      otherDb()
        .collection("factories")
        .doc("factory_1")
        .collection("inventory")
        .doc("prod_3")
        .set({ qty: 10, productId: "prod_3", companyIds: [], userId: "other_user" })
    );
    await assertFails(
      otherDb()
        .collection("factories")
        .doc("factory_1")
        .collection("inventory")
        .doc("prod_1")
        .delete()
    );
  });

  // -------- PURCHASE_ORDERS ----------
  test("PurchaseOrders: active user can create purchase order", async () => {
    await assertSucceeds(
      activeDb().collection("purchase_orders").doc("po_new").set({
        companyId: "company_1",
        userId: "active_user",
        isDelivered: false,
      })
    );
  });

  test("PurchaseOrders: cannot create for company user doesn't belong to", async () => {
    await assertFails(
      activeDb().collection("purchase_orders").doc("po_bad").set({
        companyId: "company_2",
        userId: "active_user",
      })
    );
  });

  test("PurchaseOrders: owner can read/update/delete if not delivered", async () => {
    await assertSucceeds(activeDb().doc("purchase_orders/order_1").get());
    await assertSucceeds(activeDb().doc("purchase_orders/order_1").update({ isDelivered: false }));
    await assertSucceeds(activeDb().doc("purchase_orders/order_1").delete());
  });

  test("PurchaseOrders: owner cannot update/delete if delivered", async () => {
    await assertFails(activeDb().doc("purchase_orders/order_delivered").update({ isDelivered: false }));
    await assertFails(activeDb().doc("purchase_orders/order_delivered").delete());
  });

  test("PurchaseOrders: non-owner cannot read/update/delete", async () => {
    await assertFails(otherDb().doc("purchase_orders/order_1").get());
    await assertFails(otherDb().doc("purchase_orders/order_1").update({ isDelivered: false }));
    await assertFails(otherDb().doc("purchase_orders/order_1").delete());
  });

  // -------- MANUFACTURING_ORDERS ----------
  test("ManufacturingOrders: owner can create", async () => {
    await assertSucceeds(
      activeDb().collection("manufacturing_orders").doc("mo_new").set({
        companyId: "company_1",
        userId: "active_user",
      })
    );
  });

  test("ManufacturingOrders: owner can read/update/delete", async () => {
    await assertSucceeds(activeDb().doc("manufacturing_orders/morder_1").get());
    await assertSucceeds(activeDb().doc("manufacturing_orders/morder_1").update({ companyId: "company_1" }));
    await assertSucceeds(activeDb().doc("manufacturing_orders/morder_1").delete());
  });

  test("ManufacturingOrders: non-owner cannot read/update/delete", async () => {
    await assertFails(otherDb().doc("manufacturing_orders/morder_1").get());
    await assertFails(otherDb().doc("manufacturing_orders/morder_1").update({ companyId: "company_1" }));
    await assertFails(otherDb().doc("manufacturing_orders/morder_1").delete());
  });

  // -------- STOCK_MOVEMENTS (subcollection in companies) ----------
  test("StockMovements: owner can create", async () => {
    await assertSucceeds(
      activeDb()
        .collection("companies")
        .doc("company_1")
        .collection("stock_movements")
        .doc("sm_new")
        .set({
          type: "in",
          qty: 10,
          userId: "active_user",
        })
    );
  });

  test("StockMovements: owner can read/update/delete", async () => {
    await assertSucceeds(
      activeDb()
        .collection("companies")
        .doc("company_1")
        .collection("stock_movements")
        .doc("mov_1")
        .get()
    );
    await assertSucceeds(
      activeDb()
        .collection("companies")
        .doc("company_1")
        .collection("stock_movements")
        .doc("mov_1")
        .update({ qty: 20 })
    );
    await assertSucceeds(
      activeDb()
        .collection("companies")
        .doc("company_1")
        .collection("stock_movements")
        .doc("mov_1")
        .delete()
    );
  });

  test("StockMovements: non-owner cannot read/update/delete", async () => {
    await assertFails(
      otherDb()
        .collection("companies")
        .doc("company_1")
        .collection("stock_movements")
        .doc("mov_1")
        .get()
    );
    await assertFails(
      otherDb()
        .collection("companies")
        .doc("company_1")
        .collection("stock_movements")
        .doc("mov_1")
        .update({ qty: 99 })
    );
    await assertFails(
      otherDb()
        .collection("companies")
        .doc("company_1")
        .collection("stock_movements")
        .doc("mov_1")
        .delete()
    );
  });

  // -------- VENDORS ----------
  test("Vendors: owner can create vendor", async () => {
    await assertSucceeds(
      activeDb().collection("vendors").doc("vendor_new").set({
        userId: "active_user",
        name: "Vendor New",
      })
    );
  });

  test("Vendors: owner can read/update/delete", async () => {
    await assertSucceeds(activeDb().doc("vendors/supplier_1").get());
    await assertSucceeds(activeDb().doc("vendors/supplier_1").update({ name: "Changed Vendor" }));
    await assertSucceeds(activeDb().doc("vendors/supplier_1").delete());
  });

  test("Vendors: non-owner cannot read/update/delete", async () => {
    await assertFails(otherDb().doc("vendors/supplier_1").get());
    await assertFails(otherDb().doc("vendors/supplier_1").update({ name: "Bad" }));
    await assertFails(otherDb().doc("vendors/supplier_1").delete());
  });

  // -------- ITEMS ----------
  test("Items: owner can create item", async () => {
    await assertSucceeds(
      activeDb().collection("items").doc("item_new").set({
        userId: "active_user",
        name: "Item New",
      })
    );
  });

  test("Items: owner can read/update/delete", async () => {
    await assertSucceeds(activeDb().doc("items/item_1").get());
    await assertSucceeds(activeDb().doc("items/item_1").update({ name: "Changed Item" }));
    await assertSucceeds(activeDb().doc("items/item_1").delete());
  });

  test("Items: non-owner cannot read/update/delete", async () => {
    await assertFails(otherDb().doc("items/item_1").get());
    await assertFails(otherDb().doc("items/item_1").update({ name: "Bad" }));
    await assertFails(otherDb().doc("items/item_1").delete());
  });
});
