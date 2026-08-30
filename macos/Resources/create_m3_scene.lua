obs = obslua

local screen_scene_name = "DAAK M3 Ekran"
local screen_source_name = "M3 Ekran ve Ses"
local studio_scene_name = "DAAK Ekran + Kameralar"
local phone_scene_name = "DAAK Telefon Tam"
local mac_scene_name = "DAAK M3 Kamera Tam"
local vertical_scene_name = "Escena vertical"
local phone_source_name = "DAAK Telefon Kamerası"
local mac_source_name = "DAAK M3 Kamerası"

local setup_timer_active = false
local sync_timer_active = false
local display_uuid = ""

local function read_local_camera_config()
    local values = {}
    local home = os.getenv("HOME")
    if home == nil then
        return values
    end
    local path = home .. "/Library/Application Support/DAAK/Broadcast/camera-sources.conf"
    local handle = io.open(path, "r")
    if handle == nil then
        return values
    end
    for line in handle:lines() do
        local key, value = string.match(line, "^([%w_]+)=(.*)$")
        if key ~= nil and value ~= nil then
            values[key] = value
        end
    end
    handle:close()
    return values
end

local function selected_size()
    local home = os.getenv("HOME")
    if home == nil then
        return 2560, 1440
    end
    local handle = io.open(home .. "/Library/Application Support/DAAK/Broadcast/quality-profile", "r")
    if handle ~= nil then
        local quality = handle:read("*l")
        handle:close()
        if quality == "1080p60" then
            return 1920, 1080
        end
    end
    return 2560, 1440
end

local function selected_vertical_layout()
    local home = os.getenv("HOME")
    if home == nil then
        return "screen-phone"
    end
    local handle = io.open(home .. "/Library/Application Support/DAAK/Broadcast/vertical-layout-profile", "r")
    if handle ~= nil then
        local layout = handle:read("*l")
        handle:close()
        if layout == "screen-phone" or layout == "screen-mac" or layout == "triple" then
            return layout
        end
    end
    return "screen-phone"
end

local function selected_capture_mode()
    local home = os.getenv("HOME")
    if home == nil then
        return "window"
    end
    local handle = io.open(home .. "/Library/Application Support/DAAK/Broadcast/capture-mode-profile", "r")
    if handle ~= nil then
        local mode = handle:read("*l")
        handle:close()
        if mode == "display" then
            return mode
        end
    end
    return "window"
end

local function matching_window_id(source, values)
    local configured = tonumber(values.capture_window_id or "") or 0
    local owner = values.capture_window_owner or ""
    local title = values.capture_window_title or ""
    if owner == "" or title == "" then
        return configured
    end
    local properties = obs.obs_source_properties(source)
    if properties == nil then
        return configured
    end
    local window_property = obs.obs_properties_get(properties, "window")
    if window_property ~= nil then
        local expected = "[" .. owner .. "] " .. title
        local count = obs.obs_property_list_item_count(window_property)
        for index = 0, count - 1 do
            if obs.obs_property_list_item_name(window_property, index) == expected then
                configured = obs.obs_property_list_item_int(window_property, index)
                break
            end
        end
    end
    obs.obs_properties_destroy(properties)
    return configured
end

