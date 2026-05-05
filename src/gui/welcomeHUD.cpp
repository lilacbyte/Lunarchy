#include "gui/welcomeHUD.h"

#include "client/localplayer.h"
#include "util/string.h"
#include <algorithm>
#include <optional>
#include <sstream>

namespace {
static std::string replace_all(std::string value, const std::string &from, const std::string &to)
{
	if (from.empty())
		return value;

	size_t pos = 0;
	while ((pos = value.find(from, pos)) != std::string::npos) {
		value.replace(pos, from.size(), to);
		pos += to.size();
	}
	return value;
}

static std::wstring buildWelcomeLine(const std::string &template_text, const std::string &player_name)
{
	std::string resolved = template_text.empty() ? "welcome, <%player%> :^)" : template_text;
	resolved = replace_all(resolved, "%player%", player_name);
	resolved = replace_all(resolved, "%name%", player_name);
	resolved = replace_all(resolved, "$1", player_name);
	return utf8_to_wide(resolved);
}

static std::vector<std::wstring> splitLines(const std::wstring &text)
{
	std::vector<std::wstring> lines;
	size_t start = 0;
	while (start <= text.size()) {
		const size_t end = text.find(L'\n', start);
		std::wstring line = text.substr(start, end == std::wstring::npos ? std::wstring::npos : end - start);
		if (!line.empty() && line.back() == L'\r')
			line.pop_back();
		lines.push_back(line);
		if (end == std::wstring::npos)
			break;
		start = end + 1;
	}
	if (lines.empty())
		lines.push_back(L"welcome");
	return lines;
}

static std::optional<video::SColor> readWelcomeColor()
{
	video::SColor color(255, 255, 255, 255);
	if (parseColorString(g_settings->get("welcome.color"), color, true, 0xff))
		return color;
	return std::nullopt;
}

static s32 getAlignedX(const core::rect<s32> &bounds, s32 line_width)
{
	const std::string align = g_settings->get("welcome.align");
	const s32 left = bounds.UpperLeftCorner.X + 6;
	const s32 right = bounds.LowerRightCorner.X - 6;

	if (align == "Left")
		return left;
	if (align == "Center")
		return bounds.UpperLeftCorner.X + (bounds.getWidth() - line_width) / 2;

	return right - line_width;
}
} // namespace

WelcomeHUD::WelcomeHUD(const core::rect<s32> &rect) : CheatUIElement(rect) {}

core::rect<s32> WelcomeHUD::calculateBounds(video::IVideoDriver *driver,
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
		max_width = 220;

	const s32 padding = 12;
	const s32 min_width = std::clamp<s32>(static_cast<s32>(screensize.Width / 4), 260, 420);
	const s32 width = std::max(max_width + padding, min_width);
	const s32 height = std::max<s32>(line_height * static_cast<s32>(lines.size()), line_height) + padding;
	const s32 x = 10;
	const s32 y = screensize.Height > static_cast<u32>(height + 5)
		? 10
		: 5;

	return core::rect<s32>(x, y, x + width, y + height);
}

void WelcomeHUD::draw(video::IVideoDriver *driver, gui::IGUIFont *font, float dtime,
	ClientEnvironment &env, bool editing)
{
	(void)dtime;
	if (!hudShouldRender(editing))
		return;

	if (!g_settings->getBool("welcome") && !editing)
		return;
	if (!font)
		return;

	LocalPlayer *player = env.getLocalPlayer();
	const std::string player_name = player ? player->getName() : "player";
	const std::string template_text = g_settings->get("welcome.message");
	const std::wstring welcome_line = buildWelcomeLine(template_text, player_name);
	const std::vector<std::wstring> lines = splitLines(welcome_line);

	core::rect<s32> draw_bounds = bounds;
	if (draw_bounds.getWidth() <= 0 || draw_bounds.getHeight() <= 0)
		draw_bounds = calculateBounds(driver, font, lines);

	const video::SColor outline_color(255, 0, 0, 0);
	const video::SColor background_color(180, 25, 25, 25);
	const video::SColor text_color = readWelcomeColor().value_or(video::SColor(255, 255, 255, 255));

	const bool draw_background = editing || g_settings->getBool("welcome.background");
	if (draw_background) {
		driver->draw2DRectangle(background_color, draw_bounds);
		driver->draw2DRectangleOutline(draw_bounds, outline_color, 2);
	}

	s32 y = draw_bounds.UpperLeftCorner.Y + 6;
	for (const std::wstring &line : lines) {
		const core::dimension2d<u32> dim_u32 = font->getDimension(line.c_str());
		const core::dimension2d<s32> dim(dim_u32.Width, dim_u32.Height);
		const s32 x = getAlignedX(draw_bounds, dim.Width);
		font->draw(line.c_str(), core::rect<s32>(x, y, x + dim.Width, y + dim.Height), text_color);
		y += dim.Height;
	}
}
