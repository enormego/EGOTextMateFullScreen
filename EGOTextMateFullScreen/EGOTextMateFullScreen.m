//
//  EGOTextMateFullScreen.m
//  EGOTextMateFullScreen
//
//  Created by Shaun Harrison on 7/2/11.
//  Copyright 2011 enormego. All rights reserved.
//

#import "EGOTextMateFullScreen.h"
#import <objc/objc-class.h>
#import "OakDocumentController_EGOTextMateFullScreen.h"
#import "OakProjectController_EGOTextMateFullScreen.h"

void egotmfs_appendMethod(Class aClass, Class bClass, SEL bSel);
BOOL egotmfs_methodSwizzle(Class klass, SEL origSel, SEL altSel, BOOL forInstance);

static BOOL hasSwizzled = NO;


@implementation EGOTextMateFullScreen

+ (void)initialize {
	[super initialize];
	
	if(!hasSwizzled) {
		egotmfs_appendMethod(NSClassFromString(@"OakDocumentController"), [OakDocumentController_EGOTextMateFullScreen class], @selector(windowDidLoad_EGOTextMateFullScreen));
		egotmfs_methodSwizzle(NSClassFromString(@"OakDocumentController"), @selector(windowDidLoad), @selector(windowDidLoad_EGOTextMateFullScreen), YES);

		egotmfs_appendMethod(NSClassFromString(@"OakProjectController"), [OakProjectController_EGOTextMateFullScreen class], @selector(windowDidLoad_EGOTextMateFullScreen));
		egotmfs_methodSwizzle(NSClassFromString(@"OakProjectController"), @selector(windowDidLoad), @selector(windowDidLoad_EGOTextMateFullScreen), YES);

		hasSwizzled = YES;
		
		// If windows were opened before this plugin was loaded, we loop through and turn on full screen
		for(NSWindow* window in [NSApplication sharedApplication].windows) {
			if([window.windowController isKindOfClass:NSClassFromString(@"OakDocumentController")] || 
			   [window.windowController isKindOfClass:NSClassFromString(@"OakProjectController")]) {
				window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
			}
		}
		
		// Add the full screen menu item shortcut
		for(NSMenuItem* item in [NSApplication sharedApplication].mainMenu.itemArray) {
			if(![item hasSubmenu]) continue;
			if(![item.title isEqualToString:NSLocalizedString(@"View", @"View")]) continue;
			[item.submenu addItemWithTitle:@"" action:@selector(toggleFullScreen:) keyEquivalent:@"f"].keyEquivalentModifierMask = NSControlKeyMask | NSAlternateKeyMask;
			break;
		}
	}
}

- (id)initWithPlugInController:(id)aController {
    if ((self = [super init])) {
        // Initialization code here.
    }
    
    return self;
}

@end

#pragma mark -
#pragma mark Method swizzling

void egotmfs_appendMethod(Class aClass, Class bClass, SEL bSel) {
	if(!aClass) return;
	if(!bClass) return;
	Method bMethod = class_getInstanceMethod(bClass, bSel);
	class_addMethod(aClass, method_getName(bMethod), method_getImplementation(bMethod), method_getTypeEncoding(bMethod));
}

/**
 * @credit http://www.cocoadev.com/index.pl?MethodSwizzling
 */
BOOL egotmfs_methodSwizzle(Class klass, SEL origSel, SEL altSel, BOOL forInstance) {
    // Make sure the class isn't nil
	if (klass == nil)
		return NO;
	
	// Look for the methods in the implementation of the immediate class
	Class iterKlass = (forInstance ? klass : klass->isa);
	Method origMethod = NULL, altMethod = NULL;
	unsigned int methodCount = 0;
	Method *mlist = class_copyMethodList(iterKlass, &methodCount);
	if(mlist != NULL) {
		int i;
		for (i = 0; i < methodCount; ++i) {
			if(method_getName(mlist[i]) == origSel )
				origMethod = mlist[i];
			if (method_getName(mlist[i]) == altSel)
				altMethod = mlist[i];
		}
	}
	
	// if origMethod was not found, that means it is not in the immediate class
	// try searching the entire class hierarchy with class_getInstanceMethod
	// if not found or not added, bail out
	if(origMethod == NULL) {
		origMethod = class_getInstanceMethod(iterKlass, origSel);
		if(origMethod == NULL) {
			return NO;
		}
		
		if(class_addMethod(iterKlass, method_getName(origMethod), method_getImplementation(origMethod), method_getTypeEncoding(origMethod)) == NO) {
			return NO;
		}
	}
	
	// same thing with altMethod
	if(altMethod == NULL) {
		altMethod = class_getInstanceMethod(iterKlass, altSel);
		if(altMethod == NULL ) 
			return NO;
		if(class_addMethod(iterKlass, method_getName(altMethod), method_getImplementation(altMethod), method_getTypeEncoding(altMethod)) == NO )
			return NO;
	}
	
	//clean up
	free(mlist);
	
	// we now have to look up again for the methods in case they were not in the class implementation,
	//but in one of the superclasses. In the latter, that means we added the method to the class,
	//but the Leopard APIs is only 'class_addMethod', in which case we need to have the pointer
	//to the Method objects actually stored in the Class structure (in the Tiger implementation, 
	//a new mlist was explicitely created with the added methods and directly added to the class; 
	//thus we were able to add a new Method AND get the pointer to it)
	
	// for simplicity, just use the same code as in the first step
	origMethod = NULL;
	altMethod = NULL;
	methodCount = 0;
	mlist = class_copyMethodList(iterKlass, &methodCount);
	if(mlist != NULL) {
		int i;
		for (i = 0; i < methodCount; ++i) {
			if(method_getName(mlist[i]) == origSel )
				origMethod = mlist[i];
			if (method_getName(mlist[i]) == altSel)
				altMethod = mlist[i];
		}
	}
	
	// bail if one of the methods doesn't exist anywhere
	// with all we did, this should not happen, though
	if (origMethod == NULL || altMethod == NULL)
		return NO;
	
	// now swizzle
	method_exchangeImplementations(origMethod, altMethod);
	
	//clean up
	free(mlist);
	
	return YES;
}
