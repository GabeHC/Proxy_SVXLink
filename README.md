# autoProxy (WinAutoProxy branch) – adapted from F1TZO

Windows-focused helper to pick the best public pi9 Echolink proxy and update the EchoLink profile registry file before the client starts. Original concept by Michel GACEM F1TZO; adapted and maintained independently. The Windows script writes the modern EchoLink hive `HKCU\SOFTWARE\K1RFD\EchoLink` (global Options and per-profile Options) and sets SelectedProfile/DefaultProfile; legacy Synergenics keys are no longer touched.

What it needs (Windows): PowerShell (Win7+), outbound access to http://www.echolink.org, and an exported EchoLink profile registry file. The script defaults to `%USERPROFILE%\Documents\Echolink\Proxyed.reg`; point `-ProfilePath` to whatever profile export you use. Default proxy password: public (lowercase). Pick the profile name you want EchoLink to start with (example: Proxyed).

How to run (manual):
- Open PowerShell (Run as Administrator recommended for reg import).
- Run:
  - Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  - .\windowsProxy.ps1 -ProfilePath "$env:USERPROFILE\Documents\Echolink\Proxyed.reg" -ProxyPassword public -ProfileName "Proxyed" -RestartEchoLink
- The script imports the reg file, writes K1RFD keys (Proxy/ProxyPW/ProxyPort/UseProxy) for the chosen profile, and restarts EchoLink with `-p<ProfileName>` so the UI shows the selected proxy.

How it works:
- Fetch the public proxy list from echolink.org, keep pi9 proxies on port 8100, exclude private/44.* addresses.
- Randomly sample a few proxies to limit test time.
- Measure latency (Test-NetConnection / ping) and pick the lowest RTT.
- Update ProxyServer/ProxyPort/ProxyPassword in the exported reg file, import it, and report the chosen proxy.

Run at startup (Task Scheduler, login trigger example):
- Create task → run with highest privileges.
- Trigger: At log on; add a 20–30s delay so network is ready.
- Action: Program `powershell.exe`
  - Arguments: `-NoProfile -ExecutionPolicy Bypass -File "C:\Users\Gabe\Documents\GitHub\Proxy_SVXLink\windowsProxy.ps1" -ProfilePath "$env:USERPROFILE\Documents\Echolink\profile.reg" -ProxyPassword public`
  - Start in: `C:\Users\Gabe\Documents\GitHub\Proxy_SVXLink`
- Optionally set another task to start EchoLink after this task completes.

License: GPL. Credit to Michel GACEM F1TZO for the original work. Recent updates by BV5DJ.

---

# autoProxy（WinAutoProxy 分支）

Windows 版工具，用來在啟動 EchoLink 前挑選最佳 pi9 公用代理並更新 EchoLink 註冊檔設定。原始概念來自 Michel GACEM F1TZO，本專案獨立維護。

需求（Windows）：PowerShell（Win7 以上），可連線 http://www.echolink.org，已匯出的 EchoLink 註冊檔（腳本預設使用 %USERPROFILE%\Documents\Echolink\Proxyed.reg，可用 -ProfilePath 指向你實際匯出的檔案）。預設代理密碼：public（小寫）。

手動執行：
- 以系統管理員開啟 PowerShell（建議，方便匯入註冊檔）。
- 執行：
  - Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  - .\windowsProxy.ps1 -ProfilePath "$env:USERPROFILE\Documents\Echolink\Proxyed.reg" -ProxyPassword public -ProfileName "Proxyed" -RestartEchoLink
- 完成後啟動 EchoLink，讓它載入更新後的代理設定。

運作原理：
- 從 echolink.org 抓公開代理，只保留 pi9、埠 8100，排除私網與 44.*。
- 隨機抽少量代理測試，縮短執行時間。
- 以 Test-NetConnection / ping 測延遲，選擇最低 RTT。
- 更新匯出的註冊檔中的 ProxyServer/ProxyPort/ProxyPassword，匯入後回報選到的代理。

開機/登入自動執行（工作排程器登入觸發範例）：
- 建立工作 → 以最高權限執行。
- 觸發：登入時；可設定延遲 20–30 秒，確保網路就緒。
- 動作：
  - 程式：powershell.exe
  - 引數：`-NoProfile -ExecutionPolicy Bypass -File "C:\Users\Gabe\Documents\GitHub\Proxy_SVXLink\windowsProxy.ps1" -ProfilePath "$env:USERPROFILE\Documents\Echolink\profile.reg" -ProxyPassword public`
  - 起始於：`C:\Users\Gabe\Documents\GitHub\Proxy_SVXLink`
- 可再加一個後續任務啟動 EchoLink，確保先跑完代理更新。

授權：GPL。致謝 Michel GACEM F1TZO 的原始工作；近期更新由 BV5DJ 完成。# autoProxy (adapted from F1TZO)

Tools to automatically get a free Echolink proxy and configure ModuleEchoLink.conf. Original concept by Michel GACEM F1TZO; adapted and maintained here as an independent project.

