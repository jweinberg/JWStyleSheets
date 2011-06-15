//
//  JWSheetParser.h
//  JWStyleSheet
//
//  Created by Joshua Weinberg on 6/9/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JWSheetParser : NSObject
@property (nonatomic, readonly, copy) NSURL *sheetURL;
- (id)initWithContentsOfURL:(NSURL*)aURL;
- (void)parse;
@end
