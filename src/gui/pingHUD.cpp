#include "gui/pingHUD.h"

#include <algorithm>
#include <iomanip>
#include <sstream>

namespace {
static std::wstring buildPingText(Client *client)
{
	if (!client)
		return L"ping: -- ms";

	const float rtt_ms = std::max(0.0f, client->getRTT() * 1000.0f);
	std::wstringstream wss;
	wss << L"ping: " << std::fixed << std::setprecision(0) << rtt_ms << L" ms";
	return wss.str();
}
} // namespace

pingHUD::pingHUD(Client *client, const core::rect<s32> &rect) : CheatUIElement(rect), m_client(client) {}

void pingHUD::draw(video::IVideoDriver *driver, gui::IGUIFont *font, float dtime,
	ClientEnvironment &env, bool editing)
{
	(void)dtime;
	(void)env;
	if (!hudShouldRender(editing))
		return;

	if (!g_settings->getBool("ping") && !editing)
		return;
	if (!font)
		return;

	const std::wstring text = buildPingText(m_client);
	const core::dimension2d<u32> dim_u32 = font->getDimension(text.c_str());
	const core::dimension2d<s32> dim(dim_u32.Width, dim_u32.Height);

	core::rect<s32> draw_bounds = bounds;
	if (draw_bounds.getWidth() <= 0 || draw_bounds.getHeight() <= 0) {
		const s32 padding = 10;
		const s32 width = dim.Width + padding;
		const s32 height = dim.Height + padding;
		draw_bounds = core::rect<s32>(10, 45, 10 + width, 45 + height);
	}

	const video::SColor outline_color(255, 0, 0, 0);
	const video::SColor background_color(180, 25, 25, 25);
	const video::SColor text_color(255, 255, 255, 255);

	const bool draw_background = editing || g_settings->getBool("ping.background");
	if (draw_background) {
		driver->draw2DRectangle(background_color, draw_bounds);
		driver->draw2DRectangleOutline(draw_bounds, outline_color, 2);
	}

	const s32 x = draw_bounds.UpperLeftCorner.X + (draw_bounds.getWidth() - dim.Width) / 2;
	const s32 y = draw_bounds.UpperLeftCorner.Y + (draw_bounds.getHeight() - dim.Height) / 2;
	font->draw(text.c_str(), core::rect<s32>(x, y, x + dim.Width, y + dim.Height), text_color);
}