Requirements (Linux): lynx, gawk, grep, shuf, ping, sudo.

Branches:
- main: Linux scripts (autoProxy.sh, legacy F1TZO_Get_SVXProxy.sh).
- WinAutoProxy: PowerShell helper for Windows EchoLink.

Usage (Linux):
- autoProxy.sh: fetches a filtered public pi9 proxy list on port 8100 (pi9 proxies are chosen because they run without timeout/limits, even for sysop clients), tests a small shuffled sample for lowest latency, rewrites /etc/svxlink/svxlink.d/ModuleEchoLink.conf with PROXY_SERVER and PROXY_PASSWORD=public (lowercase confirmed in testing), then restarts svxlink.
- F1TZO_Get_SVXProxy.sh: legacy variant; add your own svxlink restart command at the bottom.

How it works (autoProxy.sh):
- Source: pulls the public proxy list from echolink.org, keeps only pi9 on port 8100, drops private/44.* addresses.
- Sample: shuffles and tests a small subset to reduce run time.
- Latency: pings each candidate, uses the lowest RTT; empty results are treated as failures.
- Selection: keeps the lowest-latency proxy as BPROXY and its latency as BLAT.
- Config: scans ModuleEchoLink.conf and replaces PROXY_SERVER and PROXY_PASSWORD=public via a temp file before overwriting the original.
- Apply: restarts svxlink with sudo to load the new config.

Usage (Windows EchoLink client):
- Branch: WinAutoProxy (PowerShell).
- Script: windowsProxy.ps1 picks the best public pi9 proxy on port 8100, updates the exported EchoLink profile registry file (default: %USERPROFILE%\Documents\Echolink\profile.reg) with ProxyServer/ProxyPort/ProxyPassword (default password "public" in lowercase, matching tests), and imports it. Run in PowerShell:
    - Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
    - .\windowsProxy.ps1
    - Adjust -ProfilePath or -ProxyPassword if needed.
    - Restart EchoLink after running so it reloads the registry settings.

License: GPL (credit to Michel GACEM F1TZO for the original work). Recent updates by BV5DJ.

---

# autoProxy（改編自 F1TZO）

這個工具用來自動取得免費 Echolink 代理，並設定 ModuleEchoLink.conf。原始概念來自 Michel GACEM F1TZO，本專案在此基礎上獨立維護。

需求（Linux）：lynx、gawk、grep、shuf、ping、sudo。

分支：
- main：Linux 腳本（autoProxy.sh、舊版 F1TZO_Get_SVXProxy.sh）。
- WinAutoProxy：供 Windows EchoLink 使用的 PowerShell 輔助腳本。

用法（Linux）：
- autoProxy.sh：抓取過濾後的 pi9 公用代理清單（埠 8100；pi9 無超時也無速率限制，系統管理員也適用），隨機抽樣少量節點測延遲，寫入 /etc/svxlink/svxlink.d/ModuleEchoLink.conf 的 PROXY_SERVER 與 PROXY_PASSWORD=public（實測需用小寫），然後重啟 svxlink。
- F1TZO_Get_SVXProxy.sh：舊版腳本，需自行在末端加入 svxlink 重啟指令。

原理（autoProxy.sh）：
- 來源：從 echolink.org 抓取公開代理，只保留 pi9、埠 8100，排除私網與 44.*。
- 抽樣：用 shuf 打散並只測少量代理，縮短執行時間。
- 測延遲：對候選執行 ping，取最小 RTT；若沒有結果視為失敗。
- 選擇：延遲最低者作為 BPROXY，並記錄延遲 BLAT。
- 配置：走訪 ModuleEchoLink.conf，替換 PROXY_SERVER 與 PROXY_PASSWORD=public，先寫暫存檔再覆蓋正式檔。
- 套用：以 sudo 停止並啟動 svxlink 以套用新設定。

用法（Windows EchoLink 用戶端）：
- 分支：WinAutoProxy（PowerShell）。
- 腳本 windowsProxy.ps1 會挑選延遲最低的 pi9 公用代理（埠 8100），更新並匯入你匯出的 EchoLink 登錄檔（預設 %USERPROFILE%\Documents\Echolink\profile.reg，預設密碼為小寫 "public"）。PowerShell 執行步驟：
    - Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
    - .\windowsProxy.ps1
    - 若需修改檔案路徑或密碼，可用參數覆寫。
    - 執行後重開 EchoLink 以重新載入設定。

授權：GPL（致謝 Michel GACEM F1TZO 的原始工作），近期更新由 BV5DJ 完成。# autoProxy (adapted from F1TZO)

Tools to automatically get a free Echolink proxy and configure ModuleEchoLink.conf. Original concept by Michel GACEM F1TZO; adapted and maintained here as an independent project.

Requirements (Linux): lynx、gawk、grep、shuf、ping、sudo、svxlink 重啟指令。

Reminder: 加上你自己的 svxlink 重啟指令。

