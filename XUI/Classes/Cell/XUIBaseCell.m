//
// Created by Zheng on 28/07/2017.
// Copyright (c) 2017 Zheng. All rights reserved.
//

#import "XUIBaseCell.h"
#import "XUILogger.h"
#import "XUIPrivate.h"
#import "XUICellFactory.h"

#import <objc/runtime.h>
#import "UITableViewCell+XUIDisclosureIndicatorColor.h"

NSString * XUIBaseCellReuseIdentifier = @"XUIBaseCellReuseIdentifier";

@interface XUIBaseCell ()
@property (nonatomic, strong) UIView *validationView;

@end

@implementation XUIBaseCell {

}

#pragma mark - Layouts

+ (BOOL)xibBasedLayout {
    return NO;
}

+ (UINib *)cellNib {
    if ([[self class] xibBasedLayout]) {
        static NSMutableDictionary <NSString *, UINib *> *cellNibs = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            cellNibs = [[NSMutableDictionary alloc] init];
        });
        NSString *cellName = NSStringFromClass([self class]);
        if (cellNibs[cellName]) {
            return cellNibs[cellName];
        }
        NSBundle *nibBundle = FRAMEWORK_BUNDLE;
        if (!([nibBundle pathForResource:cellName ofType:@"nib"])) {
            nibBundle = [NSBundle bundleForClass:[self class]];
        }
        if (!([nibBundle pathForResource:cellName ofType:@"nib"])) {
            NSAssert(YES, @"XUI cannot find the xib of \"%@\", please inherit +[XUIBaseCell cellNib] to specify it.", cellName);
            return nil;
        }
        if (nibBundle) {
            UINib *cellNib = [UINib nibWithNibName:cellName bundle:nibBundle];
            if (cellNib) {
                [cellNibs setObject:cellNib forKey:cellName];
                return cellNib;
            }
        }
    }
    return nil;
}

+ (BOOL)layoutNeedsTextLabel {
    return YES;
}

+ (BOOL)layoutNeedsImageView {
    return YES;
}

+ (BOOL)layoutRequiresDynamicRowHeight {
    return NO;
}

+ (BOOL)layoutUsesAutoResizing {
    if (XUI_SYSTEM_8) {
        return NO;
    } else {
        return YES;
    }
}

#pragma mark - Property Tests

+ (NSDictionary <NSString *, NSString *> *)entryValueTypes {
    return @{};
}

+ (BOOL)testEntry:(NSDictionary *)cellEntry error:(NSError **)error {
    NSMutableDictionary *baseTypes =
    [@{
      @"cell": [NSString class],
      @"label": [NSString class],
      @"defaults": [NSString class],
      @"key": [NSString class],
      @"icon": [NSString class],
      @"iconRenderingMode": [NSString class],
      @"enabled": [NSNumber class],
      @"height": [NSNumber class],
      @"postNotification": [NSString class],
      @"theme": [NSDictionary class],
      } mutableCopy];
    [baseTypes addEntriesFromDictionary:[self.class entryValueTypes]];
    for (NSString *pairKey in cellEntry.allKeys) {
        Class pairClass = baseTypes[pairKey];
        if (pairClass) {
            if (![cellEntry[pairKey] isKindOfClass:pairClass]) {
                NSString *errorReason
                = [NSString stringWithFormat:[XUIStrings localizedStringForString:@"key \"%@\", should be \"%@\"."], pairKey, NSStringFromClass(pairClass)];
                NSError *exceptionError
                = [NSError errorWithDomain:kXUICellFactoryErrorInvalidTypeDomain code:400 userInfo:@{ NSLocalizedDescriptionKey: errorReason }];
                if (error) *error = exceptionError;
                return NO;
            }
        }
    }
    for (NSString *pairKey in cellEntry.allKeys) {
        id pairValue = cellEntry[pairKey];
        BOOL testResult = [self testValue:pairValue forKey:pairKey error:error];
        if (!testResult) {
            return NO;
        }
    }
    return YES;
}

+ (BOOL)testValue:(id)value forKey:(NSString *)key error:(NSError **)error {
    if ([key isEqualToString:@"iconRenderingMode"]) {
        if (NO == [@[ @"Automatic", @"AlwaysOriginal", @"AlwaysTemplate" ] containsObject:value])
        {
            NSString *errorReason
            = [NSString stringWithFormat:[XUIStrings localizedStringForString:@"key \"%@\" (\"%@\") is invalid."], @"iconRenderingMode", value];
            NSError *exceptionError
            = [NSError errorWithDomain:kXUICellFactoryErrorUnknownEnumDomain code:400 userInfo:@{ NSLocalizedDescriptionKey: errorReason }];
            if (error) *error = exceptionError;
            return NO;
        }
    }
    return YES;
}

#pragma mark - Initializers

- (NSString *)xui_cell {
    return NSStringFromClass([self class]);
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(nullable NSString *)reuseIdentifier {
    if (self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier]) {
        [self setupCell];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self setupCell];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGRect contentRect = self.contentView.frame;
    self.validationView.frame = CGRectMake(0.0, 0.0, 4.0, CGRectGetHeight(contentRect));
}

