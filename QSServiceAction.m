

#import "QSServiceAction.h"

#import <QSCore/QSCore.h>
#import <QSCore/QSObject_Pasteboard.h>
#import <QSCore/QSLibrarian.h>
#import <QSCore/QSExecutor.h>
#import <QSFoundation/NSWorkspace_BLTRExtensions.h>


#define NSServicesKey	 		@"NSServices"
#define NSMenuItemKey	 		@"NSMenuItem"
#define NSMenuItemDisabledKey 		@"NSMenuItem (Disabled)"

#define NSSendTypesKey	 		@"NSSendTypes"
#define NSReturnTypesKey	 	@"NSReturnTypes"

#define DefaultKey	 		@"default"
#define NSKeyEquivalentKey 		@"NSKeyEquivalent"
#define infoPath			@"Contents/Info.plist"

#define kBundleID @"com.blacktree.Quicksilver.QSServicesMenuPlugIn"

NSArray *QSServicesPlugin_servicesForBundle(NSString *path) {
    if (path) {
        NSString *dictPath = [path stringByAppendingPathComponent:infoPath];
        NSDictionary *infoDictionary = [NSDictionary dictionaryWithContentsOfFile:dictPath];
        if ([infoDictionary isKindOfClass:[NSDictionary class]]) {
            NSArray* array = [infoDictionary objectForKey:NSServicesKey];
            if ([array isKindOfClass:[NSArray class]]) {
                return array;
            }
        }
    }
    return nil;
}
NSArray *QSServicesPlugin_providersAtPath(NSString *path) {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSMutableArray *providers = [NSMutableArray arrayWithCapacity:1];
       
    path = [path stringByStandardizingPath];
    NSArray *subPaths = [manager subpathsAtPath:path];
    @autoreleasepool {
        for (NSString *itemPath in subPaths){
            if ([itemPath hasSuffix:infoPath]) {
                itemPath = [path stringByAppendingPathComponent:itemPath];
                NSDictionary *servicesDict = [[NSDictionary dictionaryWithContentsOfFile:itemPath] objectForKey:NSServicesKey];
                if ([servicesDict isKindOfClass:[NSDictionary class]] && [servicesDict count]) {
                    [providers addObject:[[itemPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent]];
                }
            }
        }
    }
    return providers;
}

NSArray *QSServicesPlugin_applicationProviders() {
    NSMutableArray *providers = [NSMutableArray arrayWithCapacity:1];

    
    NSArray *apps = [[NSWorkspace sharedWorkspace] allApplications];
    @autoreleasepool {
        for (NSString *itemPath in apps){
            NSDictionary *servicesDict = [[NSDictionary dictionaryWithContentsOfFile:[itemPath stringByAppendingPathComponent:infoPath]] objectForKey:NSServicesKey];
            if ([servicesDict isKindOfClass:[NSDictionary class]] && [servicesDict count]) {
                [providers addObject:itemPath];
            }
        }
    }
    return providers;
}

@implementation QSServiceActions

+ (void)loadPlugIn {
	[NSThread detachNewThreadSelector:@selector(loadServiceActions) toTarget:self withObject:nil];
}

+ (void)loadServiceActions {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[[QSTaskController sharedInstance] updateTask:@"Load Actions" status:@"Loading Application Services" progress:-1];
    NSArray *serviceActions = [QSServiceActions allServiceActions];

    @autoreleasepool {
        for (id individualAction in serviceActions) {
            [QSExec performSelectorOnMainThread:@selector(addActions:) withObject:[individualAction actions] waitUntilDone:YES];
        }
    }
	//NSLog(@"Services Loaded");
	[[QSTaskController sharedInstance] removeTask:@"Load Actions"];
    [pool release];
}


+ (NSArray *)allServiceActions {
    NSMutableSet *providerSet = [NSMutableSet setWithCapacity:1];
    [providerSet addObjectsFromArray:QSServicesPlugin_applicationProviders()];
    [providerSet addObjectsFromArray:QSServicesPlugin_providersAtPath(@"/System/Library/Services/")];
    [providerSet addObjectsFromArray:QSServicesPlugin_providersAtPath(@"/Library/Services/")];
    [providerSet addObjectsFromArray:QSServicesPlugin_providersAtPath(@"~/Library/Services/")];
    NSArray *providerArray = [providerSet allObjects];
    NSMutableArray *actionObjects = [NSMutableArray arrayWithCapacity:[providerArray count]];
    
    @autoreleasepool {
        for (id individualProvider in providerArray) {
            [actionObjects addObject:[[self class] serviceActionsForBundle:individualProvider]];
        }
    }
    
    return actionObjects;
}

+ (QSServiceActions *)serviceActionsForBundle:(NSString *)path {
    //NSLog(@"Loading Actions for Bundle: %@",path);
    return [[[[self class] alloc] initWithBundlePath:path] autorelease];
}

- (id)initWithBundlePath:(NSString *)path {
    if (self = [super init]) {
        serviceBundle = [path copy];
        serviceArray = [QSServicesPlugin_servicesForBundle(path) retain];
        NSString *bundleIdentifier = [[NSBundle bundleWithPath:path] bundleIdentifier];
        modificationsDictionary = [[[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"NSServiceModifications" ofType:@"plist"]] objectForKey:bundleIdentifier] retain];
    }
    return self;
}