Branches:
- main: Linux scripts (autoProxy.sh, legacy F1TZO_Get_SVXProxy.sh).
- WinAutoProxy: PowerShell helper for Windows EchoLink.

Usage (Linux):
- autoProxy.sh: fetches a filtered public pi9 proxy list on port 8100 (pi9 proxies are chosen because they run without timeout/limits, even for sysop clients), tests a small shuffled sample for lowest latency, rewrites /etc/svxlink/svxlink.d/ModuleEchoLink.conf with PROXY_SERVER and PROXY_PASSWORD=public (lowercase confirmed in testing), then restarts svxlink.
- F1TZO_Get_SVXProxy.sh: legacy variant; add your own svxlink restart command at the bottom.

Principles (autoProxy.sh):
- 來源：從 echolink.org 取得公開代理清單，僅取 pi9、埠 8100，排除私網段與 44.*。
- 抽樣：隨機打亂後取少量代理（shuf），降低測試時間。
- 測延遲：對每個候選以 ping 測試，取最小 rtt；空值視為失敗。
- 選擇：以最低延遲作為最佳代理（BPROXY），紀錄延遲（BLAT）。
- 配置：以 gawk/grep 遍歷 ModuleEchoLink.conf，替換 PROXY_SERVER 與 PROXY_PASSWORD=public，寫入暫存檔再覆蓋正式檔。
- 套用：使用 sudo 停止與啟動 svxlink 套用新設定。

Usage (Windows EchoLink client):
- Branch: WinAutoProxy (PowerShell).
- Script: windowsProxy.ps1 picks the best public pi9 proxy on port 8100, updates the exported EchoLink profile registry file (default: %USERPROFILE%\Documents\Echolink\profile.reg) with ProxyServer/ProxyPort/ProxyPassword (default password "public" in lowercase, matching tests), and imports it. Run in PowerShell:
    - Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
    - .\windowsProxy.ps1
    - Adjust -ProfilePath or -ProxyPassword if needed.
    - Restart EchoLink after running so it reloads the registry settings.

License: GPL (credit to Michel GACEM F1TZO for the original work). Recent updates by BV5DJ.

---

# autoProxy（改編自 F1TZO）

這個工具用來自動取得免費 Echolink 代理，並設定 ModuleEchoLink.conf。原始概念來自 Michel GACEM F1TZO，本專案在此基礎上獨立維護。

需求（Linux）：lynx、gawk、grep、shuf、ping、sudo，以及你的 svxlink 重啟指令。

提醒：別忘了加入你自己的 svxlink 重啟指令。

分支：
- main：Linux 腳本（autoProxy.sh、舊版 F1TZO_Get_SVXProxy.sh）。
- WinAutoProxy：供 Windows EchoLink 使用的 PowerShell 輔助腳本。

用法（Linux）：
- autoProxy.sh：抓取過濾後的 pi9 公用代理清單（埠 8100；pi9 無超時也無速率限制，系統管理員也適用），隨機抽樣少量節點測延遲，寫入 /etc/svxlink/svxlink.d/ModuleEchoLink.conf 的 PROXY_SERVER 與 PROXY_PASSWORD=public（實測需用小寫），然後重啟 svxlink。
- F1TZO_Get_SVXProxy.sh：舊版腳本，需自行在末端加入 svxlink 重啟指令。

原理（autoProxy.sh）：
- 來源：從 echolink.org 抓取公開代理清單，只取 pi9、埠 8100，排除私網與 44.*。
- 抽樣：以 shuf 打散並只測少量代理，降低耗時。
- 測延遲：對候選以 ping 測試，取最小 rtt；若測不到視為失敗。
- 選擇：以最低延遲作為最佳代理（BPROXY），同步記錄延遲（BLAT）。
- 配置：利用 gawk/grep 走訪 ModuleEchoLink.conf，替換 PROXY_SERVER 與 PROXY_PASSWORD=public，寫入暫存檔再覆蓋正式檔。
- 套用：使用 sudo 停止並啟動 svxlink 套用新設定。

用法（Windows EchoLink 用戶端）：
- 分支：WinAutoProxy（PowerShell）。
- 腳本 windowsProxy.ps1 會挑選延遲最低的 pi9 公用代理（埠 8100），更新並匯入你匯出的 EchoLink 登錄檔（腳本預設 %USERPROFILE%\Documents\Echolink\Proxyed.reg，可用 -ProfilePath 指向你的匯出檔；預設密碼為小寫 "public"）。PowerShell 執行步驟：
  - Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  - .\windowsProxy.ps1 -ProfilePath "$env:USERPROFILE\Documents\Echolink\Proxyed.reg" -ProxyPassword public -ProfileName "Proxyed" -RestartEchoLink
  - 若需修改檔案路徑或密碼，可用參數覆寫。
  - 腳本會寫入 K1RFD 註冊表（Proxy/ProxyPW/ProxyPort/UseProxy）並用 -pProfileName 重啟 EchoLink。

授權：GPL（致謝 Michel GACEM F1TZO 的原始工作），近期更新由 BV5DJ 完成。
