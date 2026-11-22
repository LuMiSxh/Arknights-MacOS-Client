// SPDX-License-Identifier: MPL-2.0

#import <objc/message.h>
#import <objc/runtime.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

/*
 * Process-local Dock policy for the Arknights Wine process tree.
 *
 * The launcher injects this x86-64 dylib with DYLD_INSERT_LIBRARIES. Wine later asks
 * NSApplication to publish the icon it extracted from Arknights.exe. Intercepting that
 * single public AppKit setter lets the launcher replace the icon with a launcher-owned PNG,
 * without modifying Wine, its prefix, or the game executable. Without a custom icon, Wine's
 * image passes through unchanged; the Wine squircle patch already places it on the icon grid.
 *
 * Wine passes the injection on to every process the game starts, such as the Bilibili
 * sign-in helper or a console host. Each of those would otherwise get its own "wine"
 * Dock tile with a generic executable icon, which macOS can keep among recent apps after
 * the game exits. Only the launcher's direct child, the game, keeps its Dock tile.
 *
 * The game itself would also be recorded as a recent app when it quits. The Dock keeps only
 * the symlinked Wine executable, so it would show a generic executable icon instead of the
 * Arknights icon set at runtime. An exit handler therefore sets the game's activation policy
 * to Prohibited just before the process ends, which removes its Dock tile first.
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


typedef void (*SetApplicationIconImageIMP)(id, SEL, id);
typedef signed char (*SetActivationPolicyIMP)(id, SEL, long);

/* The integer enum values mirror NSApplicationActivationPolicyRegular/Accessory/Prohibited;
 * naming them here avoids loading AppKit merely to obtain those declarations. */
static const long activation_policy_regular = 0;
static const long activation_policy_accessory = 1;
static const long activation_policy_prohibited = 2;

/* Wine exits on a Win32 thread, so the policy change must hop to the Cocoa main thread. The
 * wait is bounded so a blocked main thread can delay exit by at most this long, never hang it. */
static const int64_t exit_main_thread_timeout_ns = 250000000;

/* AppKit normally appears very early in Wine startup. Polling every 50ms for at most ten
 * seconds avoids blocking dyld's constructor thread while still installing the hook before
 * Wine publishes its executable icon, without keeping the CPU out of its idle states.
 * objc_getClass only observes runtime state; it does not cause AppKit to load. */
static const struct timespec appkit_poll_interval = {.tv_sec = 0, .tv_nsec = 50000000};
static const int appkit_poll_limit = 200;

static SetApplicationIconImageIMP original_set_application_icon_image;
static SetActivationPolicyIMP original_set_activation_policy;
static bool is_helper_process;
static dispatch_semaphore_t exit_policy_done;
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

static void send_void(id receiver, SEL selector) {
	((void (*)(id, SEL))objc_msgSend)(receiver, selector);
}

static void send_void_with_integer(id receiver, SEL selector, long value) {
	((void (*)(id, SEL, long))objc_msgSend)(receiver, selector, value);
}

/* Resolves the optional launcher-owned PNG only after Wine has initialized AppKit.
 * Both the copied C path and NSImage intentionally live for the remaining process
 * lifetime: Wine sets its application icon once, and retaining these objects prevents
 * an autorelease-pool boundary from invalidating the replacement before AppKit consumes it. */
