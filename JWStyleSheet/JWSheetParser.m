//
//  JWSheetParser.m
//  JWStyleSheet
//

#import "JWSheetParser.h"

@interface JWSheetParser ()
@property (nonatomic, readwrite, copy) NSURL *sheetURL;

- (NSArray*)parseClassNames:(NSString*)classList;
- (NSDictionary*)buildTextAttributes:(NSDictionary*)properties;
- (UIColor*)parseColor:(NSString*)color;
- (void)configureBarButtonItemWithProxy:(id)proxy attributes:(NSDictionary*)attributes;
- (void)configureNavigationBarWithProxy:(id)proxy attributes:(NSDictionary*)attributes;
- (void)configureToolbarWithProxy:(id)proxy attributes:(NSDictionary*)attributes;
- (UIImage*)loadImage:(id)attributes;
@end

@implementation JWSheetParser
@synthesize sheetURL;

- (id)init;
{
    return nil;
}

- (id)initWithContentsOfURL:(NSURL*)aURL;
{
    self = [super init];
    if (self) 
    {
        self.sheetURL = aURL;
    }
    
    return self;
}

- (void)parse;
{
    NSInputStream *stream = [NSInputStream inputStreamWithURL:self.sheetURL];
    [stream open];
    NSDictionary * groups = [NSJSONSerialization JSONObjectWithStream:stream options:0 error:nil];
    [stream close];
    
    [groups enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSDictionary *properties, BOOL *stop) 
    {
        NSArray *classNames = [self parseClassNames:key];
    
        NSArray *containedIn = [classNames subarrayWithRange:NSMakeRange(0, [classNames count] - 1)];
        NSMutableArray *classArray = [NSMutableArray array];
        for (NSString *string in containedIn)
            [classArray insertObject:NSClassFromString(string) atIndex:0];
        
        Class currentClass = NSClassFromString([classNames lastObject]);
        
        //This is a big hack. 'appearanceWhenContainedIn' uses a variadic list to get the right proxy. We need to build one on the heap to pass off to it.
        Class<UIAppearanceContainer> __unsafe_unretained * stack = (typeof(stack))calloc([classNames count] + 1, sizeof(Class));
        [classArray getObjects:stack];
        id appearenceProxy = [currentClass appearanceWhenContainedIn:*stack, nil];
        free(stack);
        
        
        if ([currentClass isEqual:[UIBarButtonItem class]] || 
            [currentClass isSubclassOfClass:[UIBarButtonItem class]])
        {
            [self configureBarButtonItemWithProxy:appearenceProxy
                                       attributes:properties];
        }
        else if ([currentClass isEqual:[UINavigationBar class]] ||
                 [currentClass isSubclassOfClass:[UINavigationBar class]])
        {
            [self configureNavigationBarWithProxy:appearenceProxy
                                       attributes:properties];
        }
        else if ([currentClass isEqual:[UIToolbar class]] ||
                 [currentClass isSubclassOfClass:[UIToolbar class]])
        {
            [self configureToolbarWithProxy:appearenceProxy
                                 attributes:properties];
        }

    }];
}

#pragma mark - Configuration Methods
- (void)configureNavigationBarWithProxy:(UINavigationBar*)navBar attributes:(NSDictionary *)attributes;
{
    [attributes enumerateKeysAndObjectsUsingBlock:^(NSString *key, id val, BOOL *stop) {
        if ([key isEqualToString:@"tintColor"])
        {
            [navBar setTintColor:[self parseColor:val]];
        }
        else if ([key isEqualToString:@"title-offset"])
        {
            [navBar setTitleVerticalPositionAdjustment:[val floatValue]
                                         forBarMetrics:UIBarMetricsDefault];
        }
        else if ([key isEqualToString:@"text-attributes"])
        {
            [navBar setTitleTextAttributes:[self buildTextAttributes:val]];
        }
        else if ([key isEqualToString:@"background"])
        {
            [navBar setBackgroundImage:[self loadImage:val] forBarMetrics:UIBarMetricsDefault];
        }
        else
        {
            NSLog(@"Unknown attribute: %@: %@", key, val);
        }        
    }];
}

