

#import "QSServiceAction.h"
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
    for (NSString *itemPath in subPaths){
        if ([itemPath hasSuffix:infoPath]) {
            itemPath = [path stringByAppendingPathComponent:itemPath];
            NSArray *servicesArray = [[NSDictionary dictionaryWithContentsOfFile:itemPath] objectForKey:NSServicesKey];
            for (NSDictionary *servicesDict in servicesArray) {
                if ([servicesDict isKindOfClass:[NSDictionary class]] && [servicesDict count]) {
                    [providers addObject:[QSServiceActions serviceActionsForBundle:[[itemPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent]]];
                }
            }
        }
    }
    return providers;
}

NSArray *QSServicesPlugin_applicationProviders() {
    NSMutableArray *providers = [NSMutableArray arrayWithCapacity:1];
    
    NSArray *apps = [[NSWorkspace sharedWorkspace] allApplications];
    for (NSString *itemPath in apps){
        NSArray *servicesArray = [[NSDictionary dictionaryWithContentsOfFile:[itemPath stringByAppendingPathComponent:infoPath]] objectForKey:NSServicesKey];
        for (NSDictionary *servicesDict in servicesArray) {
            if ([servicesDict isKindOfClass:[NSDictionary class]] && [servicesDict count]) {
                [providers addObject:[QSServiceActions serviceActionsForBundle:itemPath]];
            } 
        }
    }
    return providers;
}

@implementation QSServiceActions

+ (void)loadPlugIn {
    dispatch_async(dispatch_get_global_queue(0,0),^{
        [self loadServiceActions];
    });
}


+ (void)loadServiceActions {	
	[[QSTaskController sharedInstance] updateTask:@"Load Actions" status:@"Loading Application Services" progress:-1];
    NSArray *serviceActions = [QSServiceActions allServiceActions];
    
    for (QSServiceActions *individualAction in serviceActions) {
        /* Note: calling dispatch_sync(main_thread) isn't necessarily equiv to calling [NSThread performSelectorOnMainThread...] (previously used) but in this case it's fine, as loadServiceActions is ALWAYS called on a background thread. See http://stackoverflow.com/questions/5225130/grand-central-dispatch-gcd-vs-performselector-need-a-better-explanation */
        dispatch_sync(dispatch_get_main_queue(), ^{
        [QSExec addActions:[individualAction actions]];
        });
    }
    QSPlugIn *thisPlugin = [QSPlugIn plugInWithBundle:[NSBundle bundleForClass:[self class]]];
    
    // Send a 'plugin loaded' notif so things like the list of actions (in the prefs) gets updated
    [[NSNotificationCenter defaultCenter] postNotificationName:QSPlugInLoadedNotification object:thisPlugin];
	[[QSTaskController sharedInstance] removeTask:@"Load Actions"];
}


// returns an array of path strings giving the paths of the bundle that contains the service
+ (NSArray *)allServiceActions {
    NSMutableSet *actionObjects = [NSMutableSet setWithCapacity:1];
    [actionObjects addObjectsFromArray:QSServicesPlugin_applicationProviders()];
    [actionObjects addObjectsFromArray:QSServicesPlugin_providersAtPath(@"/System/Library/Services/")];
    [actionObjects addObjectsFromArray:QSServicesPlugin_providersAtPath(@"/Library/Services/")];
    [actionObjects addObjectsFromArray:QSServicesPlugin_providersAtPath(@"~/Library/Services/")];
    
    return [actionObjects allObjects];
}

+ (QSServiceActions *)serviceActionsForBundle:(NSString *)path {
    //NSLog(@"Loading Actions for Bundle: %@",path);
    return [[[QSServiceActions alloc] initWithBundlePath:path] autorelease];
}

-(void)dealloc {
    [serviceBundle release];
    [serviceArray release];
    [modificationsDictionary release];
    [super dealloc];
}

