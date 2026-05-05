#include "gui/coordsHUD.h"

#include <algorithm>
#include <vector>

coordsHUD::coordsHUD(const core::rect<s32>& rect) : CheatUIElement(rect) {}

namespace {
static std::vector<std::wstring> buildCoordsLines(const v3f &coords)
{
	std::vector<std::wstring> lines;
	std::wstringstream wss;
	wss << std::fixed << std::setprecision(1);
	wss << L"X: " << coords.X / 10 << L" Y: " << coords.Y / 10 << L" Z: " << coords.Z / 10;
	lines.push_back(wss.str());

	if (g_settings->getBool("coords.nether_coords")) {
		std::wstringstream nss;
		nss << std::fixed << std::setprecision(1);
		nss << L"Nether X: " << (coords.X / 10) / 8.0f
			<< L" Y: " << coords.Y / 10
			<< L" Z: " << (coords.Z / 10) / 8.0f;
		lines.push_back(nss.str());
	}

	return lines;
}
}

void coordsHUD::draw(video::IVideoDriver* driver, gui::IGUIFont* font, float dtime, ClientEnvironment &env, bool editing) {
    if (!hudShouldRender(editing))
        return;

    if (g_settings->getBool("coords") || editing) {
        const video::SColor outline_color = video::SColor(255, 0, 0, 0);
        const video::SColor background_color = video::SColor(255, 25, 25, 25);
        const video::SColor text_color = video::SColor(255, 255, 255, 255);

        if (editing || g_settings->getBool("coords.background")) {
            driver->draw2DRectangle(background_color, bounds);
            driver->draw2DRectangleOutline(bounds, outline_color, 3);
        }

        v3f coords = env.getLocalPlayer()->getPosition();
		const std::vector<std::wstring> lines = buildCoordsLines(coords);
		s32 total_height = 0;
		s32 max_width = 0;
		for (const auto &line : lines) {
			const core::dimension2d<u32> dim_u32 = font->getDimension(line.c_str());
			max_width = std::max(max_width, static_cast<s32>(dim_u32.Width));
			total_height += static_cast<s32>(dim_u32.Height);
		}
		s32 textX = bounds.UpperLeftCorner.X + (bounds.getWidth() - max_width) / 2;
		s32 textY = bounds.UpperLeftCorner.Y + (bounds.getHeight() - total_height) / 2;
		for (const auto &line : lines) {
			const core::dimension2d<u32> dim_u32 = font->getDimension(line.c_str());
			const core::dimension2d<s32> dim(dim_u32.Width, dim_u32.Height);
			font->draw(line.c_str(), core::rect<s32>(textX, textY, textX + dim.Width, textY + dim.Height), text_color);
			textY += dim.Height;
		}
    }
}
