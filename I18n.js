var messages = {
  en: {
    tooltip: "Show network activity by process",
    title: "Network activity by process",
    process: "PROCESS",
    download: "DOWNLOAD",
    upload: "UPLOAD",
    readError: "Could not read network traffic",
    measuring: "Measuring network traffic…",
    noActivity: "No active network traffic",
    otherTraffic: "Other traffic",
    footer: "Recent {count} processes + unassigned traffic · R to refresh"
  },
  zh_CN: {
    tooltip: "查看各进程的网络活动",
    title: "各进程网络活动",
    process: "进程",
    download: "下载",
    upload: "上传",
    readError: "无法读取网络流量",
    measuring: "正在测量网络流量…",
    noActivity: "暂无活跃网络流量",
    otherTraffic: "其他流量",
    footer: "近期 {count} 个进程及未归属流量 · 按 R 刷新"
  }
}

function localeKey(localeName) {
  var normalized = String(localeName || "")
    .replace(/-/g, "_")
    .toLowerCase()

  if (normalized === "zh"
      || normalized.indexOf("zh_cn") === 0
      || normalized.indexOf("zh_sg") === 0
      || normalized.indexOf("zh_hans") === 0) {
    return "zh_CN"
  }

  return "en"
}

function translate(localeName, key, values) {
  var language = localeKey(localeName)
  var catalog = messages[language] || messages.en
  var text = catalog[key] !== undefined ? catalog[key] : messages.en[key]
  if (text === undefined) return key

  var replacements = values || {}
  return String(text).replace(/\{([^}]+)\}/g, function(_, name) {
    return replacements[name] !== undefined ? String(replacements[name]) : "{" + name + "}"
  })
}
