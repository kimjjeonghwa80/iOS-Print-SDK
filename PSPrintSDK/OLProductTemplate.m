//
//  OLProductTemplate.m
//  PS SDK
//
//  Created by Deon Botha on 18/03/2014.
//  Copyright (c) 2014 Deon Botha. All rights reserved.
//

#import "OLProductTemplate.h"
#import "OLProductTemplateSyncRequest.h"
#import "OLCountry.h"

NSString *const kNotificationTemplateSyncComplete = @"co.oceanlabs.pssdk.notification.kNotificationSyncComplete";
NSString *const kNotificationKeyTemplateSyncError = @"co.oceanlabs.pssdk.notification.kNotificationKeyTemplateSyncError";

NSString *const kOLDefaultTemplateForSquarePrints = @"squares";
NSString *const kOLDefaultTemplateForSquareMiniPrints = @"squares_mini";
NSString *const kOLDefaultTemplateForMagnets = @"magnets";
NSString *const kOLDefaultTemplateForPolaroidStylePrints = @"polaroids";
NSString *const kOLDefaultTemplateForPolaroidStyleMiniPrints = @"polaroids_mini";
NSString *const kOLDefaultTemplateForPostcard = @"ps_postcard";
NSString *const kOLDefaultTemplateForFrames2x2 = @"frames_2";
NSString *const kOLDefaultTemplateForFrames3x3 = @"frames_3";
NSString *const kOLDefaultTemplateForFrames4x4 = @"frames_4";

static NSString *const kKeyIdentifier = @"co.oceanlabs.pssdk.kKeyIdentifier";
static NSString *const kKeyName = @"co.oceanlabs.pssdk.kKeyName";
static NSString *const kKeyQuantity = @"co.oceanlabs.pssdk.kKeyQuantity";
static NSString *const kKeyEnabled = @"co.oceanlabs.pssdk.kKeyEnabled";
static NSString *const kKeyCostsByCurrency = @"co.oceanlabs.pssdk.kKeyCostsByCurrency";

static NSMutableArray *templates;
static NSDate *lastSyncDate;
static OLProductTemplateSyncRequest *inProgressSyncRequest = nil;

@interface OLProductTemplate ()
@property (nonatomic, strong) NSDictionary/*<NSString, NSDecimalNumber>*/ *costsByCurrencyCode;
@end

@interface OLCountry (Private)
+ (BOOL)isValidCurrencyCode:(NSString *)code;
@end

@implementation OLProductTemplate

- (id)initWithIdentifier:(NSString *)identifier name:(NSString *)name sheetQuantity:(NSUInteger)quantity sheetCostsByCurrencyCode:(NSDictionary/*<String, NSDecimalNumber>*/*)costs enabled:(BOOL)enabled {
    if (self = [super init]) {
        _identifier = identifier;
        _name = name;
        _quantityPerSheet = quantity;
        self.costsByCurrencyCode = costs;
        _enabled = enabled;
    }
    
    return self;
}

+ (NSString *)templatesFilePath {
    NSArray * urls = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSString *documentDirPath = [(NSURL *)[urls objectAtIndex:0] path];
    return [documentDirPath stringByAppendingPathComponent:@"co.oceanlabs.pssdk.Templates"];
}

- (NSDecimalNumber *)costPerSheetInCurrencyCode:(NSString *)currencyCode {
    return self.costsByCurrencyCode[currencyCode];
}

- (NSArray *)currenciesSupported {
    NSMutableArray *codes = [[NSMutableArray alloc] init];
    for (NSString *code in self.costsByCurrencyCode) {
        [codes addObject:code];
    }
    return codes;
}

+ (void)sync {
    if (inProgressSyncRequest == nil) {
        inProgressSyncRequest = [[OLProductTemplateSyncRequest alloc] init];
        [inProgressSyncRequest sync:^(NSArray *templates_, NSError *error) {
            inProgressSyncRequest = nil;
            if (error) {
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationTemplateSyncComplete object:self userInfo:@{kNotificationKeyTemplateSyncError: error}];
            } else {
                [self saveTemplatesAsLatest:templates_];
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationTemplateSyncComplete object:self userInfo:nil];
            }
        }];
    }
}

+ (BOOL)isSyncInProgress {
    return inProgressSyncRequest != nil;
}

