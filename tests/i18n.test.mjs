import assert from "node:assert/strict"
import fs from "node:fs"
import vm from "node:vm"

const source = fs.readFileSync(new URL("../I18n.js", import.meta.url), "utf8")
const context = vm.createContext({})
vm.runInContext(source, context)

const localeKey = context.localeKey
const translate = context.translate

assert.equal(localeKey("zh_CN"), "zh_CN")
assert.equal(localeKey("zh-CN"), "zh_CN")
assert.equal(localeKey("zh_Hans_SG"), "zh_CN")
assert.equal(localeKey("zh_TW"), "en")
assert.equal(localeKey("en_US"), "en")
assert.equal(localeKey("C"), "en")

assert.equal(translate("zh_CN", "noActivity"), "暂无活跃网络流量")
assert.equal(translate("en_US", "download"), "DOWNLOAD")
assert.equal(
  translate("zh_CN", "footer", { count: 5 }),
  "近期 5 个进程及未归属流量 · 按 R 刷新"
)
assert.equal(translate("zh_CN", "unknownKey"), "unknownKey")

console.log("i18n tests passed")
