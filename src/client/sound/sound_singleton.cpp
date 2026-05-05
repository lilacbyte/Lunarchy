// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (C) 2022 DS
// Copyright (C) 2013 celeron55, Perttu Ahola <celeron55@gmail.com>
// Copyright (C) 2011 Sebastian 'Bahamada' Rühl
// Copyright (C) 2011 Cyriaque 'Cisoun' Skrapits <cysoun@gmail.com>
// Copyright (C) 2011 Giuseppe Bilotta <giuseppe.bilotta@gmail.com>

#include "sound_singleton.h"

#include <cctype>
#include <algorithm>
#include <string>
#include <vector>

namespace sound {

namespace {

using DeviceList = std::vector<std::string>;

DeviceList enumerateDevices()
{
	DeviceList devices;

	if (const ALCchar *device_names = alcGetString(nullptr, ALC_DEVICE_SPECIFIER)) {
		const ALCchar *name = device_names;
		while (*name != '\0') {
			devices.emplace_back(name);
			name += devices.back().size() + 1;
		}
	}

	return devices;
}

bool isPipeWireDevice(const std::string &device_name)
{
	std::string lowered = device_name;
	std::transform(lowered.begin(), lowered.end(), lowered.begin(),
		[](unsigned char c) { return static_cast<char>(std::tolower(c)); });
	return lowered.find("pipewire") != std::string::npos;
}

bool tryOpenDevice(const char *device_name,
		SoundManagerSingleton::unique_ptr_alcdevice &device,
		SoundManagerSingleton::unique_ptr_alccontext &context)
{
	auto opened_device = SoundManagerSingleton::unique_ptr_alcdevice(alcOpenDevice(device_name));
	if (!opened_device)
		return false;

	auto opened_context = SoundManagerSingleton::unique_ptr_alccontext(
			alcCreateContext(opened_device.get(), nullptr));
	if (!opened_context)
		return false;

	if (!alcMakeContextCurrent(opened_context.get()))
		return false;

	device = std::move(opened_device);
	context = std::move(opened_context);
	return true;
}

} // namespace

bool SoundManagerSingleton::init()
{
	DeviceList devices = enumerateDevices();
	std::vector<std::string> candidates;
	candidates.reserve(devices.size() + 1);

	if (const ALCchar *default_device = alcGetString(nullptr, ALC_DEFAULT_DEVICE_SPECIFIER);
			default_device && *default_device != '\0') {
		candidates.emplace_back(default_device);
	}

	for (const std::string &device_name : devices) {
		if (std::find(candidates.begin(), candidates.end(), device_name) == candidates.end())
			candidates.push_back(device_name);
	}

	auto try_all_devices = [&](auto &&predicate) {
		for (const std::string &device_name : candidates) {
			if (predicate(device_name) &&
					tryOpenDevice(device_name.c_str(), m_device, m_context))
				return true;
		}
		return false;
	};

	// Prefer non-PipeWire devices first when available, then fall back to PipeWire.
	if (!try_all_devices([&](const std::string &device_name) {
		return !isPipeWireDevice(device_name);
	}) &&
			!try_all_devices([&](const std::string &device_name) {
				return isPipeWireDevice(device_name);
			})) {
		errorstream << "Audio: Global Initialization: Failed to open or initialize OpenAL device" << std::endl;
		return false;
	}

	alDistanceModel(AL_INVERSE_DISTANCE_CLAMPED);

	// Speed of sound in nodes per second
	// FIXME: This value assumes 1 node sidelength = 1 meter, and "normal" air.
	//        Ideally this should be mod-controlled.
	alSpeedOfSound(343.3f);

	// doppler effect turned off for now, for best backwards compatibility
	alDopplerFactor(0.0f);

	if (alGetError() != AL_NO_ERROR) {
		errorstream << "Audio: Global Initialization: OpenAL Error " << alGetError() << std::endl;
		return false;
	}

	infostream << "Audio: Global Initialized: OpenAL " << alGetString(AL_VERSION)
		<< ", using " << alcGetString(m_device.get(), ALC_DEVICE_SPECIFIER)
		<< std::endl;

	return true;
}

SoundManagerSingleton::~SoundManagerSingleton()
{
	infostream << "Audio: Global Deinitialized." << std::endl;
}

} // namespace sound
