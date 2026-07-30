const {readFileSync} = require("node:fs");
const {resolve} = require("node:path");
const {after, before, beforeEach, test} = require("node:test");
const assert = require("node:assert/strict");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const projectId = "demo-hobbyquest-rubric";
const uid = "rubric-user";
const questPath = `users/${uid}/plans/plan-1/quests/quest-1`;
let testEnv;

/**
 * Builds a valid quest document with optional field overrides.
 * @param {Object} overrides quest fields to replace
 * @return {Object} a valid quest document
 */
function validQuest(overrides = {}) {
  return {
    node_id: "quest-1",
    title: "Shade a Simple Sphere",
    desc: "Use one light source to shade a sphere.",
    steps: ["Draw", "Shade", "Review"],
    xp_reward: 150,
    type: "challenge",
    duration_minutes: 20,
    depends_on: [],
    isCompleted: false,
    isActive: true,
    reflectionNote: "",
    completedAt: null,
    imageUrl: null,
    greeting: null,
    observation: null,
    tip: null,
    youtube_search_query: null,
    awardedXP: null,
    ...overrides,
  };
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc(`users/${uid}`).set({
      nickname: "Hero",
      isOnboardingComplete: true,
      totalXP: 0,
      activePlanId: "plan-1",
    });
  });
});

after(async () => {
  await testEnv.cleanup();
});

test("accepts legacy and rubric-aware quest documents", async () => {
  const db = testEnv.authenticatedContext(uid).firestore();
  await assertSucceeds(db.doc(questPath).set(validQuest()));
  await assertSucceeds(
      db.doc(`${questPath}-rubric`).set(validQuest({
        node_id: "quest-1-rubric",
        isCompleted: true,
        image_rubric: [
          "Clear separation between light, middle, and dark values",
          "Consistent light direction across the subject",
          "Controlled hard and soft edges where forms change",
        ],
        rubricAssessments: [
          {
            criterion:
              "Clear separation between light, middle, and dark values",
            met: true,
            feedback: "Values read clearly.",
          },
          {
            criterion: "Consistent light direction across the subject",
            met: true,
            feedback: "Light stays consistent.",
          },
          {
            criterion:
              "Controlled hard and soft edges where forms change",
            met: false,
            feedback: "Soften the form shadow.",
          },
        ],
      })),
  );
});

test("rejects invalid rubric lengths and oversized criteria", async () => {
  const db = testEnv.authenticatedContext(uid).firestore();
  await assertFails(
      db.doc(questPath).set(validQuest({image_rubric: ["One", "Two"]})),
  );
  await assertFails(
      db.doc(questPath).set(validQuest({
        image_rubric: ["x".repeat(121), "Two", "Three"],
      })),
  );
});

test("rejects malformed rubric assessment maps and extra keys", async () => {
  const db = testEnv.authenticatedContext(uid).firestore();
  const rubricAssessments = [
    {criterion: "One", met: true, feedback: "Visible."},
    {criterion: "Two", met: false, feedback: "Needs work."},
    {criterion: "Three", met: true, feedback: "Visible.", score: 100},
  ];
  await assertFails(
      db.doc(questPath).set(validQuest({
        isCompleted: true,
        image_rubric: ["One", "Two", "Three"],
        rubricAssessments,
      })),
  );
  await assertFails(
      db.doc(questPath).set(validQuest({
        isCompleted: true,
        image_rubric: ["One", "Two", "Three"],
        rubricAssessments: [
          {criterion: "One", met: "true", feedback: "Visible."},
          {criterion: "Two", met: false, feedback: "Needs work."},
          {criterion: "Three", met: true, feedback: "Visible."},
        ],
      })),
  );
});

test("rejects cross-user writes", async () => {
  const attackerDb = testEnv.authenticatedContext("other-user").firestore();
  await assertFails(attackerDb.doc(questPath).set(validQuest()));
  assert.ok(true);
});
