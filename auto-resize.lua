obs = obslua

maxsize = obs.vec2()
alignment = obs.vec2()
horizontal_align = 0.5
vertical_align = 0.5
check_sources = {}
filter = {
	pattern = "",
	inverted = false
}
all_scenes = false
keep_to_max = false

frame_cooldown = 0
frame = 0

scene_index = 0

-- cached items
old_scenes = nil
scenesource = nil
sceneitems = nil

function updateScene(scenesource)
	local scene = obs.obs_scene_from_source(scenesource)
	sceneitems = obs.obs_scene_enum_items(scene)

	local scenesize = obs.vec2()
	scenesize.x = obs.obs_source_get_width(scenesource)
	scenesize.y = obs.obs_source_get_height(scenesource)

	local max = obs.vec2()
	max.x = ((maxsize.x ~= 0) and math.min(maxsize.x, scenesize.x) or scenesize.x)
	max.y = ((maxsize.y ~= 0) and math.min(maxsize.y, scenesize.y) or scenesize.y)

	for i, sceneitem in ipairs(sceneitems) do
		-- prevent updating when unloading
		local itemsource = obs.obs_sceneitem_get_source(sceneitem)
		local sourcetype = obs.obs_source_get_unversioned_id(itemsource)
		local sourcename = obs.obs_source_get_name(itemsource)

		if arrayContains(check_sources, sourcename) == true then
			local iteminfo = obs.obs_transform_info()
			obs.obs_sceneitem_get_info(sceneitem, iteminfo)

			local size = obs.vec2()
			size.x = obs.obs_source_get_width(itemsource)
			size.y = obs.obs_source_get_height(itemsource)

			if size.x ~= 0 and size.y ~= 0 then
				local offsetScale = obs.vec2()
				offsetScale.x = math.max(math.min(size.x, max.x), keep_to_max and max.x or 0) / size.x;
				offsetScale.y = math.max(math.min(size.y, max.y), keep_to_max and max.y or 0) / size.y;
				offsetScale = math.min(offsetScale.x, offsetScale.y);

				local itemsize = obs.vec2()
				itemsize.x = size.x * offsetScale;
				itemsize.y = size.y * offsetScale;

				iteminfo.scale.x = offsetScale;
				iteminfo.scale.y = offsetScale;

				iteminfo.pos.x = (alignment.x * scenesize.x) - (alignment.x * itemsize.x);
				iteminfo.pos.y = (alignment.y * scenesize.y) - (alignment.y * itemsize.y);

				obs.obs_sceneitem_set_info(sceneitem, iteminfo)
			end
		end
	end

	obs.sceneitem_list_release(sceneitems)
	sceneitems = nil
end

function filterAndGetSceneIndexes(names)
	local result = {}

	local pattern = filter.pattern
	local inverted = filter.inverted

	try(function()
		for sceneIndex = 1, #names, 1 do
			if (names[sceneIndex]:find(pattern) == nil) == inverted then
				table.insert(result, sceneIndex)
			end
		end
	end, nil)

	for sceneIndex = 1, #names, 1 do
		if patternSafe == true then
			if (names[sceneIndex]:find(pattern) == nil) == inverted then
				table.insert(result, sceneIndex)
			end
		end
	end

	return result
end

function obs_frontend_source_list_free(sources)
	for _, value in ipairs(sources) do
		obs.obs_source_release(value)
	end
end

--- QUICK IMPORTS ---

-- Copied from https://github.com/midnight-studios/obs-lua/blob/69a56537aafc58d3fdf91959695576e91bdb6e1a/StopWatch.lua#L945
function obs_data_array_to_table( set, item )
	local array = obs.obs_data_get_array( set, item )
	local count = obs.obs_data_array_count( array )
	local list = {}
	
	for i = 1, count do 
		local array_item = obs.obs_data_array_item( array, i-1 )
		local value = obs.obs_data_get_string( array_item, "value" )
		table.insert( list, value )
	end
	
	obs.obs_data_array_release( array )
	return list
end

-- Copied from https://stackoverflow.com/a/33511182
function arrayContains(arr, val)
	for _, value in ipairs(arr) do
		if value == val then
			return true
		end
	end

	return false
end

-- Copied from https://www.lua.org/gems/lpg113.pdf
function try(f, catch_f)
	local status, exception = pcall(f)
	if not status then
		if catch_f ~= nil then
			catch_f(exception)
		end
	end