- (NSArray *)types{ return nil; }

- (NSArray *)actions {
    NSMutableArray *newActions = [NSMutableArray arrayWithCapacity:1];
    NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:serviceBundle];
    [icon setSize:NSMakeSize(16, 16)];
    
    if (![serviceArray count]) {
        return nil;
    }
    NSBundle *servicesBundle = [NSBundle bundleWithIdentifier:kBundleID];
    
    for (NSDictionary *thisService in serviceArray) {
        NSString *serviceString = [[thisService objectForKey:NSMenuItemKey] objectForKey:DefaultKey];
        
        if (!serviceString) {
            continue;
        }
        id serviceModifications = [modificationsDictionary objectForKey:serviceString];
        
        if ([serviceModifications isKindOfClass:[NSString class]]) {
            NSLog(@"Couldn't get action for %@ with service string %@",thisService,serviceString);
            continue;
        }
        
        if ([[(NSDictionary *)serviceModifications objectForKey:@"disabled"] boolValue])
            continue;
        
        QSAction *serviceAction = [[QSAction alloc] init];
        [serviceAction setIdentifier:serviceString];
		
        if ([(NSDictionary *)serviceModifications objectForKey:@"name"])
            [serviceAction setName:[(NSDictionary *)serviceModifications objectForKey:@"name"]];
		
		NSArray *sendTypes = [thisService objectForKey:NSSendTypesKey];
        
		if (sendTypes) {
			[serviceAction setDirectTypes:sendTypes];
		}
		
        [serviceAction setBundle:servicesBundle];
		[serviceAction setIcon:icon];
        [serviceAction setIconLoaded:YES];
		[serviceAction setProvider:self];
		[serviceAction setDisplaysResult:YES];
		[serviceAction setDetails:[NSString stringWithFormat:@"A service of %@",[serviceBundle lastPathComponent]]];
		
		[newActions addObject:serviceAction];

    }
	return newActions;
}

- (NSArray *)validActionsForDirectObject:(QSObject *)dObject indirectObject:(QSObject *)iObject {
    
    BOOL fileType = [[dObject primaryType]isEqualToString:NSFilenamesPboardType];
    if (fileType && ![dObject validPaths])
        return nil;
	NSMutableArray *newActions = [NSMutableArray arrayWithCapacity:1];
    
    NSString *menuItem;
	// NSLog(@"services%@", serviceArray);
    @autoreleasepool {
        for (NSDictionary *thisService in serviceArray) {
            menuItem = [[thisService objectForKey:NSMenuItemKey] objectForKey:DefaultKey];
            
            BOOL disabled = [[[modificationsDictionary objectForKey:menuItem] objectForKey:@"disabled"] boolValue];
            if (menuItem && !disabled) {
                NSSet *sendTypes = [NSSet setWithArray:[thisService objectForKey:NSSendTypesKey]];
                NSSet *availableTypes = [NSSet setWithArray:[dObject types]];
                
                // Add if they intersect, but ignore ex
                if ([sendTypes intersectsSet:availableTypes]){
                    if (fileType && ![sendTypes containsObject:NSFilenamesPboardType])
                        continue;
                    
                    [newActions addObject:menuItem];
                }
            }
        }
    }
	
    return newActions;
}


- (QSObject *)performAction:(QSAction *)action directObject:(QSBasicObject *)dObject indirectObject:(QSBasicObject *)iObject {
    NSPasteboard *pboard = [NSPasteboard pasteboardWithUniqueName];
    NSDictionary *thisService = nil;
	//NSLog(@"perform %@ %@ %@",[action actionDict],serviceArray,self);

    @autoreleasepool {
        for (thisService in serviceArray) {
            // NSLog(@"'%@' '%@'",[action identifier],[[thisService objectForKey:NSMenuItemKey]objectForKey:DefaultKey]);
            
            if ([[[thisService objectForKey:NSMenuItemKey] objectForKey:DefaultKey] isEqualToString:[action identifier]]) {
                NSArray *sendTypes = [thisService objectForKey:NSSendTypesKey];
                [dObject putOnPasteboard:pboard declareTypes:sendTypes includeDataForTypes:sendTypes];
                break;
            }
        }
    }
    
    BOOL success = NSPerformService([action identifier], pboard);
    if (success) {
        QSObject *entry = nil;
        if ([thisService objectForKey:NSReturnTypesKey])
            entry = [[QSObject alloc] initWithPasteboard:pboard types:[thisService objectForKey:NSReturnTypesKey]];
        return entry;
    }
    NSLog(@"PerformServiceFailed: %@, %@\r%@\r%@", action, dObject, serviceBundle, [[pboard types] componentsJoinedByString:@", "]);
    return nil;
}

- (BOOL)performServiceWithNameAndPasteboard:(NSArray *)array {
    return NSPerformService([array objectAtIndex:0], [array lastObject]);
}

@end
