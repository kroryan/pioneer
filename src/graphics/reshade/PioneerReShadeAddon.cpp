/*
 * Pioneer Space Simulator - ReShade 5 Addon
 * Configures depth buffer detection for Pioneer's MSAA OpenGL render targets
 * and auto-applies sane defaults for space simulation post-processing.
 *
 * Build: Compiled as pioneer-reshade.addon (DLL renamed by CMake)
 * Install: Place next to opengl32.dll (ReShade) and pioneer.exe
 */

#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <reshade.hpp>

// Forward declaration of ImGui table only if user includes imgui separately
// We deliberately avoid requiring imgui linkage here.

static HMODULE s_addon_module = nullptr;

// ------------------------------------------------------------------ //
//  Swapchain init: runs once when Pioneer's GL context is ready       //
// ------------------------------------------------------------------ //
static void on_init_swapchain(reshade::api::swapchain *swapchain, bool resize)
{
	if (resize)
		return;

	reshade::log::message(reshade::log::level::info,
		"[Pioneer] Swapchain initialised - applying depth buffer configuration");

	// Pioneer depth convention:
	//   - Standard GL range (0.0 = near, 1.0 = far)
	//   - MSAA resolve happens before SDL_GL_SwapWindow, so ReShade sees
	//     the already-resolved default framebuffer at present time.
	//   - Reversed depth is NOT active by default (glDepthRange 0,1).
	//
	// Tell ReShade's Generic Depth addon to use the largest depth buffer
	// (Pioneer creates one MSAA FBO depth attachment + the default FB depth).
	reshade::set_config_value(nullptr, "DEPTH", "UseAspectRatioHeuristics", "1");

	// Pioneer is a space sim - very large far plane.
	// Linearisation far plane (in scene units) must be large to avoid clipping.
	// The exact value is set in game code; 1e7 is a safe default.
	reshade::set_config_value(nullptr, "RESHADE_DEPTH_LINEARIZATION_FAR_PLANE", "Key", "10000000.0");

	// Depth input is NOT reversed for standard Pioneer builds
	reshade::set_config_value(nullptr, "RESHADE_DEPTH_INPUT_IS_REVERSED", "Key", "0");

	// Depth input is upside-down in OpenGL (Y-axis convention differs from DX)
	reshade::set_config_value(nullptr, "RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN", "Key", "1");

	reshade::log::message(reshade::log::level::info,
		"[Pioneer] Depth configuration applied (GL, MSAA-resolved, Y-flipped)");
}

static void on_destroy_swapchain(reshade::api::swapchain * /*swapchain*/, bool resize)
{
	if (resize)
		return;
	reshade::log::message(reshade::log::level::info, "[Pioneer] Swapchain destroyed");
}

// ------------------------------------------------------------------ //
//  Settings overlay (shown inside ReShade UI under Add-ons tab)      //
//  We keep this minimal - no imgui header dependency.                 //
// ------------------------------------------------------------------ //
static void on_reshade_present(reshade::api::effect_runtime * /*runtime*/)
{
	// Nothing to do per-frame at the API level.
	// All configuration is handled in on_init_swapchain.
}

// ------------------------------------------------------------------ //
//  DLL entry point                                                    //
// ------------------------------------------------------------------ //
BOOL APIENTRY DllMain(HMODULE hModule, DWORD reason, LPVOID)
{
	switch (reason)
	{
	case DLL_PROCESS_ATTACH:
		s_addon_module = hModule;

		// Register this addon with ReShade. Returns false if ReShade is not
		// present or the API version doesn't match - safe to ignore, the game
		// will still run normally.
		if (!reshade::register_addon(hModule))
			return TRUE; // not FALSE - allow the game to continue without ReShade

		reshade::register_event<reshade::addon_event::init_swapchain>(on_init_swapchain);
		reshade::register_event<reshade::addon_event::destroy_swapchain>(on_destroy_swapchain);
		reshade::register_event<reshade::addon_event::reshade_present>(on_reshade_present);

		reshade::log::message(reshade::log::level::info,
			"[Pioneer] pioneer-reshade.addon loaded (ReShade API v19)");
		break;

	case DLL_PROCESS_DETACH:
		reshade::unregister_event<reshade::addon_event::init_swapchain>(on_init_swapchain);
		reshade::unregister_event<reshade::addon_event::destroy_swapchain>(on_destroy_swapchain);
		reshade::unregister_event<reshade::addon_event::reshade_present>(on_reshade_present);
		reshade::unregister_addon(hModule);
		break;
	}
	return TRUE;
}
