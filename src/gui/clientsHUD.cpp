#include "gui/clientsHUD.h"

#include "client/content_cao.h"
#include "client/localplayer.h"
#include "util/string.h"
#include <algorithm>
#include <cmath>
#include <sstream>

namespace {
static std::vector<std::wstring> buildClientLines(ClientEnvironment &env)
{
	std::vector<std::wstring> lines;
	const std::set<std::string> &names = env.getPlayerNames();

	std::wstringstream header;
	header << L"client list (" << names.size() << L")";
	lines.push_back(header.str());

	for (const std::string &name : names)
		lines.push_back(utf8_to_wide(name));

	return lines;
}

static std::vector<std::wstring> buildNearbyLines(ClientEnvironment &env, float radius)
{
	struct Entry {
		std::wstring text;
		float distance;
	};
	std::vector<Entry> entries;
	LocalPlayer *lp = env.getLocalPlayer();
	if (!lp)
		return {L"nearby (0)"};

	const v3f origin = lp->getPosition();
	std::vector<DistanceSortedActiveObject> objects;
	env.getAllActiveObjects(origin, objects);

	for (const auto &sortedObj : objects) {
		auto *cao = sortedObj.obj;
		auto *obj = dynamic_cast<GenericCAO *>(cao);
		if (!obj || !obj->isPlayer() || obj->isLocalPlayer())
			continue;

		const float dist_blocks = origin.getDistanceFrom(obj->getPosition()) / BS;
		if (dist_blocks > radius)
			continue;

		std::wstringstream line;
		line << utf8_to_wide(obj->getName());
		if (g_settings->getBool("nearby_clients.distance"))
			line << L" [" << static_cast<int>(std::round(dist_blocks)) << L" blocks away]";
		if (g_settings->getBool("nearby_clients.health")) {
			const u16 hp = obj->getHp();
			const u16 hp_max = obj->getProperties().hp_max;
			if (hp_max > 0)
				line << L" (" << hp << L"/" << hp_max << L")";
		}
		entries.push_back({line.str(), dist_blocks});
	}

	std::sort(entries.begin(), entries.end(), [](
		const auto &a, const auto &b) { return a.distance < b.distance; });

	std::vector<std::wstring> lines;
	std::wstringstream header;
	header << L"nearby (" << entries.size() << L")";
	lines.push_back(header.str());

	for (const auto &entry : entries)
		lines.push_back(entry.text);

	return lines;
}
} // namespace

clientsHUD::clientsHUD(const core::rect<s32> &rect) : CheatUIElement(rect) {}

std::vector<std::wstring> clientsHUD::buildLines(ClientEnvironment &env) const
{
	std::vector<std::wstring> lines = buildClientLines(env);
	std::vector<std::wstring> nearby = buildNearbyLines(env, 128.0f);
	if (nearby.size() > 1) {
		lines.emplace_back(L"");
		lines.insert(lines.end(), nearby.begin(), nearby.end());
	}
	return lines;
}

core::rect<s32> clientsHUD::calculateBounds(video::IVideoDriver *driver,
	gui::IGUIFont *font, const std::vector<std::wstring> &lines) const
{
	const core::dimension2d<u32> screensize = driver->getScreenSize();
	s32 max_width = 0;
	s32 line_height = 0;

	for (const std::wstring &line : lines) {
		if (!font)
			break;
		const core::dimension2d<u32> dim = font->getDimension(line.c_str());
		max_width = std::max(max_width, static_cast<s32>(dim.Width));
		line_height = std::max(line_height, static_cast<s32>(dim.Height));
	}

	if (line_height <= 0)
		line_height = font ? static_cast<s32>(font->getDimension(L"M").Height) : 16;
	if (max_width <= 0)
		max_width = 140;

	const s32 padding = 10;
	const s32 width = max_width + padding;
	const s32 height = std::max<s32>(line_height * static_cast<s32>(lines.size()), line_height) + padding;
	const s32 x = screensize.Width > static_cast<u32>(width + 5)
		? static_cast<s32>(screensize.Width) - width - 5
		: 5;
	const s32 y = 5;

	return core::rect<s32>(x, y, x + width, y + height);
}

void clientsHUD::draw(video::IVideoDriver *driver, gui::IGUIFont *font, float dtime,
	ClientEnvironment &env, bool editing)
{
	(void)dtime;
	if (!hudShouldRender(editing))
		return;

	if (!g_settings->getBool("clients") && !editing)
		return;
	if (!font)
		return;

	m_cache_timer += dtime;
	if (editing || !m_cache_valid || m_cache_timer >= 0.35f) {
		m_cached_lines = buildLines(env);
		m_cache_valid = true;
		m_cache_timer = 0.0f;
	}

	const std::vector<std::wstring> lines = m_cached_lines;
	core::rect<s32> draw_bounds = bounds;
	if (draw_bounds.getWidth() <= 0 || draw_bounds.getHeight() <= 0)
		draw_bounds = calculateBounds(driver, font, lines);

	const video::SColor outline_color(255, 0, 0, 0);
	const video::SColor background_color(180, 25, 25, 25);
	const video::SColor text_color(255, 255, 255, 255);

	const bool draw_background = editing || g_settings->getBool("clients.background");
	if (draw_background) {
		driver->draw2DRectangle(background_color, draw_bounds);
		driver->draw2DRectangleOutline(draw_bounds, outline_color, 2);
	}

	s32 y = draw_bounds.UpperLeftCorner.Y + 5;
	for (const std::wstring &line : lines) {
		const core::dimension2d<u32> dim_u32 = font->getDimension(line.c_str());
		const core::dimension2d<s32> dim(dim_u32.Width, dim_u32.Height);
		const s32 x = draw_bounds.UpperLeftCorner.X + 5;
		font->draw(line.c_str(), core::rect<s32>(x, y, x + dim.Width, y + dim.Height), text_color);
		y += dim.Height;
	}
}