local function ensure_screen_source(values)
    local source = obs.obs_get_source_by_name(screen_source_name)
    local mode = selected_capture_mode()
    if source == nil then
        local settings = obs.obs_data_create()
        if mode == "display" then
            obs.obs_data_set_int(settings, "type", 0)
            obs.obs_data_set_string(settings, "display_uuid", display_uuid)
        else
            obs.obs_data_set_int(settings, "type", 1)
            obs.obs_data_set_int(settings, "window", tonumber(values.capture_window_id or "") or 0)
        end
        obs.obs_data_set_bool(settings, "show_cursor", true)
        obs.obs_data_set_bool(settings, "hide_obs", true)
        obs.obs_data_set_bool(settings, "show_empty_names", false)
        obs.obs_data_set_bool(settings, "show_hidden_windows", false)
        source = obs.obs_source_create("screen_capture", screen_source_name, settings, nil)
        obs.obs_data_release(settings)
        return source
    end
    local settings = obs.obs_source_get_settings(source)
    if mode == "display" then
        local selected_display_uuid = display_uuid
        if selected_display_uuid == "" then
            selected_display_uuid = obs.obs_data_get_string(settings, "display_uuid")
        end
        obs.obs_data_set_int(settings, "type", 0)
        obs.obs_data_set_string(settings, "display_uuid", selected_display_uuid)
        obs.obs_data_erase(settings, "window")
    else
        obs.obs_data_set_int(settings, "type", 1)
        obs.obs_data_set_int(settings, "window", matching_window_id(source, values))
        obs.obs_data_erase(settings, "display_uuid")
    end
    obs.obs_data_set_bool(settings, "show_cursor", true)
    obs.obs_data_set_bool(settings, "hide_obs", true)
    obs.obs_data_set_bool(settings, "show_empty_names", false)
    obs.obs_data_set_bool(settings, "show_hidden_windows", false)
    obs.obs_source_update(source, settings)
    obs.obs_data_release(settings)
    return source
end

local function ensure_camera_source(source_name, device_id, device_name)
    local source = obs.obs_get_source_by_name(source_name)
    if source ~= nil then
        return source
    end
    if device_id == nil or device_id == "" then
        return nil
    end
    local settings = obs.obs_data_create()
    obs.obs_data_set_string(settings, "device", device_id)
    obs.obs_data_set_string(settings, "device_name", device_name or source_name)
    obs.obs_data_set_bool(settings, "use_preset", true)
    obs.obs_data_set_string(settings, "preset", "AVCaptureSessionPreset1920x1080")
    obs.obs_data_set_bool(settings, "buffering", false)
    source = obs.obs_source_create("av_capture_input", source_name, settings, nil)
    obs.obs_data_release(settings)
    if source ~= nil then
        obs.obs_source_set_volume(source, 0.0)
    end
    return source
end

local function ensure_main_scene(name)
    local scene = obs.obs_get_scene_by_name(name)
    if scene ~= nil then
        return scene, nil, false
    end
    scene = obs.obs_scene_create(name)
    return scene, nil, true
end

local function set_item(scene, source, x, y, width, height, bounds_type)
    if scene == nil or source == nil then
        return
    end
    local item = obs.obs_scene_find_source(scene, obs.obs_source_get_name(source))
    if item == nil then
        item = obs.obs_scene_add(scene, source)
    end
    local position = obs.vec2()
    position.x = x
    position.y = y
    local bounds = obs.vec2()
    bounds.x = width
    bounds.y = height
    obs.obs_sceneitem_set_alignment(item, 5)
    obs.obs_sceneitem_set_pos(item, position)
    obs.obs_sceneitem_set_bounds_type(item, bounds_type)
    obs.obs_sceneitem_set_bounds_alignment(item, 0)
    obs.obs_sceneitem_set_bounds_crop(item, bounds_type == obs.OBS_BOUNDS_SCALE_OUTER)
    obs.obs_sceneitem_set_bounds(item, bounds)
    obs.obs_sceneitem_set_visible(item, true)
end

local function set_item_visibility(scene, source, visible)
    if scene == nil or source == nil then
        return
    end
    local item = obs.obs_scene_find_source(scene, obs.obs_source_get_name(source))
    if item ~= nil then
        obs.obs_sceneitem_set_visible(item, visible)
    end
end

local function release_scene(scene, source, created)
    if source ~= nil then
        obs.obs_source_release(source)
    elseif created and scene ~= nil then
        obs.obs_scene_release(scene)
    end
end

