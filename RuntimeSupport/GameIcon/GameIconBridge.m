// SPDX-License-Identifier: MPL-2.0

#import <objc/message.h>
#import <objc/runtime.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/*
 * Process-local Dock icon policy for the main Arknights Wine process.
 *
 * The launcher injects this x86-64 dylib with DYLD_INSERT_LIBRARIES. Wine later asks
 * NSApplication to publish the icon it extracted from Arknights.exe. Intercepting that
 * single public AppKit setter lets the launcher either normalize the extracted icon to
 * the macOS icon grid or replace it with a launcher-owned PNG, without modifying Wine,
 * its prefix, or the game executable.
 *
 * This file deliberately does not import or link AppKit/Foundation. Loading an AppKit-
 * linked injected dylib initializes AppKit before Wine has assigned
 * WINEPRELOADERAPPNAME, causing the menu bar to expose Wine's hosted-application name
 * instead of "Arknights". The bridge therefore waits until Wine itself has loaded
 * NSApplication and accesses the small required API surface through the Objective-C
 * runtime. All AppKit object creation and drawing still happens on Wine's calling
 * thread when it invokes setApplicationIconImage:; the polling thread only installs
 * the method hook.
 */

/* NSPoint, NSSize, and NSRect are intentionally mirrored instead of importing AppKit.
 * Their x86-64 layouts are pairs of doubles, which must exactly match the objc_msgSend
 * function signatures below for struct arguments and return values to use the correct ABI. */
typedef struct {
	double x;
	double y;
} AKPoint;

typedef struct {
	double width;
	double height;
} AKSize;

typedef struct {
	AKPoint origin;
	AKSize size;
} AKRect;

typedef void (*SetApplicationIconImageIMP)(id, SEL, id);

/* A 412-point content square inside a 512-point canvas is the 80.5% macOS icon grid.
 * The integer enum values mirror NSCompositingOperationCopy and NSImageInterpolationHigh;
 * naming them here avoids loading AppKit merely to obtain those declarations. */
static const double icon_canvas_dimension = 512.0;
static const double icon_content_dimension = 412.0;
static const long compositing_operation_copy = 1;
static const long image_interpolation_high = 3;

/* AppKit normally appears very early in Wine startup. Polling every millisecond for at
 * most ten seconds avoids blocking dyld's constructor thread while still installing the
 * hook before Wine publishes its executable icon. objc_getClass only observes runtime
 * state; it does not cause AppKit to load. */
static const struct timespec appkit_poll_interval = { .tv_sec = 0, .tv_nsec = 1000000 };
static const int appkit_poll_limit = 10000;

static SetApplicationIconImageIMP original_set_application_icon_image;
static pthread_mutex_t icon_setter_lock = PTHREAD_MUTEX_INITIALIZER;
static char *custom_game_icon_path;
static id custom_game_icon;

/* Typed objc_msgSend adapters are required because the runtime declares objc_msgSend
 * without the concrete return and argument ABI of each selector. Keep these signatures
 * aligned with the corresponding AppKit methods, especially the struct-valued variants. */
static id send_id(id receiver, SEL selector) {
	return ((id (*)(id, SEL))objc_msgSend)(receiver, selector);
}

static id send_id_with_id(id receiver, SEL selector, id value) {
	return ((id (*)(id, SEL, id))objc_msgSend)(receiver, selector, value);
}

static id send_id_with_size(id receiver, SEL selector, AKSize value) {
	return ((id (*)(id, SEL, AKSize))objc_msgSend)(receiver, selector, value);
}

static void send_void(id receiver, SEL selector) {
	((void (*)(id, SEL))objc_msgSend)(receiver, selector);
}

static void send_void_with_integer(id receiver, SEL selector, long value) {
	((void (*)(id, SEL, long))objc_msgSend)(receiver, selector, value);
}

static AKSize send_size(id receiver, SEL selector) {
	return ((AKSize (*)(id, SEL))objc_msgSend)(receiver, selector);
}

static void send_draw_message(
	id receiver, SEL selector, AKRect destination, AKRect source, long operation, double fraction) {
	((void (*)(id, SEL, AKRect, AKRect, long, double))objc_msgSend)(
		receiver, selector, destination, source, operation, fraction);
}

/* Resolves the optional launcher-owned PNG only after Wine has initialized AppKit.
 * Both the copied C path and NSImage intentionally live for the remaining process
 * lifetime: Wine sets its application icon once, and retaining these objects prevents
 * an autorelease-pool boundary from invalidating the replacement before AppKit consumes it. */
static id load_custom_game_icon(void) {
	if (custom_game_icon != nil || custom_game_icon_path == NULL) return custom_game_icon;

	Class string_class = objc_getClass("NSString");
	Class image_class = objc_getClass("NSImage");
	if (string_class == Nil || image_class == Nil) return nil;

	id path = ((id (*)(id, SEL, const char *))objc_msgSend)(
		(id)string_class, sel_registerName("stringWithUTF8String:"), custom_game_icon_path);
	id image = send_id((id)image_class, sel_registerName("alloc"));
	custom_game_icon = send_id_with_id(image, sel_registerName("initWithContentsOfFile:"), path);
	if (custom_game_icon == nil) {
		fprintf(
			stderr,
			"Arknights Client: failed to load custom game icon: %s\n",
			custom_game_icon_path);
	}
	return custom_game_icon;
}