end

--- SCRIPT DEFAULTS ---

function script_properties()
	local props = obs.obs_properties_create()

	obs.obs_properties_add_int(props, "max_source_width", "Max source width *(0px to disable)", 0, 3840, 1)
	obs.obs_properties_add_int(props, "max_source_height", "Max source height *(0px to disable)", 0, 2160, 1)
	obs.obs_properties_add_float_slider(props, "vertical_align", "Vertical alignment (screen align)", 0, 1, 0.001)
	obs.obs_properties_add_float_slider(props, "horizontal_align", "Horizontal alignment (screen align)", 0, 1, 0.001)
	obs.obs_properties_add_editable_list(props, "check_sources", "Sources to check", obs.OBS_EDITABLE_LIST_TYPE_STRINGS, "", "")
	obs.obs_properties_add_text(props, "filter", "Filter scenes *(using lua patterns)", obs.OBS_TEXT_DEFAULT )
	obs.obs_properties_add_bool(props, "filter_inverted", "Invert filter *(not include above)")
	obs.obs_properties_add_bool(props, "all_scenes", "All scenes instead of current *(slower)")
	obs.obs_properties_add_bool(props, "keep_to_max", "Always fit to screen")
	obs.obs_properties_add_int(props, "frame_cooldown", "Frame cooldown (skip x frames)", 0, 1000, 1)

	return props
end

function script_defaults(settings)
	obs.obs_data_set_default_int(settings, "max_source_width", 0)
	obs.obs_data_set_default_int(settings, "max_source_height", 0)
	obs.obs_data_set_default_double(settings, "horizontal_align", 0.5)
	obs.obs_data_set_default_double(settings, "vertical_align", 0.5)
	obs.obs_data_set_default_string(settings, "filter", "^%[")
	obs.obs_data_set_default_bool(settings, "filter_inverted", false)
	obs.obs_data_set_default_bool(settings, "all_scenes", true)
	obs.obs_data_set_default_bool(settings, "keep_to_max", true)
	obs.obs_data_set_default_int(settings, "frame_cooldown", 60)
end

function script_description()
	return "<p>Adds the ability to automatically resize scene sources if they don't fit the screen.<br><i>Made by <a href=\"https://github.com/leialoha\">Leialoha</a> (Version: v1.1.0)</i></p>"
end

function script_update(settings)
	maxsize.x = obs.obs_data_get_int(settings, "max_source_width")
	maxsize.y = obs.obs_data_get_int(settings, "max_source_height")
	alignment.x = obs.obs_data_get_double(settings, "horizontal_align")
	alignment.y = obs.obs_data_get_double(settings, "vertical_align")
	check_sources = obs_data_array_to_table(settings, "check_sources")
	filter.pattern = obs.obs_data_get_string(settings, "filter")
	filter.inverted = obs.obs_data_get_bool(settings, "filter_inverted")
	all_scenes = obs.obs_data_get_bool(settings, "all_scenes")
	keep_to_max = obs.obs_data_get_bool(settings, "keep_to_max")
	frame_cooldown = obs.obs_data_get_int(settings, "frame_cooldown")
end

function script_load(settings)
	script_update(settings)
end

function script_unload()
	if old_scenes ~= nil then obs_frontend_source_list_free(old_scenes) end
	if scenesource ~= nil then obs.obs_source_release(scenesource) end
	if sceneitems ~= nil then obs.sceneitem_list_release(sceneitems) end
end

function script_tick(seconds)
	if frame_cooldown ~= 0 then
		frame = math.fmod(frame+1, frame_cooldown+1)
		if frame ~= 0 then return end
	end

	if all_scenes then
		scenes = obs.obs_frontend_get_scenes()
		local scene_names = obs.obs_frontend_get_scene_names()
		local scene_indexes = filterAndGetSceneIndexes(scene_names)

		if #scene_indexes ~= 0 then
			scene_index = math.fmod(scene_index+1, #scene_indexes)
			updateScene(scenes[scene_indexes[scene_index+1]])
		end

		obs_frontend_source_list_free(scenes)
		scenes = nil
	else
		scenesource = obs.obs_frontend_get_current_scene()
		updateScene(scenesource)
	
		obs.obs_source_release(scenesource)
		scenesource = nil
	end
end
