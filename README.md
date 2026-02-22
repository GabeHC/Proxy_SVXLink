# Proxy_SVXLink

ENG :
Tools to automatic get a free proxy Echolink and configure ModuleEchoLink.conf

WARNING : you need to have lynx installed

Don't forget to add your svxlink restart command

Usage (Linux):
- autoProxy.sh: fetches a filtered public pi9 proxy list on port 8100 (pi9 proxies are chosen because they run without timeout/limits, even for sysop clients), tests a small shuffled sample for lowest latency, rewrites /etc/svxlink/svxlink.d/ModuleEchoLink.conf with PROXY_SERVER and PROXY_PASSWORD=public (lowercase confirmed in testing), then restarts svxlink.
- F1TZO_Get_SVXProxy.sh: legacy variant; add your own svxlink restart command at the bottom.

Usage (Windows EchoLink client):
- Branch: windows-echolink
- Script: windowsProxy.ps1 picks the best public pi9 proxy on port 8100, updates the exported EchoLink profile registry file (default: %USERPROFILE%\Documents\Echolink\profile.reg) with ProxyServer/ProxyPort/ProxyPassword (default password "public" in lowercase, matching tests), and imports it. Run in PowerShell:
	- Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
	- .\windowsProxy.ps1
	- Adjust -ProfilePath or -ProxyPassword if needed.
	- Restart EchoLink after running so it reloads the registry settings.

FR:
Script pour selectionner et configurer automatiquement un proxy public Echolink dans svxlink

Attention : vous devez avoir lynx d'installé

N'oubliez pas d'ajouter à la fin votre commande de restart svxlink

(c) GPL Michel F1TZO

Recent updates by BV5DJ.
