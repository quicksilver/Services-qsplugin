

#import <Foundation/Foundation.h>

#define kQSServicesMenuPlugInType @"QSServicesMenuPlugInType"

@interface QSServiceActions : QSActionProvider {
    NSString *serviceBundle;
    NSArray *serviceArray;
    NSDictionary *modificationsDictionary;
}

+ (NSArray *) allServiceActions;
+ (QSServiceActions *) serviceActionsForBundle:(NSString *)path;
- (id) initWithBundlePath:(NSString *)path;
@end
