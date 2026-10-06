.pragma library

// App<->window matching shared by the dock, its hover preview and its menu.
//
// A .pragma library cannot reach QML singletons, so the caller passes its
// DesktopEntries instance in.

function desktopId(app) {
    return String(app && app.id !== undefined && app.id !== null ? app.id : "").replace(/\.desktop$/i, "");
}

function resolveEntry(app, desktopEntries) {
    if (!app || !desktopEntries)
        return null;

    const id = desktopId(app);
    const exec = String(app.exec !== undefined && app.exec !== null ? app.exec : "");
    return desktopEntries.byId(id) || desktopEntries.heuristicLookup(id) || desktopEntries.heuristicLookup(exec)
            || null;
}

function matchCandidates(app, desktopEntries) {
    const out = [];

    function add(value) {
        const text = String(value === undefined || value === null ? "" : value).trim().toLowerCase();
        if (!text || out.indexOf(text) !== -1)
            return;
        out.push(text);
    }

    add(desktopId(app));
    add(app && app.exec);
    add(app && app.icon);

    const extras = (app && app.match) || [];
    for (let i = 0; i < extras.length; i++)
        add(extras[i]);

    const entry = resolveEntry(app, desktopEntries);
    if (entry) {
        add(entry.id);
        add(entry.startupClass);
        add(entry.icon);
    }

    return out;
}

function matchesToken(candidates, value) {
    const target = String(value === undefined || value === null ? "" : value).toLowerCase();
    if (!target)
        return false;

    for (let i = 0; i < candidates.length; i++) {
        if (target === candidates[i])
            return true;
    }

    for (let i = 0; i < candidates.length; i++) {
        const candidate = candidates[i];
        if (!candidate || candidate.length < 3)
            continue;
        if (target.endsWith("." + candidate) || candidate.endsWith("." + target))
            return true;
        if (candidate.length >= 4 && (target.indexOf(candidate) !== -1 || candidate.indexOf(target) !== -1))
            return true;
    }

    return false;
}

// Does this dock entry correspond to the given app id / window app_id?
function matchesAppId(app, appId, desktopEntries) {
    return matchesToken(matchCandidates(app, desktopEntries), appId);
}

function matchesWindow(app, window, desktopEntries) {
    return matchesToken(matchCandidates(app, desktopEntries), window && window.app_id);
}

// Do two dock entries describe the same application?
function sameApp(a, b, desktopEntries) {
    if (!a || !b)
        return false;
    return matchesAppId(a, b.id, desktopEntries) || matchesAppId(b, a.id, desktopEntries);
}