+ (OLProductTemplate *)templateWithId:(NSString *)identifier {
    NSArray *templates = [OLProductTemplate templates];
    for (OLProductTemplate *template in templates) {
        if ([template.identifier isEqualToString:identifier]) {
            return template;
        }
    }
    
    NSAssert(NO, @"Template with id '%@' not found. Please ensure you've provided a OLProductTemplates.plist file detailing your print templates or run OLProductTemplate.sync first if your templates are defined in the developer dashboard", identifier);
    return nil;
}

+ (void)saveTemplatesAsLatest:(NSArray *)templates_ {
    templates = [NSMutableArray arrayWithArray:templates_];
    lastSyncDate = [NSDate date];
    [NSKeyedArchiver archiveRootObject:@[lastSyncDate, templates] toFile:[OLProductTemplate templatesFilePath]];
}

+ (NSDate *)lastSyncDate {
    return lastSyncDate;
}

+ (NSMutableArray *)templatesFromBundledPlist {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"OLProductTemplates" ofType:@"plist"];
    NSMutableArray *plist = [[NSMutableArray alloc] initWithContentsOfFile:path];
    
    NSMutableArray *templates = [[NSMutableArray alloc] init];
    for (id template in plist) {
        if ([template isKindOfClass:[NSDictionary class]]) {
            id templateId = template[@"OLTemplateId"];
            id templateName = template[@"OLTemplateName"];
            id sheetQuantity = template[@"OLSheetQuanity"];
            id enabled = template[@"OLEnabled"] ? template[@"OLEnabled"] : [NSNumber numberWithInt:1];
            id sheetCosts = template[@"OLSheetCosts"];
            if ([templateId isKindOfClass:[NSString class]] && [templateName isKindOfClass:[NSString class]]
                && [sheetQuantity isKindOfClass:[NSNumber class]] && [enabled isKindOfClass:[NSNumber class]]
                && [sheetCosts isKindOfClass:[NSDictionary class]]) {
                
                NSMutableDictionary/*<String, NSDecimalNumber>*/ *costs = [[NSMutableDictionary alloc] init];
                for (id key in sheetCosts) {
                    id val = sheetCosts[key];
                    if ([key isKindOfClass:[NSString class]] && [val isKindOfClass:[NSString class]]) {
                        if ([OLCountry isValidCurrencyCode:key]) {
                            NSDecimalNumber *cost = [NSDecimalNumber decimalNumberWithString:val];
                            costs[key] = cost;
                        }
                    }
                }
                
                [templates addObject:[[OLProductTemplate alloc] initWithIdentifier:templateId name:templateName sheetQuantity:[sheetQuantity unsignedIntegerValue] sheetCostsByCurrencyCode:costs enabled:[enabled boolValue]]];
            }
        }
    }
    return templates;
}

+ (NSArray *)templates {
    if (!templates) {
        NSArray *components = [NSKeyedUnarchiver unarchiveObjectWithFile:[OLProductTemplate templatesFilePath]];
        if (!components) {
            lastSyncDate = nil;
            templates = [self templatesFromBundledPlist];
            
        } else {
            lastSyncDate = components[0];
            templates = components[1];
        }
    }
    
    return templates;
}

- (NSString *)description {
    NSMutableString *supportedCurrencies = [[NSMutableString alloc] init];
    for (NSString *currency in self.costsByCurrencyCode) {
        [supportedCurrencies appendFormat:@" %@", currency];
    }
    return [NSString stringWithFormat:@"%@%@ (%@)%@ quantity: %d",self.enabled ? @"enabled " : @"disabled ", self.identifier, self.name, supportedCurrencies, self.quantityPerSheet];
}

#pragma mark - NSCoding protocol methods

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.identifier forKey:kKeyIdentifier];
    [aCoder encodeObject:self.name forKey:kKeyName];
    [aCoder encodeInteger:self.quantityPerSheet forKey:kKeyQuantity];
    [aCoder encodeBool:self.enabled forKey:kKeyEnabled];
    [aCoder encodeObject:self.costsByCurrencyCode forKey:kKeyCostsByCurrency];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        _identifier = [aDecoder decodeObjectForKey:kKeyIdentifier];
        _name = [aDecoder decodeObjectForKey:kKeyName];
        _quantityPerSheet = [aDecoder decodeIntegerForKey:kKeyQuantity];
        _enabled = [aDecoder decodeBoolForKey:kKeyEnabled];
        _costsByCurrencyCode = [aDecoder decodeObjectForKey:kKeyCostsByCurrency];
    }
    
    return self;
}

@end
