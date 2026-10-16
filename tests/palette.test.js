// Run with: node --test tests/*.test.js
const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const Palette = require("../Palette.js")

const theme = (name) => Palette.parseToml(fs.readFileSync(path.join(__dirname, "fixtures", `theme-${name}.toml`), "utf8"))

test("colors.toml parses top-level keys only", () => {
  const values = Palette.parseToml('accent = "#dcd7ba"\nred = \'#c34043\'\n# note\n[extra]\nred = "#000000"\n')
  assert.deepEqual(values, { accent: "#dcd7ba", red: "#c34043" })
})

test("alert colors are fixed reds, oranges and yellows, not the theme's", () => {
  // Kanagawa's own red is #c34043; lumon/hackerman repurpose theirs entirely.
  const dark = Palette.build(theme("kanagawa"), {})
  assert.equal(dark.alerts.warning, Palette.ALERTS.dark.warning)
  assert.equal(dark.alerts.emergency, Palette.ALERTS.dark.warning)
  assert.equal(dark.alerts.watch, Palette.ALERTS.dark.watch)
  assert.equal(dark.alerts.advisory, Palette.ALERTS.dark.advisory)
  assert.equal(dark.alerts.statement, dark.muted)
  assert.equal(Palette.build({ red: "#50f872", yellow: "#50f7d4", background: "#0B0C16" }, {}).alerts.warning, Palette.ALERTS.dark.warning)

  const light = Palette.build(theme("flexoki-light"), {})
  assert.equal(light.alerts.warning, Palette.ALERTS.light.warning)
  assert.equal(light.alerts.advisory, Palette.ALERTS.light.advisory)
})

test("every alert and text color stays legible", () => {
  for (const name of ["kanagawa", "flexoki-light", "last-horizon"]) {
    const p = Palette.build(theme(name), {})
    assert.ok(Palette.contrast(p.muted, p.bg) >= 4.5, `${name} muted`)
    for (const level of ["advisory", "watch", "warning", "emergency"])
      assert.ok(Palette.contrast(p.alerts[level], p.bg) >= 3, `${name} ${level} ${p.alerts[level]} on ${p.bg}`)
  }
  assert.equal(Palette.build(theme("flexoki-light"), {}).light, true)
})

test("the shell's resolved colors win, and an empty theme still builds", () => {
  const p = Palette.build(theme("kanagawa"), { background: "#000000", foreground: "#FFFFFF", accent: "#123456" })
  assert.equal(p.bg, "#000000")
  assert.equal(p.fg, "#ffffff")
  assert.equal(p.accent, "#123456")
  const empty = Palette.build({}, {})
  assert.ok(Palette.isHex(empty.alerts.watch))
  assert.ok(Palette.isHex(empty.muted))
})

test("rain follows the theme's cyan; meter scales are fixed", () => {
  const p = Palette.build(theme("kanagawa"), {})
  assert.equal(p.rain, "#6a9589")
  assert.deepEqual(p.scale, Palette.SCALE.dark)
  assert.deepEqual(Palette.build(theme("flexoki-light"), {}).scale, Palette.SCALE.light)
  assert.ok(Palette.contrast(Palette.build(theme("last-horizon"), {}).rain, "#0c0b0c") >= 3)
})

test("sky layers stay quieter than text", () => {
  for (const name of ["kanagawa", "flexoki-light", "last-horizon"]) {
    const p = Palette.build(theme(name), {})
    assert.ok(Palette.contrast(p.skyDim, p.bg) < Palette.contrast(p.muted, p.bg), name)
    assert.ok(Palette.contrast(p.skyDim, p.bg) > 1.2, name)
    assert.ok(Palette.contrast(p.skyBright, p.bg) > Palette.contrast(p.skyDim, p.bg), name)
  }
})