- (void)configureToolbarWithProxy:(UIToolbar*)toolbar attributes:(NSDictionary *)attributes;
{
    [attributes enumerateKeysAndObjectsUsingBlock:^(NSString *key, id val, BOOL *stop) {
        if ([key isEqualToString:@"tintColor"])
        {
            [toolbar setTintColor:[self parseColor:val]];
        }
        else if ([key isEqualToString:@"background"])
        {
            [toolbar setBackgroundImage:[self loadImage:val]
                     forToolbarPosition:UIToolbarPositionAny
                             barMetrics:UIBarMetricsDefault];
        }
    }];
}

- (void)configureBarButtonItemWithProxy:(UIBarButtonItem*)barButton attributes:(NSDictionary*)attributes;
{
    [attributes enumerateKeysAndObjectsUsingBlock:^(NSString *key, id val, BOOL *stop) {
        if ([key isEqualToString:@"tintColor"])
        {
            [barButton setTintColor:[self parseColor:val]];
        }
        else if ([key isEqualToString:@"title-offset"])
        {
            [barButton setTitlePositionAdjustment:UIOffsetFromString(val) 
                                    forBarMetrics:UIBarMetricsDefault];
        }
        else if ([key isEqualToString:@"text-attributes"])
        {
            [barButton setTitleTextAttributes:[self buildTextAttributes:val]
                                     forState:UIControlStateNormal];
        }
        else if ([key isEqualToString:@"background"])
        {
            [barButton setBackgroundImage:[self loadImage:val] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        }
    }];
}

#pragma mark - Parsing Methods

- (NSArray*)parseClassNames:(NSString*)classList;
{
    NSArray *classes = [classList componentsSeparatedByString:@"."];
    
    NSMutableArray *trimmedClasses = [NSMutableArray array];
    for (NSString *string in classes)
    {
        [trimmedClasses addObject:[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]; 
    }
    
    return [trimmedClasses copy];
}

- (UIColor*)parseColor:(NSString*)color;
{
    NSScanner *hexScanner = [NSScanner scannerWithString:color];
    NSUInteger rgb = 0;
    [hexScanner scanHexInt:&rgb];
    
    return [UIColor colorWithRed:(float)((rgb >> 16) & 0xFF)/255.0f green:(float)((rgb >> 8) & 0xFF)/255.0f blue:(float)((rgb) & 0xFF)/255.0f alpha:1.0f];
}

- (NSDictionary*)buildTextAttributes:(NSDictionary*)val;
{
    CGFloat fontSize = [[val objectForKey:@"size"] floatValue];
    NSString *fontName = [val objectForKey:@"font"];
    UIFont *font = [UIFont fontWithName:fontName size:fontSize];
    UIColor *fontColor = [self parseColor:[val objectForKey:@"color"]];
    
    UIColor *shadowColor = [self parseColor:[val objectForKey:@"shadow-color"]];
    NSValue *shadowOffset = [NSValue valueWithUIOffset:UIOffsetFromString([val objectForKey:@"shadow-offset"])];
    
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    if (font)
        [attributes setObject:font forKey:UITextAttributeFont];
    if (fontColor)
        [attributes setObject:fontColor forKey:UITextAttributeTextColor];
    if (shadowColor)
        [attributes setObject:shadowColor forKey:UITextAttributeTextShadowColor];
    if (shadowOffset)
        [attributes setObject:shadowOffset forKey:UITextAttributeTextShadowOffset];
    return [attributes copy];
}

- (UIImage*)loadImage:(id)attributes;
{
    if ([attributes isKindOfClass:[NSString class]])
        return [UIImage imageNamed:attributes];
    else if ([attributes isKindOfClass:[NSDictionary class]])
    {
        NSString *imageName = [attributes objectForKey:@"name"];
        NSString *capString = [attributes objectForKey:@"caps"];
        
        UIEdgeInsets insets = UIEdgeInsetsZero;
        if (capString)
            insets = UIEdgeInsetsFromString(capString);
        
        return [[UIImage imageNamed:imageName] resizableImageWithCapInsets:insets];
    }
    return nil;
}
@end