local function configure_studio_scenes(screen, phone, mac)
    local width, height = selected_size()
    local margin = math.floor(width * 0.01875)

    local scene, source, created = ensure_main_scene(screen_scene_name)
    set_item(scene, screen, 0, 0, width, height, obs.OBS_BOUNDS_SCALE_INNER)
    release_scene(scene, source, created)

    scene, source, created = ensure_main_scene(studio_scene_name)
    set_item(scene, screen, 0, 0, width, height, obs.OBS_BOUNDS_SCALE_INNER)
    if phone ~= nil then
        local camera_width = math.floor(width * 0.34)
        local camera_height = math.floor(camera_width * 9 / 16)
        set_item(scene, phone, width - camera_width - margin, height - camera_height - margin,
                 camera_width, camera_height, obs.OBS_BOUNDS_SCALE_OUTER)
    end
    if mac ~= nil then
        local camera_width = math.floor(width * 0.22)
        local camera_height = math.floor(camera_width * 9 / 16)
        set_item(scene, mac, margin, height - camera_height - margin,
                 camera_width, camera_height, obs.OBS_BOUNDS_SCALE_OUTER)
    end
    release_scene(scene, source, created)

    if phone ~= nil then
        scene, source, created = ensure_main_scene(phone_scene_name)
        set_item(scene, phone, 0, 0, width, height, obs.OBS_BOUNDS_SCALE_OUTER)
        release_scene(scene, source, created)
    end

    if mac ~= nil then
        scene, source, created = ensure_main_scene(mac_scene_name)
        set_item(scene, mac, 0, 0, width, height, obs.OBS_BOUNDS_SCALE_OUTER)
        release_scene(scene, source, created)
    end
end

local function current_vertical_layout()
    local transition = obs.obs_get_output_source(0)
    if transition == nil then
        return selected_vertical_layout(), ""
    end
    local current = obs.obs_transition_get_active_source(transition)
    local name = obs.obs_source_get_name(current or transition)
    if current ~= nil then
        obs.obs_source_release(current)
    end
    obs.obs_source_release(transition)
    if name == screen_scene_name then
        return "screen-only", name
    elseif name == phone_scene_name then
        return "phone-only", name
    elseif name == mac_scene_name then
        return "mac-only", name
    end
    return selected_vertical_layout(), name
end

local function configure_vertical_scene(screen, phone, mac, layout)
    local canvas = obs.obs_get_canvas_by_name("Aitum Vertical")
    if canvas == nil then
        obs.script_log(obs.LOG_WARNING, "Aitum Vertical tuvali henüz hazır değil")
        return false
    end
    local scene_source = obs.obs_canvas_get_source_by_name(canvas, vertical_scene_name)
    if scene_source == nil then
        obs.script_log(obs.LOG_WARNING, "Aitum Vertical sahnesi henüz hazır değil")
        obs.obs_canvas_release(canvas)
        return false
    end
    local scene = obs.obs_scene_from_source(scene_source)
    if layout == "screen-only" then
        set_item(scene, screen, 0, 0, 1080, 1920, obs.OBS_BOUNDS_SCALE_INNER)
        set_item_visibility(scene, phone, false)
        set_item_visibility(scene, mac, false)
    elseif layout == "phone-only" then
        set_item_visibility(scene, screen, false)
        if phone ~= nil then
            set_item(scene, phone, 0, 0, 1080, 1920, obs.OBS_BOUNDS_SCALE_OUTER)
        end
        set_item_visibility(scene, mac, false)
    elseif layout == "mac-only" then
        set_item_visibility(scene, screen, false)
        set_item_visibility(scene, phone, false)
        if mac ~= nil then
            set_item(scene, mac, 0, 0, 1080, 1920, obs.OBS_BOUNDS_SCALE_OUTER)
        end
    elseif layout == "triple" then
        set_item(scene, screen, 0, 0, 1080, 608, obs.OBS_BOUNDS_SCALE_INNER)
        if phone ~= nil then
            set_item(scene, phone, 0, 608, 1080, 720, obs.OBS_BOUNDS_SCALE_OUTER)
        end
        if mac ~= nil then
            set_item(scene, mac, 0, 1328, 1080, 592, obs.OBS_BOUNDS_SCALE_OUTER)
        end
    elseif layout == "screen-mac" then
        set_item(scene, screen, 0, 0, 1080, 720, obs.OBS_BOUNDS_SCALE_INNER)
        set_item_visibility(scene, phone, false)
        if mac ~= nil then
            set_item(scene, mac, 0, 720, 1080, 1200, obs.OBS_BOUNDS_SCALE_OUTER)
        end
    else
        set_item(scene, screen, 0, 0, 1080, 720, obs.OBS_BOUNDS_SCALE_INNER)
        if phone ~= nil then
            set_item(scene, phone, 0, 720, 1080, 1200, obs.OBS_BOUNDS_SCALE_OUTER)
        end
        set_item_visibility(scene, mac, false)
    end
    obs.script_log(obs.LOG_INFO, "DAAK dikey düzeni: " .. layout)
    obs.obs_source_release(scene_source)
    obs.obs_canvas_release(canvas)
    return true
