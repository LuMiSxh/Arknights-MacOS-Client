// SPDX-License-Identifier: MPL-2.0

#import <objc/runtime.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

/*
 * Process-local Dock policy for the helper processes of the Arknights Wine process tree.
 *
 * The launcher injects this x86-64 dylib with DYLD_INSERT_LIBRARIES and passes its own process
 * ID. Wine passes the injection on to every process the game starts, such as the Bilibili
 * sign-in helper or a console host. Each of those would otherwise get its own "wine" Dock tile
 * with a generic executable icon, which macOS can keep among recent apps after the game exits.
 * Helpers switch to accessory activation instead. The game, the launcher's direct child, keeps
 * its Dock tile. Its icon and Dock name come from the runtime patches, not from this file.
 *
 * This file deliberately does not import or link AppKit/Foundation. Loading an AppKit-
 * linked injected dylib initializes AppKit before Wine has assigned
 * WINEPRELOADERAPPNAME, causing the menu bar to expose Wine's hosted-application name
 * instead of "Arknights". The bridge therefore waits until Wine itself has loaded
 * NSApplication and accesses the small required API surface through the Objective-C
 * runtime. The polling thread only installs the method hook.
 */

typedef signed char (*SetActivationPolicyIMP)(id, SEL, long);

/* The integer values mirror NSApplicationActivationPolicyRegular and Accessory. Naming them here
 * avoids loading AppKit merely to obtain those declarations. */
static const long activation_policy_regular = 0;
static const long activation_policy_accessory = 1;

/* AppKit normally appears very early in Wine startup. Polling every 50ms for at most ten
 * seconds avoids blocking dyld's constructor thread while still installing the hook before
 * Wine shows its first window, without keeping the CPU out of its idle states.
 * objc_getClass only observes runtime state; it does not cause AppKit to load. */
static const struct timespec appkit_poll_interval = {.tv_sec = 0, .tv_nsec = 50000000};
static const int appkit_poll_limit = 200;

static SetActivationPolicyIMP original_set_activation_policy;
static pthread_mutex_t activation_policy_lock = PTHREAD_MUTEX_INITIALIZER;

/* Replacement IMP for NSApplication.setActivationPolicy:. Wine starts each process as a UI
 * element and requests Regular when it shows its first window; keeping that request
 * accessory-only leaves the window usable but never publishes a Dock tile. */
static signed char set_activation_policy(id application, SEL selector, long policy) {
	SetActivationPolicyIMP original;
	if (policy == activation_policy_regular)
		policy = activation_policy_accessory;
	pthread_mutex_lock(&activation_policy_lock);
	original = original_set_activation_policy;
	pthread_mutex_unlock(&activation_policy_lock);
	return original != NULL ? original(application, selector, policy) : 0;
}

/* Installs the hook only after NSApplication exists. Holding the same mutex the replacement
 * uses while method_setImplementation publishes it prevents another AppKit caller from
 * observing the hook before its original target has been stored. */
static bool install_activation_policy_hook(void) {
	Class application_class = objc_getClass("NSApplication");
	if (application_class == Nil)
		return false;

	Method method =
	    class_getInstanceMethod(application_class, sel_registerName("setActivationPolicy:"));
	if (method == NULL)
		return false;

	pthread_mutex_lock(&activation_policy_lock);
	original_set_activation_policy =
	    (SetActivationPolicyIMP)method_setImplementation(method, (IMP)set_activation_policy);
	pthread_mutex_unlock(&activation_policy_lock);
	return original_set_activation_policy != NULL;
}

/* Background entry point used solely to wait for AppKit and install the hook. A timeout is
 * non-fatal: the helper keeps its normal Dock behavior. The message goes to stderr, which the
 * launcher already captures in wine.log for diagnosis. */
static void *wait_for_appkit(void *context) {
	(void)context;
	for (int attempt = 0; attempt < appkit_poll_limit; attempt++) {
		if (install_activation_policy_hook())
			return NULL;
		nanosleep(&appkit_poll_interval, NULL);
	}
	fprintf(stderr, "Arknights Client: helper Dock bridge timed out waiting for AppKit\n");
	return NULL;
}

/* Dylib entry point. The parent check runs here because the game is still the launcher's child
 * when the loader calls this constructor. Only helper processes start the observer thread. The
 * game, and a process with a missing or malformed launcher PID, keep the original Dock behavior.
 * Constructor failures are deliberately non-fatal and logged to Wine's captured stderr. */
__attribute__((constructor)) static void install_helper_dock_bridge(void) {
	const char *launcher_pid = getenv("ARKNIGHTS_CLIENT_LAUNCHER_PID");
	if (launcher_pid == NULL || launcher_pid[0] == '\0')
		return;
	char *end = NULL;
	long parent = strtol(launcher_pid, &end, 10);
	if (*end != '\0' || parent <= 0 || parent == (long)getppid())
		return;

	pthread_t thread;
	if (pthread_create(&thread, NULL, wait_for_appkit, NULL) == 0) {
		pthread_detach(thread);
	} else {
		fprintf(stderr, "Arknights Client: failed to start helper Dock bridge\n");
	}
}
