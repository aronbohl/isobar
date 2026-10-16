// Run with: node --test tests/*.test.js
const test = require("node:test")
const assert = require("node:assert/strict")
const Sky = require("../Sky.js")

const COLS = 120
const ROWS = 40

function frame(kind, wind, ticks, seed) {
  const random = Sky.seeded(seed || 7)
  const s = Sky.create(kind, wind, COLS, ROWS, random)
  let out
  for (let i = 0; i < (ticks || 1); i++) out = joined(Sky.step(s, true, random))
  return { s, out, random }
}

function joined(frame) {
  return { dim: frame.dim.join("\n"), bright: frame.bright.join("\n") }
}

function chars(text) {
  return new Set(text.replace(/[ \n]/g, ""))
}

test("every frame is a full grid in both layers", () => {
  for (const kind of ["stars", "sun", "partly", "clouds", "rain", "storm", "snow"]) {
    const { out } = frame(kind, 10, 3)
    for (const layer of [out.dim, out.bright]) {
      const lines = layer.split("\n")
      assert.equal(lines.length, ROWS, kind)
      assert.ok(lines.every((l) => l.length === COLS), kind)
    }
  }
})

test("each sky draws its own characters", () => {
  const sun = frame("sun", 0, 1).out
  assert.ok(sun.bright.includes("@"))
  assert.equal(sun.bright.split("\n")[6][COLS - 16], "@")

  const stars = frame("stars", 0, 40).out
  for (const ch of chars(stars.dim + stars.bright)) assert.ok(".·+*=-".includes(ch), ch)

  const clouds = frame("clouds", 0, 1).out
  assert.ok(clouds.dim.includes("(___") || clouds.dim.includes("~-."))
  assert.equal(clouds.bright.trim(), "")

  const rain = frame("rain", 5, 2).out
  assert.ok(rain.bright.includes("|"))
  const windy = frame("rain", 50, 2).out
  assert.ok(windy.bright.includes("\\"))
  assert.ok(!windy.bright.includes("|"))

  const snow = frame("snow", 0, 2).out
  assert.ok(snow.dim.includes(".") || snow.dim.includes("·"))
})

test("strong wind adds streaks; calm wind doesn't", () => {
  assert.equal(frame("clouds", 40).s.streaks.length, 14)
  assert.equal(frame("clouds", 20).s.streaks.length, 0)
  assert.ok(frame("clouds", 40, 2).out.dim.includes("~-"))
})

test("storms throw lightning", () => {
  // A generator pinned low makes every chance roll succeed.
  const s = Sky.create("storm", 0, COLS, ROWS, Sky.seeded(1))
  Sky.step(s, true, () => 0.01)
  assert.ok(s.bolt)
  assert.ok(s.bolt.pts.length >= 18)
})

test("a frozen sky repeats the same frame", () => {
  const random = Sky.seeded(3)
  const s = Sky.create("rain", 10, COLS, ROWS, random)
  const a = joined(Sky.step(s, false, random))
  const b = joined(Sky.step(s, false, random))
  assert.equal(a.dim, b.dim)
  assert.equal(a.bright, b.bright)
  assert.equal(s.f, 0)
  assert.notEqual(joined(Sky.step(s, true, random)).bright, a.bright)
})