end

local function sync_vertical_scene()
    if sync_timer_active then
        obs.timer_remove(sync_vertical_scene)
        sync_timer_active = false
    end
    local screen = obs.obs_get_source_by_name(screen_source_name)
    local phone = obs.obs_get_source_by_name(phone_source_name)
    local mac = obs.obs_get_source_by_name(mac_source_name)
    if screen == nil then
        if phone ~= nil then obs.obs_source_release(phone) end
        if mac ~= nil then obs.obs_source_release(mac) end
        return
    end
    local layout, horizontal_name = current_vertical_layout()
    if configure_vertical_scene(screen, phone, mac, layout) then
        obs.script_log(obs.LOG_INFO, "DAAK yatay sahne eşlemesi: " .. horizontal_name .. " -> " .. layout)
    end
    obs.obs_source_release(screen)
    if phone ~= nil then obs.obs_source_release(phone) end
    if mac ~= nil then obs.obs_source_release(mac) end
end

local function on_frontend_event(event)
    if event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
        if sync_timer_active then
            obs.timer_remove(sync_vertical_scene)
        end
        sync_timer_active = true
        obs.timer_add(sync_vertical_scene, 150)
    end
end

local function ensure_sources_and_scenes()
    local values = read_local_camera_config()
    local screen = ensure_screen_source(values)
    local phone = ensure_camera_source(phone_source_name, values.phone_camera_id, values.phone_camera_name)
    local mac = ensure_camera_source(mac_source_name, values.mac_camera_id, values.mac_camera_name)

    if screen == nil then
        obs.script_log(obs.LOG_ERROR, "DAAK M3 ekran kaynağı oluşturulamadı")
        return
    end

    configure_studio_scenes(screen, phone, mac)
    local layout, horizontal_name = current_vertical_layout()
    local vertical_ready = configure_vertical_scene(screen, phone, mac, layout)

    obs.obs_source_release(screen)
    if phone ~= nil then obs.obs_source_release(phone) end
    if mac ~= nil then obs.obs_source_release(mac) end

    if vertical_ready then
        obs.script_log(obs.LOG_INFO, "DAAK yatay sahne eşlemesi: " .. horizontal_name .. " -> " .. layout)
        obs.script_log(obs.LOG_INFO, "DAAK yatay/dikey kamera stüdyosu hazır")
        obs.timer_remove(ensure_sources_and_scenes)
        setup_timer_active = false
    end
end

function script_description()
    return "DAAK ekranı, M3 kamerası ve telefon kamerası için yatay ve Aitum Vertical sahnelerini idempotent biçimde hazırlar."
end

function script_load(settings)
    display_uuid = obs.obs_data_get_string(settings, "display_uuid")
    obs.obs_frontend_add_event_callback(on_frontend_event)
    setup_timer_active = true
    obs.timer_add(ensure_sources_and_scenes, 1500)
end

function script_unload()
    obs.obs_frontend_remove_event_callback(on_frontend_event)
    if setup_timer_active then
        obs.timer_remove(ensure_sources_and_scenes)
    end
    if sync_timer_active then
        obs.timer_remove(sync_vertical_scene)
    end
end
