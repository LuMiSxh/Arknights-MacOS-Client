// SPDX-License-Identifier: MPL-2.0

#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <objc/message.h>
#include <objc/runtime.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

/*
 * Stops two per-frame leaks in the bundled DXMT's winemetal.so (runtime 0.7.0).
 *
 * _WMTGetDisplayDescription creates a ColorSync profile and copies four ICC tags on every
 * call and never releases them. _WMTQueryDisplaySettingForLayer runs on every Present from
 * the game's render thread, which has no autorelease pool, so the deviceDescription
 * dictionary it reads is never freed. Together the game grows by up to 20 GB per hour.
 *
 * The launcher injects this x86-64 dylib with DYLD_INSERT_LIBRARIES. When winemetal.so
 * loads, the bridge replaces the two entries of its __wine_unix_call_funcs table, which
 * Wine's ntdll indexes on every unix call. It first checks that both entries point at the
 * exact functions of the pinned runtime build; any other build is left untouched. Remove
 * this component once the runtime ships a DXMT with the fix.
 */

extern void *objc_autoreleasePoolPush(void);
extern void objc_autoreleasePoolPop(void *pool);

typedef int (*UnixCall)(void *);

/* Offsets from winemetal.so of Arknights macOS Runtime 0.7.0 (`dyld_info -fixups`); the
 * indexes follow the order of __wine_unix_call_funcs in its DXMT source. */
enum { display_description_index = 96, query_display_setting_for_layer_index = 101 };
static const uintptr_t display_description_offset = 0xB1E0;
static const uintptr_t query_display_setting_for_layer_offset = 0xB5B0;

static UnixCall original_display_description;
static UnixCall original_query_display_setting_for_layer;

/* Mirrors winemetal.h and winemetal_thunks.h on x86-64. */
struct DisplayDescription {
	float red_primaries[2];
	float blue_primaries[2];
	float green_primaries[2];
	float white_points[2];
	float maximum_edr_color_component_value;
	float maximum_potential_edr_color_component_value;
	float maximum_reference_edr_color_component_value;
};

struct DisplayDescriptionParameters {
	uint64_t display_id;
	struct DisplayDescription *description;
};

/* ColorSync and AppKit are resolved from the copies winemetal.so already loaded. Linking
 * them here would initialize AppKit before Wine names the application (see GameIconBridge.m). */
typedef CFTypeRef (*ProfileCreateWithDisplayID)(uint32_t);
typedef CFTypeRef (*ProfileCreateWithName)(CFStringRef);
typedef CFDataRef (*ProfileCopyTag)(CFTypeRef, CFStringRef);

struct ColorSync {
	ProfileCreateWithDisplayID create_with_display_id;
	ProfileCreateWithName create_with_name;
	ProfileCopyTag copy_tag;
	const CFStringRef *generic_rgb_profile;
};

static bool load_color_sync(struct ColorSync *color_sync) {
	color_sync->create_with_display_id = dlsym(RTLD_DEFAULT, "ColorSyncProfileCreateWithDisplayID");
	color_sync->create_with_name = dlsym(RTLD_DEFAULT, "ColorSyncProfileCreateWithName");
	color_sync->copy_tag = dlsym(RTLD_DEFAULT, "ColorSyncProfileCopyTag");
	color_sync->generic_rgb_profile = dlsym(RTLD_DEFAULT, "kColorSyncGenericRGBProfile");
	return color_sync->create_with_display_id != NULL && color_sync->create_with_name != NULL &&
	       color_sync->copy_tag != NULL && color_sync->generic_rgb_profile != NULL;
}

/* Reads an ICC XYZType tag as CIE xy chromaticity, exactly as DXMT's GetChromaticity_xy. */
static bool read_chromaticity(
    const struct ColorSync *color_sync,
    CFTypeRef profile,
    const char *tag_symbol,
    float *x,
    float *y) {
	const CFStringRef *tag = dlsym(RTLD_DEFAULT, tag_symbol);
	if (tag == NULL)
		return false;
	CFDataRef data = color_sync->copy_tag(profile, *tag);
	if (data == NULL)
		return false;
	bool read = false;
	const uint8_t *bytes = CFDataGetBytePtr(data);
	uint32_t signature;
	int32_t xyz[3];
	if (CFDataGetLength(data) == 20) {
		memcpy(&signature, bytes, sizeof(signature));
		memcpy(xyz, bytes + 8, sizeof(xyz));
		if (signature == 0x205a5958) {
			double X = (int32_t)__builtin_bswap32((uint32_t)xyz[0]) / 65536.0;
			double Y = (int32_t)__builtin_bswap32((uint32_t)xyz[1]) / 65536.0;
			double Z = (int32_t)__builtin_bswap32((uint32_t)xyz[2]) / 65536.0;
			*x = X / (X + Y + Z);
			*y = Y / (X + Y + Z);
			read = true;
		}
	}
	CFRelease(data);
	return read;
}

