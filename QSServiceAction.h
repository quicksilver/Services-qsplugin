

#import <Foundation/Foundation.h>

#define NSServicesKey	 		@"NSServices"
#define NSMenuItemKey	 		@"NSMenuItem"

#define NSSendTypesKey	 		@"NSSendTypes"
#define NSSendFilesTypesKey     @"NSSendFileTypes"
#define NSReturnTypesKey	 	@"NSReturnTypes"

#define DefaultKey	 		    @"default"
#define infoPath			    @"Contents/Info.plist"

#define kQSServicesMenuPlugInType @"QSServicesMenuPlugInType"
#define kBundleID               @"com.blacktree.Quicksilver.QSServicesMenuPlugIn"

@interface QSServiceActions : QSActionProvider {
    NSString *serviceBundle;
    NSArray *serviceArray;
    NSDictionary *modificationsDictionary;
}

@property (nonatomic, retain) NSString *serviceBundle;
@property (nonatomic, retain) NSArray *serviceArray;
@property (nonatomic, retain) NSDictionary *modificationsDictionary;

+ (NSArray *) allServiceActions;
+ (QSServiceActions *) serviceActionsForBundle:(NSString *)path;
- (id) initWithBundlePath:(NSString *)path;
@end