- (void)setupCell {
    _xui_readonly = @NO;
    if ([self.class layoutRequiresDynamicRowHeight]) {
        _xui_height = @(-1);
    } else {
        _xui_height = @44.f; // standard cell height
    }
    if ([self.class layoutNeedsTextLabel]) {
        self.textLabel.font = [UIFont systemFontOfSize:16.f];
        self.textLabel.text = nil;
        
        self.detailTextLabel.font = [UIFont systemFontOfSize:16.f];
        self.detailTextLabel.textColor = UIColor.grayColor;
        self.detailTextLabel.text = nil;
    }
    UIView *selectionBackground = [[UIView alloc] init];
    self.selectedBackgroundView = selectionBackground;
    
    [self.contentView addSubview:self.validationView];
}

- (void)configureCellWithEntry:(NSDictionary *)entry {
    for (NSString *itemKey in entry) {
        if ([itemKey isEqualToString:@"value"]) continue;
        NSString *propertyName = [NSString stringWithFormat:@"xui_%@", itemKey];
        if (class_getProperty([self class], [propertyName UTF8String])) {
            id itemValue = entry[itemKey];
            [self setValue:itemValue forKey:propertyName];
        }
    }
    self.xui_value = entry[@"value"]; // do not change its order
}

- (UIView *)validationView {
    if (!_validationView) {
        _validationView = [[UIView alloc] init];
        _validationView.hidden = YES;
    }
    return _validationView;
}

#pragma mark - Key Value

- (id)valueForUndefinedKey:(NSString *)key {
    return nil; // do nothing
}

- (void)setValue:(nullable id)value forUndefinedKey:(NSString *)key {
    // do nothing
}

#pragma mark - XUI Setters

- (void)setXui_icon:(NSString *)xui_icon {
    _xui_icon = xui_icon;
    if ([self.class layoutNeedsImageView]) {
        if (xui_icon) {
            NSBundle *bundle = nil;
            if (self.adapter) {
                bundle = self.adapter.bundle;
            } else {
                bundle = [NSBundle mainBundle];
            }
            NSString *imagePath = [bundle pathForResource:xui_icon ofType:nil];
            self.imageView.image = [self imageWithCurrentRenderingMode:[UIImage imageWithContentsOfFile:imagePath]];
        } else {
            self.imageView.image = nil;
        }
    }
}

- (void)setXui_iconRenderingMode:(NSString *)xui_iconRenderingMode {
    _xui_iconRenderingMode = xui_iconRenderingMode;
    if ([self.class layoutNeedsImageView]) {
        UIImage *originalImage = self.imageView.image;
        if (originalImage)
        {
            self.imageView.image = [self imageWithCurrentRenderingMode:originalImage];
        }
    }
}

- (UIImage *)imageWithCurrentRenderingMode:(UIImage *)image {
    NSString *renderingModeString = _xui_iconRenderingMode;
    UIImageRenderingMode renderingMode = UIImageRenderingModeAutomatic;
    if ([renderingModeString isEqualToString:@"AlwaysOriginal"]) {
        renderingMode = UIImageRenderingModeAlwaysOriginal;
    } else if ([renderingModeString isEqualToString:@"AlwaysTemplate"]) {
        renderingMode = UIImageRenderingModeAlwaysTemplate;
    }
    return [image imageWithRenderingMode:renderingMode];
}

- (void)setXui_label:(NSString *)xui_label {
    _xui_label = xui_label;
    if ([self.class layoutNeedsTextLabel]) {
        if (self.adapter) {
            self.textLabel.text = [self.adapter localizedStringForKey:xui_label value:xui_label];
        } else {
            self.textLabel.text = xui_label;
        }
    }
}

- (void)setXui_value:(id)xui_value {
    _xui_value = xui_value;
}

#pragma mark - Overrides

- (BOOL)canDelete {
    return NO;
}

#pragma mark - Internals

- (void)setInternalTheme:(XUITheme *)theme {
    _internalTheme = theme;
    self.tintColor = theme.foregroundColor;
    self.contentView.tintColor = theme.foregroundColor;
    self.backgroundColor = theme.cellBackgroundColor;
    self.textLabel.textColor = theme.labelColor;
    self.detailTextLabel.textColor = theme.valueColor;
    self.xui_disclosureIndicatorColor = theme.disclosureIndicatorColor;
    self.selectedBackgroundView.backgroundColor = theme.selectedColor;
    self.validationView.backgroundColor = theme.dangerColor;
}

- (void)setInternalIconPath:(NSString *)internalIconPath {
    _internalIconPath = internalIconPath;
    if ([self.class layoutNeedsImageView]) {
        if (internalIconPath) {
            NSString *imagePath = [FRAMEWORK_BUNDLE pathForResource:internalIconPath ofType:nil];
            self.imageView.image = [UIImage imageWithContentsOfFile:imagePath];
        } else {
            self.imageView.image = nil;
        }
    }
}

#pragma mark - Default Values

- (XUITheme *)theme {
    return self.internalTheme ? self.internalTheme : self.factory.theme;
}

- (id <XUIAdapter>)adapter {
    return self.factory.adapter;
}

- (XUILogger *)logger {
    return self.factory.logger;
}

#pragma mark - Validation

- (void)setValidated:(BOOL)validated {
    _validated = validated;
    if (validated) {
        self.validationView.hidden = YES;
    } else {
        self.validationView.hidden = NO;
    }
}

@end
