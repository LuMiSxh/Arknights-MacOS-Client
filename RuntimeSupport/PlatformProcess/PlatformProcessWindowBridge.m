// SPDX-License-Identifier: MPL-2.0

#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <unistd.h>

/*
 * Process-local macOS presentation policy for Arknights' PlatformProcess.
 *
 * Window position remains owned by Wine and the Win32 wrapper. Keeping Cocoa
 * and Win32 coordinates in sync is essential because winemac.drv converts
 * global mouse coordinates back through the Windows window rectangle before
 * dispatching an input event. This bridge therefore changes only presentation:
 * Dock visibility, Spaces behavior, transparency, and the rounded crop.
 */

static const volatile char launcher_marker[] =
	"Arknights Client PlatformProcess window bridge";
static dispatch_source_t presentation_timer;
static char notice_mask_key;
static CGWindowID logged_game_window;

struct game_window {
	CGWindowID number;
	pid_t process_id;
};

static struct game_window game_window_info(void) {
	CFArrayRef windows = CGWindowListCopyWindowInfo(
		kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
		kCGNullWindowID
	);
	struct game_window result = { kCGNullWindowID, 0 };
	CGFloat largest_area = 0.0;

	if (windows == NULL) return result;
	for (NSDictionary *description in (__bridge NSArray *)windows) {
		NSNumber *owner_pid = description[(id)kCGWindowOwnerPID];
		NSNumber *layer = description[(id)kCGWindowLayer];
		NSString *owner_name = description[(id)kCGWindowOwnerName];
		NSString *name = description[(id)kCGWindowName];
		NSDictionary *bounds_description = description[(id)kCGWindowBounds];
		CGRect bounds;
		CGFloat area;

		if (owner_pid.intValue == getpid() || layer.integerValue != 0) continue;
		if (![owner_name hasPrefix:@"Arknights"] && ![name hasPrefix:@"Arknights"]) {
			continue;
		}
		if (!CGRectMakeWithDictionaryRepresentation(
			(__bridge CFDictionaryRef)bounds_description,
			&bounds
		)) continue;
		area = bounds.size.width * bounds.size.height;
		if (area <= largest_area) continue;
		largest_area = area;
		result.number = [description[(id)kCGWindowNumber] unsignedIntValue];
		result.process_id = owner_pid.intValue;
	}
	CFRelease(windows);
	return result;
}

static void apply_notice_mask(NSView *view) {
	CAShapeLayer *mask;
	CGRect bounds;
	CGRect visible_bounds;
	CGPathRef path;

	if (view == nil) return;
	view.wantsLayer = YES;
	bounds = view.bounds;
	mask = objc_getAssociatedObject(view, &notice_mask_key);
	if (mask != nil && CGRectEqualToRect(mask.frame, bounds)) return;
	if (mask == nil) {
		mask = [CAShapeLayer layer];
		objc_setAssociatedObject(
			view,
			&notice_mask_key,
			mask,
			OBJC_ASSOCIATION_RETAIN_NONATOMIC
		);
	}
	visible_bounds = bounds;
	visible_bounds.size.width = MAX(0.0, visible_bounds.size.width - 1.0);
	visible_bounds.size.height = MAX(0.0, visible_bounds.size.height - 1.0);
	if (!view.layer.geometryFlipped) visible_bounds.origin.y += 1.0;
	mask.frame = bounds;
	path = CGPathCreateWithRoundedRect(visible_bounds, 9.0, 9.0, NULL);
	mask.path = path;
	CGPathRelease(path);
	view.layer.mask = mask;
	view.clipsToBounds = YES;
}

