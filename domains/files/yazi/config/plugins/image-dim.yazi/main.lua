local function dims_text(entry)
    if not entry or not entry.w or not entry.h or entry.w == 0 or entry.h == 0 then
        return ""
    end

    return string.format(" %dx%d", entry.w, entry.h)
end

local get = ya.sync(function(st, url)
    return st.dims and st.dims[url]
end)

local commit = ya.sync(function(st, updates)
    st.dims = st.dims or {}
    for url, entry in pairs(updates) do
        st.dims[url] = entry
    end

    if next(updates) then
        ui.render()
    end
end)

local function fetch(_, job)
    return ya.co(function()
        local updates = {}

        for _, file in ipairs(job.files) do
            local url = tostring(file.url)
            local mtime = file.cha.mtime or 0
            local cached = get(url)

            if not file.cha.is_dir and (not cached or cached.mtime ~= mtime) then
                local info = ya.image_info(file.url)
                updates[url] = {
                    mtime = mtime,
                    w = info and info.w or 0,
                    h = info and info.h or 0,
                }
            end

            coroutine.yield(file, {})
        end

        commit(updates)
    end)
end

local function setup(st, opts)
    opts = opts or {}
    st.dims = st.dims or {}

    Linemode:children_add(function(self)
        return dims_text(st.dims[tostring(self._file.url)])
    end, opts.order or 1450)
end

return { setup = setup, fetch = fetch }