- (id)initWithBundlePath:(NSString *)path {
    if (self = [super init]) {
        serviceBundle = [path copy];
        serviceArray = [QSServicesPlugin_servicesForBundle(path) retain];
        NSString *bundleIdentifier = [[NSBundle bundleWithPath:path] bundleIdentifier];
        modificationsDictionary = [[[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle:] pathForResource:@"NSServiceModifications" ofType:@"plist"]] objectForKey:bundleIdentifier] retain];
    }
    return self;
}

- (NSArray *)types{ return nil; }

- (NSArray *)actions {    
    if (![serviceArray count]) {
        return nil;
    }
    NSMutableArray *newActions = [NSMutableArray arrayWithCapacity:1];
    NSImage *actionIcon = [[NSWorkspace sharedWorkspace] iconForFile:serviceBundle];
    [actionIcon setSize:NSMakeSize(16, 16)];
    NSBundle *servicesBundle = [NSBundle bundleWithIdentifier:kBundleID];
    NSString *serviceString = nil;
    for (NSDictionary *thisService in serviceArray) {
        @try {
            serviceString = [[thisService objectForKey:NSMenuItemKey] objectForKey:DefaultKey];
        }
        @catch (NSException *exception) {
            NSLog(@"Exception: %@ for service array: %@",exception,serviceArray);
        }
        
        if (!serviceString) {
            continue;
        }
        NSDictionary *serviceModifications = [modificationsDictionary objectForKey:serviceString];
        
        if ([[serviceModifications objectForKey:@"disabled"] boolValue])
            continue;
        
        QSAction *serviceAction = [[QSAction alloc] init];
        [serviceAction setIdentifier:serviceString];
		
        if ([serviceModifications objectForKey:@"name"])
            [serviceAction setName:[serviceModifications objectForKey:@"name"]];
		
        NSArray *sendTypes = [thisService objectForKey:NSSendTypesKey];
        
        // If the service is for specific file types, add as direct file types
        if ([thisService objectForKey:@"NSSendFileTypes"]) {
            if (![sendTypes containsObject:QSFilePathType]) {
                sendTypes = [sendTypes arrayByAddingObject:QSFilePathType];
            }
            NSMutableArray *directFileTypes = [[thisService objectForKey:@"NSSendFileTypes"] mutableCopy];
            // public.item UTI refers to all files
            [directFileTypes removeObject:@"public.item"];
            if ([directFileTypes count]) {
                [serviceAction setDirectFileTypes:[thisService objectForKey:@"NSSendFileTypes"]];
            }
            [directFileTypes release];
        }
        
		if (sendTypes) {
//            This is a **dirty hack** to deal with Quicksilver's lack of UTI support. public.utf8-plaint-text = NSStringPboardType
            if ([sendTypes containsObject:@"public.utf8-plain-text"]) {
                sendTypes = [sendTypes arrayByAddingObject:NSStringPboardType];
            }
            [serviceAction setDirectTypes:sendTypes];
		}
		
        [serviceAction setBundle:servicesBundle];
		[serviceAction setIcon:actionIcon];
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
            @try {
                menuItem = [[thisService objectForKey:NSMenuItemKey] objectForKey:DefaultKey];
            }
            @catch (NSException *exception) {
                NSLog(@"Exception: %@ for service array %@",exception,serviceArray);
            }
            
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
            @try {
                if ([[[thisService objectForKey:NSMenuItemKey] objectForKey:DefaultKey] isEqualToString:[action identifier]]) {
                    NSArray *sendTypes = [thisService objectForKey:NSSendTypesKey];
                    if ([thisService objectForKey:@"NSSendFileTypes"]) {
                        sendTypes = [sendTypes arrayByAddingObject:NSFilenamesPboardType];
                    }
                    [dObject putOnPasteboard:pboard declareTypes:sendTypes includeDataForTypes:sendTypes];
                    break;
                }
            }
            @catch (NSException *exception) {
                NSLog(@"Exception: %@ in service array: %@",exception,serviceArray);
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