static void configure_window(NSWindow *window) {
	NSWindowCollectionBehavior behavior = window.collectionBehavior;
	NSView *content = window.contentView;
	NSView *frame = content.superview;
	SEL selector;

	behavior &= ~(NSWindowCollectionBehaviorCanJoinAllSpaces |
		NSWindowCollectionBehaviorFullScreenPrimary);
	behavior |= NSWindowCollectionBehaviorMoveToActiveSpace |
		NSWindowCollectionBehaviorFullScreenAuxiliary |
		NSWindowCollectionBehaviorParticipatesInCycle;
	if (window.collectionBehavior != behavior) window.collectionBehavior = behavior;
	selector = NSSelectorFromString(@"setNoForeground:");
	if ([window respondsToSelector:selector]) {
		((void (*)(id, SEL, BOOL))objc_msgSend)(window, selector, NO);
	}
	selector = NSSelectorFromString(@"setDisabled:");
	if ([window respondsToSelector:selector]) {
		((void (*)(id, SEL, BOOL))objc_msgSend)(window, selector, NO);
	}
	selector = NSSelectorFromString(@"setPreventsAppActivation:");
	if ([window respondsToSelector:selector]) {
		((void (*)(id, SEL, BOOL))objc_msgSend)(window, selector, NO);
	}
	if ((window.styleMask & NSWindowStyleMaskNonactivatingPanel) != 0) {
		window.styleMask &= ~NSWindowStyleMaskNonactivatingPanel;
	}
	selector = NSSelectorFromString(@"_setPreventsActivation:");
	if ([window respondsToSelector:selector]) {
		((void (*)(id, SEL, BOOL))objc_msgSend)(window, selector, NO);
	}
	if (window.ignoresMouseEvents) window.ignoresMouseEvents = NO;
	if (window.hasShadow) window.hasShadow = NO;
	if (![window.backgroundColor isEqual:NSColor.clearColor]) {
		window.backgroundColor = NSColor.clearColor;
	}
	if (window.opaque) window.opaque = NO;
	if (content != nil && !content.wantsLayer) content.wantsLayer = YES;
	if (frame != nil) {
		if (!frame.wantsLayer) frame.wantsLayer = YES;
		frame.layer.backgroundColor = NSColor.clearColor.CGColor;
	}
	apply_notice_mask(frame != nil ? frame : content);
}

static NSWindow *notice_window(void) {
	NSWindow *candidate = nil;

	for (NSWindow *window in NSApp.windows) {
		if (!window.visible || window.frame.size.width < 400 || window.frame.size.height < 300) {
			continue;
		}
		if (candidate == nil ||
			window.frame.size.width * window.frame.size.height >
				candidate.frame.size.width * candidate.frame.size.height) {
			candidate = window;
		}
	}
	return candidate;
}

static void maintain_presentation(void) {
	NSWindow *window = notice_window();
	struct game_window game;

	if (window == nil) return;
	configure_window(window);
	if (NSApp.activationPolicy != NSApplicationActivationPolicyAccessory) {
		[NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
		fprintf(
			stderr,
			"platform-window-bridge: accessory policy pid=%d class=%s canKey=%d\n",
			getpid(),
			class_getName(window.class),
			window.canBecomeKeyWindow
		);
	}
	game = game_window_info();
	if (game.number != kCGNullWindowID) {
		pid_t frontmost_process =
			NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier;
		NSWindowLevel target_level =
			(frontmost_process == game.process_id || frontmost_process == getpid())
				? NSFloatingWindowLevel
				: NSNormalWindowLevel;

		if (window.level != target_level) window.level = target_level;
		if (logged_game_window != game.number) {
			fprintf(
				stderr,
				"platform-window-bridge: found notice=%ld game=%u pid=%d\n",
				(long)window.windowNumber,
				game.number,
				game.process_id
			);
			logged_game_window = game.number;
		}
	}
}

__attribute__((constructor)) static void install_platform_process_bridge(void) {
	if (launcher_marker[0] == '\0') return;
	fprintf(
		stderr,
		"platform-window-bridge: loaded pid=%d process=%s\n",
		getpid(),
		NSProcessInfo.processInfo.processName.UTF8String
	);

	dispatch_async(dispatch_get_main_queue(), ^{
		presentation_timer = dispatch_source_create(
			DISPATCH_SOURCE_TYPE_TIMER,
			0,
			0,
			dispatch_get_main_queue()
		);
		dispatch_source_set_timer(
			presentation_timer,
			dispatch_time(DISPATCH_TIME_NOW, 0),
			NSEC_PER_MSEC * 100,
			NSEC_PER_MSEC * 10
		);
		dispatch_source_set_event_handler(presentation_timer, ^{
			maintain_presentation();
		});
		dispatch_resume(presentation_timer);
	});
}