static bool read_color_gamut(
    const struct ColorSync *color_sync, CFTypeRef profile, struct DisplayDescription *description) {
	return read_chromaticity(
	           color_sync,
	           profile,
	           "kColorSyncSigMediaWhitePointTag",
	           &description->white_points[0],
	           &description->white_points[1]) &&
	       read_chromaticity(
	           color_sync,
	           profile,
	           "kColorSyncSigRedColorantTag",
	           &description->red_primaries[0],
	           &description->red_primaries[1]) &&
	       read_chromaticity(
	           color_sync,
	           profile,
	           "kColorSyncSigGreenColorantTag",
	           &description->green_primaries[0],
	           &description->green_primaries[1]) &&
	       read_chromaticity(
	           color_sync,
	           profile,
	           "kColorSyncSigBlueColorantTag",
	           &description->blue_primaries[0],
	           &description->blue_primaries[1]);
}

static id screen_for_display(uint32_t display_id) {
	Class screen_class = objc_getClass("NSScreen");
	if (screen_class == Nil)
		return nil;
	id screens = ((id (*)(id, SEL))objc_msgSend)((id)screen_class, sel_registerName("screens"));
	long count = ((long (*)(id, SEL))objc_msgSend)(screens, sel_registerName("count"));
	for (long index = 0; index < count; index++) {
		id screen = ((id (*)(id, SEL, long))objc_msgSend)(
		    screens, sel_registerName("objectAtIndex:"), index);
		id device = ((id (*)(id, SEL))objc_msgSend)(screen, sel_registerName("deviceDescription"));
		id number = ((id (*)(id, SEL, id))objc_msgSend)(
		    device, sel_registerName("objectForKey:"), (id)CFSTR("NSScreenNumber"));
		if (((unsigned (*)(id, SEL))objc_msgSend)(number, sel_registerName("unsignedIntValue")) ==
		    display_id)
			return screen;
	}
	return nil;
}

static float screen_value(id screen, const char *selector) {
	return (float)((double (*)(id, SEL))objc_msgSend)(screen, sel_registerName(selector));
}

/* Same results as DXMT's _WMTGetDisplayDescription; every created object is released. */
static int get_display_description(void *parameters) {
	struct ColorSync color_sync;
	if (!load_color_sync(&color_sync))
		return original_display_description(parameters);
	struct DisplayDescriptionParameters *call = parameters;
	struct DisplayDescription *description = call->description;
	uint32_t display_id = (uint32_t)call->display_id;

	void *pool = objc_autoreleasePoolPush();
	CFTypeRef profile = color_sync.create_with_display_id(display_id);
	if (profile == NULL || !read_color_gamut(&color_sync, profile, description)) {
		CFTypeRef generic = color_sync.create_with_name(*color_sync.generic_rgb_profile);
		if (generic != NULL) {
			read_color_gamut(&color_sync, generic, description);
			CFRelease(generic);
		}
	}
	if (profile != NULL)
		CFRelease(profile);
	id screen = screen_for_display(display_id);
	if (screen != nil) {
		description->maximum_edr_color_component_value =
		    screen_value(screen, "maximumExtendedDynamicRangeColorComponentValue");
		description->maximum_reference_edr_color_component_value =
		    screen_value(screen, "maximumReferenceExtendedDynamicRangeColorComponentValue");
		description->maximum_potential_edr_color_component_value =
		    screen_value(screen, "maximumPotentialExtendedDynamicRangeColorComponentValue");
	} else {
		description->maximum_edr_color_component_value = 1.0f;
		description->maximum_reference_edr_color_component_value = 0.0f;
		description->maximum_potential_edr_color_component_value = 1.0f;
	}
	objc_autoreleasePoolPop(pool);
	return 0;
}

static int query_display_setting_for_layer(void *parameters) {
	void *pool = objc_autoreleasePoolPush();
	int status = original_query_display_setting_for_layer(parameters);
	objc_autoreleasePoolPop(pool);
	return status;
}

static void patch_winemetal(const struct mach_header *header, intptr_t slide) {
	(void)slide;
	if (original_display_description != NULL)
		return;
	Dl_info image;
	if (!dladdr(header, &image) || image.dli_fname == NULL)
		return;
	const char *name = strrchr(image.dli_fname, '/');
	if (name == NULL || strcmp(name, "/winemetal.so") != 0)
		return;
	void *handle = dlopen(image.dli_fname, RTLD_NOLOAD | RTLD_LAZY);
	if (handle == NULL)
		return;
	UnixCall *calls = dlsym(handle, "__wine_unix_call_funcs");
	uintptr_t base = (uintptr_t)header;
	if (calls == NULL ||
	    (uintptr_t)calls[display_description_index] != base + display_description_offset ||
	    (uintptr_t)calls[query_display_setting_for_layer_index] !=
	        base + query_display_setting_for_layer_offset) {
		fprintf(
		    stderr,
		    "Arknights Client: DXMT leak fix skipped, winemetal.so is not the 0.7.0 build\n");
		return;
	}
	original_display_description = calls[display_description_index];
	original_query_display_setting_for_layer = calls[query_display_setting_for_layer_index];
	calls[display_description_index] = get_display_description;
	calls[query_display_setting_for_layer_index] = query_display_setting_for_layer;
	fprintf(stderr, "Arknights Client: DXMT leak fix applied\n");
}

__attribute__((constructor)) static void install_dxmt_leak_fix(void) {
	_dyld_register_func_for_add_image(patch_winemetal);
}