/* Places Wine's full-bleed executable icon on the same transparent 512x512 canvas used
 * by launcher presets. Failures conservatively return the original NSImage so icon
 * handling can never prevent the game from presenting its Dock tile. Drawing uses the
 * current AppKit graphics context on Wine's setter-calling thread, not the polling thread. */
static id normalized_game_icon(id source) {
	if (source == nil) return nil;

	Class image_class = objc_getClass("NSImage");
	Class graphics_context_class = objc_getClass("NSGraphicsContext");
	if (image_class == Nil || graphics_context_class == Nil) return source;

	AKSize canvas_size = { icon_canvas_dimension, icon_canvas_dimension };
	id result = send_id((id)image_class, sel_registerName("alloc"));
	result = send_id_with_size(result, sel_registerName("initWithSize:"), canvas_size);
	if (result == nil) return source;

	send_void(result, sel_registerName("lockFocus"));
	id context = send_id((id)graphics_context_class, sel_registerName("currentContext"));
	send_void_with_integer(
		context, sel_registerName("setImageInterpolation:"), image_interpolation_high);

	double inset = (icon_canvas_dimension - icon_content_dimension) / 2.0;
	AKRect destination = { { inset, inset }, { icon_content_dimension, icon_content_dimension } };
	AKRect source_rect = { { 0.0, 0.0 }, send_size(source, sel_registerName("size")) };
	send_draw_message(
		source,
		sel_registerName("drawInRect:fromRect:operation:fraction:"),
		destination,
		source_rect,
		compositing_operation_copy,
		1.0);
	send_void(result, sel_registerName("unlockFocus"));
	return result;
}

/* Replacement IMP for NSApplication.setApplicationIconImage:. A valid custom image takes
 * precedence; a missing or unreadable one falls back to the normalized executable icon.
 * Calling the saved IMP preserves AppKit's normal Dock and application-icon side effects. */
static void set_application_icon_image(id application, SEL selector, id image) {
	SetApplicationIconImageIMP original;
	id resolved = load_custom_game_icon();
	if (resolved == nil) resolved = normalized_game_icon(image);
	pthread_mutex_lock(&icon_setter_lock);
	original = original_set_application_icon_image;
	pthread_mutex_unlock(&icon_setter_lock);
	if (original != NULL) original(application, selector, resolved);
}

/* Installs the hook only after NSApplication exists. Holding the same mutex the replacement
 * uses while method_setImplementation publishes it prevents another AppKit caller from
 * observing the hook before its original target has been stored. */
static bool install_icon_setter(void) {
	Class application_class = objc_getClass("NSApplication");
	SetApplicationIconImageIMP original;
	if (application_class == Nil) return false;

	SEL selector = sel_registerName("setApplicationIconImage:");
	Method method = class_getInstanceMethod(application_class, selector);
	if (method == NULL) return false;

	pthread_mutex_lock(&icon_setter_lock);
	original = (SetApplicationIconImageIMP)method_setImplementation(
		method, (IMP)set_application_icon_image);
	original_set_application_icon_image = original;
	pthread_mutex_unlock(&icon_setter_lock);
	return original != NULL;
}

/* Background entry point used solely to observe AppKit availability and install the hook.
 * A timeout is non-fatal—the game keeps Wine's unmodified icon—but is written to stderr,
 * which the launcher already captures in wine.log for diagnosis. */
static void *wait_for_appkit(void *context) {
	(void)context;
	for (int attempt = 0; attempt < appkit_poll_limit; attempt++) {
		if (install_icon_setter()) return NULL;
		nanosleep(&appkit_poll_interval, NULL);
	}
	fprintf(stderr, "Arknights Client: game icon bridge timed out waiting for AppKit\n");
	return NULL;
}

/* Dylib entry point. It snapshots the optional custom-icon path before returning from the
 * loader callback, then detaches the observer so dyld can continue Wine startup immediately.
 * Constructor failures are deliberately non-fatal and logged to Wine's captured stderr. */
__attribute__((constructor)) static void install_game_icon_bridge(void) {
	const char *custom_path = getenv("ARKNIGHTS_CLIENT_GAME_ICON_PATH");
	if (custom_path != NULL && custom_path[0] != '\0') {
		custom_game_icon_path = strdup(custom_path);
		if (custom_game_icon_path == NULL) {
			fprintf(stderr, "Arknights Client: failed to copy custom game icon path\n");
		}
	}

	pthread_t thread;
	if (pthread_create(&thread, NULL, wait_for_appkit, NULL) == 0) {
		pthread_detach(thread);
	} else {
		fprintf(stderr, "Arknights Client: failed to start game icon bridge\n");
	}
}