static id load_custom_game_icon(void) {
	if (custom_game_icon != nil || custom_game_icon_path == NULL)
		return custom_game_icon;

	Class string_class = objc_getClass("NSString");
	Class image_class = objc_getClass("NSImage");
	if (string_class == Nil || image_class == Nil)
		return nil;

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

/* Replacement IMP for NSApplication.setApplicationIconImage:. A valid custom image takes
 * precedence; otherwise Wine's image passes through unchanged. Calling the saved IMP
 * preserves AppKit's normal Dock and application-icon side effects. The pool catches
 * AppKit's autoreleased temporaries, which no Wine-owned pool is guaranteed to cover on the
 * calling thread; the retained custom icon survives it. */
static void set_application_icon_image(id application, SEL selector, id image) {
	@autoreleasepool {
		SetApplicationIconImageIMP original;
		id resolved = load_custom_game_icon();
		if (resolved == nil)
			resolved = image;
		pthread_mutex_lock(&icon_setter_lock);
		original = original_set_application_icon_image;
		pthread_mutex_unlock(&icon_setter_lock);
		if (original != NULL)
			original(application, selector, resolved);
	}
}

/* Installs the hook only after NSApplication exists. Holding the same mutex the replacement
 * uses while method_setImplementation publishes it prevents another AppKit caller from
 * observing the hook before its original target has been stored. */
static bool install_icon_setter(void) {
	Class application_class = objc_getClass("NSApplication");
	SetApplicationIconImageIMP original;
	if (application_class == Nil)
		return false;

	SEL selector = sel_registerName("setApplicationIconImage:");
	Method method = class_getInstanceMethod(application_class, selector);
	if (method == NULL)
		return false;

	pthread_mutex_lock(&icon_setter_lock);
	original = (SetApplicationIconImageIMP)method_setImplementation(
	    method, (IMP)set_application_icon_image);
	original_set_application_icon_image = original;
	pthread_mutex_unlock(&icon_setter_lock);
	return original != NULL;
}

/* Replacement IMP for NSApplication.setActivationPolicy: in helper processes. Wine starts
 * each process as a UI element and requests Regular when it shows its first window; keeping
 * that request accessory-only leaves the window usable but never publishes a Dock tile. */
static signed char set_activation_policy(id application, SEL selector, long policy) {
	SetActivationPolicyIMP original;
	if (policy == activation_policy_regular)
		policy = activation_policy_accessory;
	pthread_mutex_lock(&icon_setter_lock);
	original = original_set_activation_policy;
	pthread_mutex_unlock(&icon_setter_lock);
	return original != NULL ? original(application, selector, policy) : 0;
}

static bool install_activation_policy_hook(void) {
	Class application_class = objc_getClass("NSApplication");
	if (application_class == Nil)
		return false;

	Method method =
	    class_getInstanceMethod(application_class, sel_registerName("setActivationPolicy:"));
	if (method == NULL)
		return false;

	pthread_mutex_lock(&icon_setter_lock);
	original_set_activation_policy =
	    (SetActivationPolicyIMP)method_setImplementation(method, (IMP)set_activation_policy);
	pthread_mutex_unlock(&icon_setter_lock);
	return original_set_activation_policy != NULL;
}

/* Must run on the main thread. NSApp is read through its exported symbol so that exit never
 * creates an NSApplication: a nil value means Wine never started AppKit and nothing is shown. */
static void leave_dock(void *context) {
	(void)context;
	@autoreleasepool {
		id *application_symbol = (id *)dlsym(RTLD_DEFAULT, "NSApp");
		id application = application_symbol != NULL ? *application_symbol : nil;
		if (application != nil) {
			send_void_with_integer(
			    application,
			    sel_registerName("setActivationPolicy:"),
			    activation_policy_prohibited);
		}
	}
	dispatch_semaphore_signal(exit_policy_done);
}

/* Removes the game's Dock tile before exit so macOS does not record it as a recent app. This is
 * best effort: it does nothing if the main queue does not respond within the timeout. */
static void leave_dock_at_exit(void) {
	if (pthread_main_np()) {
		leave_dock(NULL);
		return;
	}
	dispatch_async_f(dispatch_get_main_queue(), NULL, leave_dock);
	if (dispatch_semaphore_wait(
	        exit_policy_done, dispatch_time(DISPATCH_TIME_NOW, exit_main_thread_timeout_ns)) != 0) {
		fprintf(stderr, "Arknights Client: timed out leaving the Dock at exit\n");
	}
}

/* Background entry point used solely to observe AppKit availability and install the hooks.
 * A timeout is non-fatal—the game keeps Wine's unmodified icon—but is written to stderr,
 * which the launcher already captures in wine.log for diagnosis. */
static void *wait_for_appkit(void *context) {
	(void)context;
	for (int attempt = 0; attempt < appkit_poll_limit; attempt++) {
		@autoreleasepool {
			if (install_icon_setter()) {
				if (is_helper_process && !install_activation_policy_hook()) {
					fprintf(stderr, "Arknights Client: failed to keep a helper out of the Dock\n");
				}
				if (!is_helper_process && atexit(leave_dock_at_exit) != 0) {
					fprintf(
					    stderr, "Arknights Client: failed to remove the game from recent apps\n");
				}
				return NULL;
			}
		}
		nanosleep(&appkit_poll_interval, NULL);
	}
	fprintf(stderr, "Arknights Client: game icon bridge timed out waiting for AppKit\n");
	return NULL;
}

/* Dylib entry point. It snapshots the optional custom-icon path and whether this process is a
 * helper before returning from the loader callback, then detaches the observer so dyld can
 * continue Wine startup immediately. The parent check runs here because the game is still the
 * launcher's child; a missing or malformed launcher PID keeps the original Dock behavior.
 * Constructor failures are deliberately non-fatal and logged to Wine's captured stderr. */
__attribute__((constructor)) static void install_game_icon_bridge(void) {
	const char *custom_path = getenv("ARKNIGHTS_CLIENT_GAME_ICON_PATH");
	if (custom_path != NULL && custom_path[0] != '\0') {
		custom_game_icon_path = strdup(custom_path);
		if (custom_game_icon_path == NULL) {
			fprintf(stderr, "Arknights Client: failed to copy custom game icon path\n");
		}
	}
	const char *launcher_pid = getenv("ARKNIGHTS_CLIENT_LAUNCHER_PID");
	if (launcher_pid != NULL && launcher_pid[0] != '\0') {
		char *end = NULL;
		long parent = strtol(launcher_pid, &end, 10);
		is_helper_process = *end == '\0' && parent > 0 && parent != (long)getppid();
	}

	exit_policy_done = dispatch_semaphore_create(0);
	pthread_t thread;
	if (pthread_create(&thread, NULL, wait_for_appkit, NULL) == 0) {
		pthread_detach(thread);
	} else {
		fprintf(stderr, "Arknights Client: failed to start game icon bridge\n");
	}
}
