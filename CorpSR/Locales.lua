--[[--------------------------------------------------------------------------
    CorpSR - traductions
    L anglais (enUS) sert de base : une cle absente d une langue retombe
    sur l anglais, puis sur la cle elle-meme. Les noms d objets viennent
    du client, deja dans la bonne langue (on ne garde que les itemIDs).
----------------------------------------------------------------------------]]

local _, ns = ...

local locales = {}

locales.enUS = {
    WIP = "version %s: the rules engine is ready, the window is coming. %d entries in the journal.",
    SONDE_START = "client probe running (a /roll 110 and a guild addon message)...",
    SONDE_DONE = "probe done: type /reload so the results are saved.",
}

locales.frFR = {
    WIP = "version %s : le moteur de règles est prêt, la fenêtre arrive. %d écritures dans le journal.",
    SONDE_START = "sonde du client en cours (un /roll 110 et un message d'addon à la guilde)...",
    SONDE_DONE = "sonde finie : fais /reload pour que les résultats soient enregistrés.",
}

locales.deDE = {
    WIP = "Version %s: Die Regel-Engine ist fertig, das Fenster folgt. %d Einträge im Journal.",
    SONDE_START = "Client-Test läuft (ein /roll 110 und eine Addon-Nachricht an die Gilde)...",
    SONDE_DONE = "Test beendet: Gib /reload ein, damit die Ergebnisse gespeichert werden.",
}

locales.esES = {
    WIP = "versión %s: el motor de reglas está listo, la ventana llegará pronto. %d entradas en el registro.",
    SONDE_START = "prueba del cliente en curso (un /roll 110 y un mensaje de addon a la hermandad)...",
    SONDE_DONE = "prueba terminada: escribe /reload para guardar los resultados.",
}
locales.esMX = locales.esES

locales.ptBR = {
    WIP = "versão %s: o motor de regras está pronto, a janela vem em seguida. %d entradas no registro.",
    SONDE_START = "teste do cliente em andamento (um /roll 110 e uma mensagem de addon para a guilda)...",
    SONDE_DONE = "teste concluído: digite /reload para salvar os resultados.",
}

locales.itIT = {
    WIP = "versione %s: il motore delle regole è pronto, la finestra arriva presto. %d voci nel registro.",
    SONDE_START = "test del client in corso (un /roll 110 e un messaggio di addon alla gilda)...",
    SONDE_DONE = "test finito: digita /reload per salvare i risultati.",
}

locales.ruRU = {
    WIP = "версия %s: движок правил готов, окно скоро появится. Записей в журнале: %d.",
    SONDE_START = "проверка клиента (/roll 110 и сообщение аддона в гильдию)...",
    SONDE_DONE = "проверка завершена: введите /reload, чтобы сохранить результаты.",
}

locales.zhCN = {
    WIP = "版本 %s：规则引擎已就绪，窗口即将推出。日志中有 %d 条记录。",
    SONDE_START = "正在检测客户端（一次 /roll 110 和一条发往公会的插件消息）……",
    SONDE_DONE = "检测完成：输入 /reload 以保存结果。",
}

locales.zhTW = {
    WIP = "版本 %s：規則引擎已就緒，視窗即將推出。日誌中有 %d 筆記錄。",
    SONDE_START = "正在檢測客戶端（一次 /roll 110 和一則發往公會的插件訊息）……",
    SONDE_DONE = "檢測完成：輸入 /reload 以儲存結果。",
}

locales.koKR = {
    WIP = "버전 %s: 규칙 엔진 준비 완료, 창은 곧 추가됩니다. 기록 %d개.",
    SONDE_START = "클라이언트 점검 중 (/roll 110 한 번과 길드 애드온 메시지)...",
    SONDE_DONE = "점검 완료: 결과를 저장하려면 /reload 를 입력하세요.",
}

ns.Locales = locales

local base = locales.enUS
local lang = GetLocale and GetLocale() or "enUS"
local chosen = locales[lang] or base

ns.L = setmetatable({}, {
    __index = function(_, k)
        local v = chosen[k]
        if v == nil then v = base[k] end
        if v == nil then v = k end
        return v
    end,
})
